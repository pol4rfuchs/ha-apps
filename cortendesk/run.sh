#!/bin/sh
# HA wrapper entrypoint for CortenDesk (Alpine/BusyBox sh, no bashio).
# Translates /data/options.json into the ENV variables the upstream
# /entrypoint.sh expects, then hands over.
set -eu

OPTIONS="${OPTIONS_FILE:-/data/options.json}"

# opt <key>: value as a string; empty if the file/key is missing or null.
# (No "// empty": that would swallow "false".)
opt() {
    [ -r "$OPTIONS" ] || return 0
    jq -r --arg k "$1" '.[$k] | select(. != null) | tostring' "$OPTIONS" 2>/dev/null || true
}

APP_URL="$(opt app_url)"
if [ -z "$APP_URL" ]; then
    echo "[ha-wrapper] ERROR: Option 'app_url' is empty. Set the public address, e.g. http://rd.example.com:21114" >&2
    exit 1
fi
export APP_URL

ADMIN_PASSWORD="$(opt admin_password)"
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "[ha-wrapper] ERROR: Option 'admin_password' is empty." >&2
    exit 1
fi
CORTENDESK_ADMIN_USER="$(opt admin_user)"
CORTENDESK_ADMIN_USER="${CORTENDESK_ADMIN_USER:-admin}"
CORTENDESK_ADMIN_PASSWORD="$ADMIN_PASSWORD"
export CORTENDESK_ADMIN_USER CORTENDESK_ADMIN_PASSWORD

WEBCLIENT="$(opt native_webclient)"
export CORTENDESK_NATIVE_WEBCLIENT="${WEBCLIENT:-false}"

# Optional: ID server/relay address if it should differ from app_url (e.g. a public
# host for external clients while app_url stays the LAN address). Format host:port.
ID_SERVER="$(opt id_server)"
if [ -n "$ID_SERVER" ]; then
    export CORTENDESK_ID_SERVER="$ID_SERVER"
fi
RELAY_SERVER="$(opt relay_server)"
if [ -n "$RELAY_SERVER" ]; then
    export CORTENDESK_RELAY_SERVER="$RELAY_SERVER"
fi

MAX_MB="$(opt downloads_max_mb)"
if [ -n "$MAX_MB" ]; then
    export CORTENDESK_DOWNLOADS_MAX_MB="$MAX_MB"
fi

# One control for the console (Laravel) and hbbs/hbbr: since upstream 1.11.0
# CORTENDESK_LOG_LEVEL sets both correctly (LOG_LEVEL and RUST_LOG).
case "$(opt log_level)" in
    DEBUG)   CORTENDESK_LOG_LEVEL=debug ;;
    WARNING) CORTENDESK_LOG_LEVEL=warning ;;
    ERROR)   CORTENDESK_LOG_LEVEL=error ;;
    *)       CORTENDESK_LOG_LEVEL=info ;;
esac
export CORTENDESK_LOG_LEVEL

# No call to GitHub (VERSION check); updates go through the HA app version (§9).
export CORTENDESK_UPDATE_CHECK=false

# HA mounts /data as root:root. php-fpm runs as www-data and needs a writable DIRECTORY
# for SQLite (journal/WAL files), otherwise: "attempt to write a readonly
# database". Therefore the DB lives in its own subfolder; /data itself stays untouched.
DB_DIR=/data/db
mkdir -p "$DB_DIR"
chown www-data:www-data "$DB_DIR"
chmod 750 "$DB_DIR"
# Deliberately WITHOUT default syntax: the upstream image sets DB_DATABASE=/data/cortendesk.sqlite
# via ENV, so ${DB_DATABASE:-...} would keep that value and make the fix ineffective.
DB_DATABASE="$DB_DIR/cortendesk.sqlite"
export DB_DATABASE

echo "[ha-wrapper] app_url=${APP_URL} log_level=${CORTENDESK_LOG_LEVEL} webclient=${CORTENDESK_NATIVE_WEBCLIENT} db=${DB_DATABASE}"
exec /entrypoint.sh "$@"
