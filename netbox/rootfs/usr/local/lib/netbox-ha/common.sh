# shellcheck shell=bash
# shellcheck disable=SC2034  # the variables are used by the files that source this one
# Shared helpers of the NetBox app. Sourced by the init script and the s6 services
# (all of them run under bashio, so bashio::* is available).

DATA_DIR="/data/netbox"
PG_DATA="${DATA_DIR}/postgresql"
VALKEY_DIR="${DATA_DIR}/valkey"
SECRET_DIR="${DATA_DIR}/secrets"
MEDIA_DIR="${DATA_DIR}/media"
SCRIPTS_DIR="${DATA_DIR}/scripts"
REPORTS_DIR="${DATA_DIR}/reports"
PLUGINS_DIR="${DATA_DIR}/plugins"
PG_RUN_DIR="/run/postgresql"
NB_LIB="/usr/local/lib/netbox-ha"
NB_APP_DIR="/opt/netbox/netbox"
NB_PYTHON="/opt/netbox/venv/bin/python"
NB_PORT="8001"

# The PostgreSQL binaries live in a versioned directory (the package version follows the Ubuntu release).
_pg_bins=(/usr/lib/postgresql/*/bin)
PG_BIN="${_pg_bins[0]}"
PG_MAJOR="${PG_BIN%/bin}"
PG_MAJOR="${PG_MAJOR##*/}"

# Apply the log_level option to bashio and compute the matching level of each component.
# PostgreSQL: in log_min_messages the level "log" ranks above warning and error, so it is not used here;
# start-up and shutdown messages are LOG messages and always appear.
nb_apply_log_level() {
  NB_LOG_LEVEL="$(bashio::config 'log_level')"
  bashio::log.level "${NB_LOG_LEVEL}"
  case "${NB_LOG_LEVEL}" in
    debug)   PG_LOG_LEVEL="debug1";  VALKEY_LOG_LEVEL="debug";   GRANIAN_LOG_LEVEL="debug" ;;
    warning) PG_LOG_LEVEL="warning"; VALKEY_LOG_LEVEL="warning"; GRANIAN_LOG_LEVEL="warning" ;;
    error)   PG_LOG_LEVEL="error";   VALKEY_LOG_LEVEL="warning"; GRANIAN_LOG_LEVEL="error" ;;
    *)       PG_LOG_LEVEL="warning"; VALKEY_LOG_LEVEL="notice";  GRANIAN_LOG_LEVEL="info" ;;
  esac
}

# Environment for everything that runs NetBox code. The settings are read by
# /etc/netbox/config/configuration.py (upstream) and ha_app.py (this app).
# Secrets are not exported: NetBox reads them from /run/secrets (a link to ${SECRET_DIR}).
nb_export_env() {
  local hosts origins tz modules
  hosts="$(bashio::config 'allowed_hosts|join(" ")')"
  if [ -z "${hosts}" ]; then
    hosts="*"
    bashio::log.warning "allowed_hosts is empty: NetBox accepts any Host header. Set allowed_hosts to the names and addresses you use."
  fi
  origins="$(bashio::config 'csrf_trusted_origins|join(" ")')"
  modules="$(bashio::config 'plugins|map(.module)|join(" ")')"

  tz="$(bashio::config 'time_zone')"
  if [ -z "${tz}" ]; then
    tz="$(bashio::info.timezone 2>/dev/null || true)"
  fi
  if [ -z "${tz}" ] || [ "${tz}" = "null" ]; then
    bashio::log.info "No time zone is set and Home Assistant did not report one, using UTC."
    tz="UTC"
  elif [ ! -f "/usr/share/zoneinfo/${tz}" ]; then
    bashio::log.warning "Time zone '${tz}' is unknown, using UTC."
    tz="UTC"
  fi

  export DB_HOST="127.0.0.1" DB_PORT="5432" DB_NAME="netbox" DB_USER="netbox" DB_SSLMODE="disable"
  export REDIS_HOST="127.0.0.1" REDIS_PORT="6379"
  export ALLOWED_HOSTS="${hosts}" CSRF_TRUSTED_ORIGINS="${origins}" TIME_ZONE="${tz}"
  export MEDIA_ROOT="${MEDIA_DIR}"
  # Local-first (§18.6): no calls from NetBox itself to the outside. Census reporting and the Copilot agent
  # are on by default upstream, ISOLATED_DEPLOYMENT switches off the features that need the Internet.
  export ISOLATED_DEPLOYMENT="True" CENSUS_REPORTING_ENABLED="False" COPILOT_ENABLED="False"
  export HA_NETBOX_LOG_LEVEL="${NB_LOG_LEVEL^^}" HA_NETBOX_PLUGINS="${modules}"
  export PYTHONPATH="${PLUGINS_DIR}"
}
