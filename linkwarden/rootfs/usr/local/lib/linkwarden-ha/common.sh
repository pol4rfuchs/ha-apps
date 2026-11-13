# shellcheck shell=bash
# shellcheck disable=SC2034  # the variables are used by the files that source this one
# Shared helpers of the Linkwarden app. Sourced by the init script and the s6 services
# (all of them run under bashio, so bashio::* is available).

DATA_DIR="/data/linkwarden"
PG_DATA="${DATA_DIR}/postgresql"
LIBRARY_DIR="${DATA_DIR}/library"
SECRET_DIR="${DATA_DIR}/secrets"
PG_RUN_DIR="/run/postgresql"
LW_DIR="/opt/linkwarden"
LW_LIB="/usr/local/lib/linkwarden-ha"
LW_PORT="3200"
LW_USER="linkwarden"
# Marker that the web service creates once the database schema is up to date. The worker waits for it.
LW_READY_FILE="/tmp/linkwarden-db-ready"

# The PostgreSQL binaries live in a versioned directory (the package version follows the Debian release).
_pg_bins=(/usr/lib/postgresql/*/bin)
PG_BIN="${_pg_bins[0]}"
PG_MAJOR="${PG_BIN%/bin}"
PG_MAJOR="${PG_MAJOR##*/}"

# Names that the app sets itself. A custom variable with one of these names would break the app or bypass an option,
# so the app refuses it. Prefixes LW_, S6_ and SUPERVISOR_ are reserved as well.
LW_RESERVED_ENV="DATABASE_URL NEXTAUTH_URL NEXTAUTH_SECRET STORAGE_FOLDER PLAYWRIGHT_WS_URL PLAYWRIGHT_BROWSERS_PATH \
NODE_ENV NODE_OPTIONS PATH HOME SHELL USER LD_PRELOAD LD_LIBRARY_PATH NEXT_TELEMETRY_DISABLED PRISMA_HIDE_UPDATE_MESSAGE \
DISABLE_BROWSER NEXT_PUBLIC_DISABLE_REGISTRATION ARCHIVE_TAKE_COUNT BROWSER_TIMEOUT PDF_MAX_BUFFER SCREENSHOT_MAX_BUFFER \
INDEX_TAKE_COUNT"

# Apply the log_level option to bashio and compute the matching level of each component.
# PostgreSQL: in log_min_messages the level "log" ranks above warning and error, so it is not used here;
# start-up and shutdown messages are LOG messages and always appear.
lw_apply_log_level() {
  LW_LOG_LEVEL="$(bashio::config 'log_level')"
  bashio::log.level "${LW_LOG_LEVEL}"
  case "${LW_LOG_LEVEL}" in
    debug)   PG_LOG_LEVEL="debug1" ;;
    error)   PG_LOG_LEVEL="error" ;;
    *)       PG_LOG_LEVEL="warning" ;;
  esac
}

# Percent-encode a string for the use in a URL (the generated database password is hex, but be safe).
lw_urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

# Print why a custom variable name is refused, or nothing if it is fine.
lw_env_name_problem() {
  local name="$1"
  if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    printf 'is not a valid variable name (letters, digits and underscore, not starting with a digit)'
  elif [[ "${name}" == LW_* || "${name}" == S6_* || "${name}" == SUPERVISOR_* ]]; then
    printf 'uses a prefix that the app reserves'
  elif [[ " ${LW_RESERVED_ENV} " == *" ${name} "* ]]; then
    printf 'is set by the app itself and cannot be changed here (the documentation lists the options that replace it)'
  fi
}

# Check the env_vars option. Used once by the init script: a wrong entry stops the start with a clear message instead
# of being ignored. Only names are logged, never values.
lw_validate_env_vars() {
  local count index name problem invalid=0 seen=" "
  count="$(bashio::config 'env_vars|length')"
  for ((index = 0; index < count; index++)); do
    name="$(bashio::config "env_vars[${index}].name")"
    problem="$(lw_env_name_problem "${name}")"
    if [ -n "${problem}" ]; then
      bashio::log.error "env_vars entry $((index + 1)): the name '${name}' ${problem}."
      invalid=1
    elif [[ "${seen}" == *" ${name} "* ]]; then
      bashio::log.warning "env_vars: '${name}' is listed more than once, the last entry wins."
    fi
    seen="${seen}${name} "
  done
  if [ "${invalid}" -ne 0 ]; then
    bashio::log.error "Fix or remove the entries named above in the env_vars option."
    return 1
  fi
  if [ "${count}" -gt 0 ]; then
    bashio::log.info "Passing ${count} additional environment variable(s) to Linkwarden (names: ${seen# })."
  fi
}

# Export a limit as environment variable. 0 (or no value) means the default of Linkwarden: the variable is not set.
lw_export_limit() {
  local option="$1" variable="$2" value
  if bashio::config.has_value "${option}"; then
    value="$(bashio::config "${option}")"
    if [ "${value}" != "0" ]; then
      export "${variable}=${value}"
    fi
  fi
}

# Environment for everything that runs Linkwarden code (web and worker).
# The secrets are read from ${SECRET_DIR}; the database password is part of DATABASE_URL, which exists only in
# the environment of these two processes.
lw_export_env() {
  local public_url db_password secret encoded_password count index name value
  public_url="$(bashio::config 'public_url')"
  if [ -z "${public_url}" ] || [ "${public_url}" = "null" ]; then
    # The init script logs a warning once; this function runs in the web and the worker service.
    public_url="http://localhost:${LW_PORT}"
  fi
  # NextAuth wants the base of its own endpoint; accept the plain address as well.
  public_url="${public_url%/}"
  case "${public_url}" in
    */api/v1/auth) ;;
    *) public_url="${public_url}/api/v1/auth" ;;
  esac

  db_password="$(< "${SECRET_DIR}/db_password")"
  secret="$(< "${SECRET_DIR}/nextauth_secret")"
  # Assign first, export afterwards: a failing command inside export would be masked (SC2155, §11).
  encoded_password="$(lw_urlencode "${db_password}")"

  # The additional variables come first, so that nothing below can be overridden by them (the names the app sets
  # are refused by the init script anyway).
  count="$(bashio::config 'env_vars|length')"
  for ((index = 0; index < count; index++)); do
    name="$(bashio::config "env_vars[${index}].name")"
    value="$(bashio::config "env_vars[${index}].value")"
    export "${name}=${value}"
  done

  export NODE_ENV="production"
  export NEXTAUTH_URL="${public_url}"
  export NEXTAUTH_SECRET="${secret}"
  export DATABASE_URL="postgresql://linkwarden:${encoded_password}@127.0.0.1:5432/linkwarden"
  export PLAYWRIGHT_BROWSERS_PATH="/ms-playwright"
  export NEXT_TELEMETRY_DISABLED="1" PRISMA_HIDE_UPDATE_MESSAGE="1"
  export PATH="${LW_DIR}/node_modules/.bin:${PATH}"
  export ARCHIVE_TAKE_COUNT
  ARCHIVE_TAKE_COUNT="$(bashio::config 'archive_take_count')"
  if bashio::config.true 'disable_browser'; then
    export DISABLE_BROWSER="true"
  fi
  if bashio::config.true 'disable_registration'; then
    export NEXT_PUBLIC_DISABLE_REGISTRATION="true"
  fi
  lw_export_limit browser_timeout BROWSER_TIMEOUT
  lw_export_limit pdf_max_buffer PDF_MAX_BUFFER
  lw_export_limit screenshot_max_buffer SCREENSHOT_MAX_BUFFER
  lw_export_limit index_take_count INDEX_TAKE_COUNT
}
