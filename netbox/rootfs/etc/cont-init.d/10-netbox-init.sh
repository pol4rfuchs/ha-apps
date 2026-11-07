#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/netbox-ha/common.sh
nb_apply_log_level

bashio::log.info "Preparing NetBox data in ${DATA_DIR}..."

# ------------------------------------------------------------ directories
mkdir -p "${DATA_DIR}" "${PG_DATA}" "${VALKEY_DIR}" "${SECRET_DIR}" \
         "${MEDIA_DIR}" "${SCRIPTS_DIR}" "${REPORTS_DIR}" "${PG_RUN_DIR}"
chmod 755 "${DATA_DIR}"
chown postgres:postgres "${PG_DATA}" "${PG_RUN_DIR}"
chmod 700 "${PG_DATA}"
chown valkey:valkey "${VALKEY_DIR}"
chmod 700 "${VALKEY_DIR}"
chown netbox:root "${SECRET_DIR}"
chmod 700 "${SECRET_DIR}"
for dir in "${MEDIA_DIR}" "${SCRIPTS_DIR}" "${REPORTS_DIR}"; do
  chown netbox:root "${dir}"
  chmod 775 "${dir}"
done
for dir in "${SCRIPTS_DIR}" "${REPORTS_DIR}"; do
  if [ ! -e "${dir}/__init__.py" ]; then
    install -o netbox -g root -m 644 /dev/null "${dir}/__init__.py"
  fi
done

# ---------------------------------------------------------------- secrets
# Generated once and kept in /data (nothing is created at build time, §4). NetBox reads them from
# /run/secrets/<name>; the link is recreated at every start because /run is empty then.
nb_gen_secret() {
  local file="${SECRET_DIR}/$1" value
  if [ -s "${file}" ]; then
    return 0
  fi
  value="$(openssl rand -hex "$2")"
  ( umask 077; printf '%s' "${value}" > "${file}.tmp" )
  mv "${file}.tmp" "${file}"
  chown netbox:root "${file}"
  if [ ! -s "${file}" ]; then
    bashio::log.error "Could not create the secret $1."
    exit 1
  fi
  bashio::log.info "Generated the secret $1."
}
nb_gen_secret secret_key 32
nb_gen_secret api_token_pepper_1 32
nb_gen_secret db_password 24
ln -sfn "${SECRET_DIR}" /run/secrets

# ------------------------------------------------------------- PostgreSQL
if [ -s "${PG_DATA}/PG_VERSION" ]; then
  pg_found="$(< "${PG_DATA}/PG_VERSION")"
  if [ "${pg_found}" != "${PG_MAJOR}" ]; then
    bashio::log.error "The database in ${PG_DATA} is PostgreSQL ${pg_found}, this image ships PostgreSQL ${PG_MAJOR}."
    bashio::log.error "A major upgrade needs a dump and restore (see DOCS.md, section Backup and restore). Not starting."
    exit 1
  fi
else
  bashio::log.info "Initializing a new PostgreSQL ${PG_MAJOR} database cluster..."
  gosu postgres "${PG_BIN}/initdb" -D "${PG_DATA}" -U postgres --encoding=UTF8 --locale=C.UTF-8 \
    --auth-local=peer --auth-host=scram-sha-256 > /dev/null
  if [ ! -s "${PG_DATA}/PG_VERSION" ]; then
    bashio::log.error "initdb did not create a cluster in ${PG_DATA}."
    exit 1
  fi
fi

# Role, database and password are set through a temporary server that listens on the socket only.
# The password is ALTERed at every start so the role never drifts from the secret file (§11).
pg_sql() {
  gosu postgres "${PG_BIN}/psql" -X -q -v ON_ERROR_STOP=1 -h "${PG_RUN_DIR}" -U postgres -d postgres "$@"
}
gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" -w -t 300 -s -l /tmp/pg-init.log \
  -o "-c listen_addresses='' -c unix_socket_directories=${PG_RUN_DIR}" start

role_exists="$(pg_sql -tA -c "SELECT 1 FROM pg_roles WHERE rolname = 'netbox'")"
if [ "${role_exists}" != "1" ]; then
  pg_sql -c "CREATE ROLE netbox LOGIN"
fi
db_password="$(< "${SECRET_DIR}/db_password")"
printf "ALTER ROLE netbox WITH LOGIN PASSWORD :'pw';\n" | pg_sql -v "pw=${db_password}"
unset db_password
db_exists="$(pg_sql -tA -c "SELECT 1 FROM pg_database WHERE datname = 'netbox'")"
if [ "${db_exists}" != "1" ]; then
  bashio::log.info "Creating the netbox database..."
  pg_sql -c "CREATE DATABASE netbox OWNER netbox ENCODING 'UTF8' TEMPLATE template0"
fi

gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" -m fast -w -t 300 -s stop

# ---------------------------------------------------------------- plugins
# Optional, from the "plugins" option. Every entry must pin an exact version. They are installed into
# ${PLUGINS_DIR} (persistent) with the NetBox pins as constraints, and only again when the list or the
# NetBox dependency pins change (new NetBox release). This is the only step that contacts the Internet (PyPI).
plugin_specs="$(bashio::config 'plugins|map(.pip)|sort|join(" ")')"
plugin_modules="$(bashio::config 'plugins|map(.module)|join(" ")')"
plugin_state="${DATA_DIR}/plugins.state"
nb_deps="$(sha256sum /opt/netbox/requirements.txt | cut -d' ' -f1)"
wanted_state="requirements ${nb_deps}; ${plugin_specs}"

if [ -z "${plugin_specs}" ]; then
  if [ -d "${PLUGINS_DIR}" ]; then
    bashio::log.info "No plugins configured, removing the installed ones."
    rm -rf "${PLUGINS_DIR}" "${plugin_state}"
  fi
else
  for spec in ${plugin_specs}; do
    if [[ ! "${spec}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*==[A-Za-z0-9][A-Za-z0-9._+!-]*$ ]]; then
      bashio::log.error "Plugin '${spec}' is not valid. Use exactly NAME==VERSION (no ranges, URLs or options)."
      exit 1
    fi
  done
  for module in ${plugin_modules}; do
    if [[ ! "${module}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      bashio::log.error "Plugin module '${module}' is not a valid Python module name."
      exit 1
    fi
  done
  if [ -d "${PLUGINS_DIR}" ] && [ "$(cat "${plugin_state}" 2>/dev/null || true)" = "${wanted_state}" ]; then
    bashio::log.info "Plugins are up to date: ${plugin_specs}"
  else
    bashio::log.warning "Installing plugins from PyPI: ${plugin_specs}"
    rm -rf "${PLUGINS_DIR}" "${plugin_state}"
    mkdir -p "${PLUGINS_DIR}"
    chown netbox:root "${PLUGINS_DIR}"
    # shellcheck disable=SC2086  # the specs were validated above and contain no spaces
    gosu netbox env VIRTUAL_ENV=/opt/netbox/venv UV_NO_CACHE=1 uv pip install \
      --python "${NB_PYTHON}" --target "${PLUGINS_DIR}" \
      -c /opt/netbox/requirements.txt -c /opt/netbox/requirements-container.txt \
      ${plugin_specs}
    printf '%s' "${wanted_state}" > "${plugin_state}"
  fi
fi

bashio::log.info "Initialization done."
