#!/bin/sh
# HA-Wrapper-Entrypoint fuer CortenDesk (Alpine/BusyBox sh, kein bashio).
# Uebersetzt /data/options.json in die ENV-Variablen, die der Upstream-
# /entrypoint.sh erwartet, und uebergibt dann.
set -eu

OPTIONS="${OPTIONS_FILE:-/data/options.json}"

# opt <key>: Wert als String; leer, wenn Datei/Key fehlt oder null ist.
# (Kein "// empty": das wuerde "false" verschlucken.)
opt() {
    [ -r "$OPTIONS" ] || return 0
    jq -r --arg k "$1" '.[$k] | select(. != null) | tostring' "$OPTIONS" 2>/dev/null || true
}

APP_URL="$(opt app_url)"
if [ -z "$APP_URL" ]; then
    echo "[ha-wrapper] FEHLER: Option 'app_url' ist leer. Oeffentliche Adresse setzen, z.B. http://rd.example.com:21114" >&2
    exit 1
fi
export APP_URL

ADMIN_PASSWORD="$(opt admin_password)"
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "[ha-wrapper] FEHLER: Option 'admin_password' ist leer." >&2
    exit 1
fi
CORTENDESK_ADMIN_USER="$(opt admin_user)"
CORTENDESK_ADMIN_USER="${CORTENDESK_ADMIN_USER:-admin}"
CORTENDESK_ADMIN_PASSWORD="$ADMIN_PASSWORD"
export CORTENDESK_ADMIN_USER CORTENDESK_ADMIN_PASSWORD

WEBCLIENT="$(opt native_webclient)"
export CORTENDESK_NATIVE_WEBCLIENT="${WEBCLIENT:-false}"

# Optional: ID-Server/Relay-Adresse, wenn sie von app_url abweichen soll (z.B. oeffentlicher
# Host fuer externe Clients, waehrend app_url die LAN-Adresse bleibt). Format host:port.
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

# Ein Regler fuer Konsole (Laravel) und hbbs/hbbr: ab Upstream 1.11.0 setzt
# CORTENDESK_LOG_LEVEL beides korrekt (LOG_LEVEL und RUST_LOG).
case "$(opt log_level)" in
    DEBUG)   CORTENDESK_LOG_LEVEL=debug ;;
    WARNING) CORTENDESK_LOG_LEVEL=warning ;;
    ERROR)   CORTENDESK_LOG_LEVEL=error ;;
    *)       CORTENDESK_LOG_LEVEL=info ;;
esac
export CORTENDESK_LOG_LEVEL

# Kein Call nach GitHub (VERSION-Check), Updates laufen ueber die HA-App-Version (§9).
export CORTENDESK_UPDATE_CHECK=false

# HA mountet /data als root:root. php-fpm laeuft als www-data und braucht fuer SQLite ein
# beschreibbares VERZEICHNIS (Journal-/WAL-Dateien), sonst: "attempt to write a readonly
# database". Daher liegt die DB in einem eigenen Unterordner, /data selbst bleibt unberuehrt.
DB_DIR=/data/db
mkdir -p "$DB_DIR"
chown www-data:www-data "$DB_DIR"
chmod 750 "$DB_DIR"
# Bewusst OHNE Default-Syntax: das Upstream-Image setzt DB_DATABASE=/data/cortendesk.sqlite
# per ENV, ein ${DB_DATABASE:-...} wuerde diesen Wert behalten und den Fix wirkungslos machen.
DB_DATABASE="$DB_DIR/cortendesk.sqlite"
export DB_DATABASE

echo "[ha-wrapper] app_url=${APP_URL} log_level=${CORTENDESK_LOG_LEVEL} webclient=${CORTENDESK_NATIVE_WEBCLIENT} db=${DB_DATABASE}"
exec /entrypoint.sh "$@"
