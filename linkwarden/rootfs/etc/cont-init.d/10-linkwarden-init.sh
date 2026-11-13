#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linkwarden-ha/common.sh
lw_apply_log_level

bashio::log.info "Preparing Linkwarden data in ${DATA_DIR}..."

# ------------------------------------------------------------ directories
mkdir -p "${DATA_DIR}" "${PG_DATA}" "${LIBRARY_DIR}" "${SECRET_DIR}" "${PG_RUN_DIR}"
chmod 755 "${DATA_DIR}"
chown postgres:postgres "${PG_DATA}" "${PG_RUN_DIR}"
chmod 700 "${PG_DATA}"
# The archives (pages, PDFs, screenshots) are written by the web and worker processes.
chown linkwarden:linkwarden "${LIBRARY_DIR}"
chmod 750 "${LIBRARY_DIR}"
# The secrets are only read by the s6 services (root).
chown root:root "${SECRET_DIR}"
chmod 700 "${SECRET_DIR}"

# Linkwarden stores its files below <application folder>/<STORAGE_FOLDER> (default "data"). The link is recreated
# at every start so the application always writes into the persistent folder.
ln -sfn "${LIBRARY_DIR}" "${LW_DIR}/data"

# ---------------------------------------------------------------- secrets
# Generated once and kept in /data (nothing is created at build time, §4).
lw_gen_secret() {
  local file="${SECRET_DIR}/$1" value
  if [ -s "${file}" ]; then
    return 0
  fi
  value="$(openssl rand -hex "$2")"
  ( umask 077; printf '%s' "${value}" > "${file}.tmp" )
  mv "${file}.tmp" "${file}"
  if [ ! -s "${file}" ]; then
    bashio::log.error "Could not create the secret $1."
    exit 1
  fi
  bashio::log.info "Generated the secret $1."
}
lw_gen_secret nextauth_secret 32
lw_gen_secret db_password 24

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

role_exists="$(pg_sql -tA -c "SELECT 1 FROM pg_roles WHERE rolname = 'linkwarden'")"
if [ "${role_exists}" != "1" ]; then
  pg_sql -c "CREATE ROLE linkwarden LOGIN"
fi
db_password="$(< "${SECRET_DIR}/db_password")"
printf "ALTER ROLE linkwarden WITH LOGIN PASSWORD :'pw';\n" | pg_sql -v "pw=${db_password}"
unset db_password
db_exists="$(pg_sql -tA -c "SELECT 1 FROM pg_database WHERE datname = 'linkwarden'")"
if [ "${db_exists}" != "1" ]; then
  bashio::log.info "Creating the linkwarden database..."
  pg_sql -c "CREATE DATABASE linkwarden OWNER linkwarden ENCODING 'UTF8' TEMPLATE template0"
fi

gosu postgres "${PG_BIN}/pg_ctl" -D "${PG_DATA}" -m fast -w -t 300 -s stop

bashio::log.info "Initialization done."
