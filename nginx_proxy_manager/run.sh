#!/bin/bash
# ==============================================================================
# Nginx Proxy Manager – HA Wrapper Entrypoint
# ==============================================================================
set -e

log() { echo "[npm-ha] $*"; }

cfg() {
    curl -sf \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/addons/self/options/config" \
        | jq -r ".${1} // empty"
}

# Liest aus /etc/secrets/ – HA Supervisor legt secrets.yaml Werte dort ab
read_secret() {
    local SECRET_FILE="/etc/secrets/${1}"
    if [ -f "${SECRET_FILE}" ]; then
        cat "${SECRET_FILE}"
    else
        echo ""
    fi
}

log "Reading Home Assistant configuration..."

# ── s6-overlay: /run/ ist noexec in HA → /tmp/ nutzen ────────────────────────
export S6_BASEDIR=/tmp/s6
mkdir -p /tmp/s6

# ── Data Paths ────────────────────────────────────────────────────────────────
mkdir -p /data/npm/data /data/npm/letsencrypt /data/npm/logs

# ── Zertifikate persistent ────────────────────────────────────────────────────
mkdir -p /etc/letsencrypt
if [ -d /data/npm/letsencrypt ] && [ "$(ls -A /data/npm/letsencrypt 2>/dev/null)" ]; then
    cp -rn /data/npm/letsencrypt/. /etc/letsencrypt/ 2>/dev/null || true
    log "Certificates restored from persistent storage"
fi

# Hintergrund-Sync alle 5 Minuten: container → persistent
(
    while true; do
        sleep 300
        rsync -a --delete /etc/letsencrypt/ /data/npm/letsencrypt/ 2>/dev/null || \
        cp -ru /etc/letsencrypt/. /data/npm/letsencrypt/ 2>/dev/null || true
    done
) &
trap "cp -ru /etc/letsencrypt/. /data/npm/letsencrypt/ 2>/dev/null || true" EXIT INT TERM

# ── Self-Healing: fehlende Zertifikate (Dummy statt Crash-Loop) ──────────────
# Falls ein Certbot-Request fehlschlägt (z.B. DuckDNS DNS-01 Fehler), generiert
# NPM trotzdem eine nginx-Config, die auf das (nie erzeugte) Zertifikat zeigt.
# nginx crasht dann in einer Endlosschleife und reißt ALLE Proxy Hosts mit,
# nicht nur den fehlerhaften. Dieser Watcher patcht fehlende Zertifikatsdateien
# mit einem kurzlebigen Self-Signed-Dummy, damit nginx startet — der Host mit
# dem kaputten Zertifikat zeigt dann nur eine Browser-Warnung statt den
# kompletten Reverse Proxy lahmzulegen. Sobald ein echtes Zertifikat erfolg-
# reich ausgestellt wird, überschreibt Certbot den Dummy automatisch.
(
    for _ in $(seq 1 40); do
        grep -rhoE 'ssl_certificate[[:space:]]+/etc/letsencrypt/live/[^;[:space:]]+' \
            /data/nginx /etc/nginx/conf.d 2>/dev/null \
            | awk '{print $2}' \
            | while read -r CERT_PATH; do
                CERT_DIR="$(dirname "${CERT_PATH}")"
                KEY_PATH="${CERT_DIR}/privkey.pem"
                if [ ! -s "${CERT_PATH}" ] || [ ! -s "${KEY_PATH}" ]; then
                    mkdir -p "${CERT_DIR}"
                    openssl req -x509 -nodes -newkey rsa:2048 \
                        -keyout "${KEY_PATH}" -out "${CERT_PATH}" \
                        -days 1 -subj "/CN=localhost" 2>/dev/null \
                        && log "Self-healed missing certificate: ${CERT_PATH} (dummy, will be replaced by a real one once issuance succeeds)"
                fi
            done || true
        sleep 3
    done
) &

export DATA_PATH="/data/npm/data"
export LETSENCRYPT_PATH="/etc/letsencrypt"

# ── Datenbank ─────────────────────────────────────────────────────────────────
DB_TYPE="$(cfg 'db_type')"

if [ "${DB_TYPE}" = "mariadb" ]; then
    export DB_MYSQL_HOST="$(cfg 'mariadb_host')"
    export DB_MYSQL_PORT="$(cfg 'mariadb_port')"
    export DB_MYSQL_NAME="$(cfg 'mariadb_name')"
    export DB_MYSQL_USER="$(cfg 'mariadb_user')"

    # Passwort aus secrets.yaml (Key: npm_mariadb_password)
    DB_PASS="$(read_secret 'npm_mariadb_password')"
    if [ -z "${DB_PASS}" ]; then
        log "WARNING: npm_mariadb_password not found in secrets.yaml!"
    fi
    export DB_MYSQL_PASSWORD="${DB_PASS}"
    log "MariaDB: ${DB_MYSQL_HOST}:${DB_MYSQL_PORT}/${DB_MYSQL_NAME}"
else
    export DB_SQLITE_FILE="/data/npm/data/database.sqlite"
    log "SQLite: ${DB_SQLITE_FILE}"
fi

# ── JWT Secret aus secrets.yaml (Key: npm_jwt_secret) ────────────────────────
JWT="$(read_secret 'npm_jwt_secret')"
[ -n "${JWT}" ] && export JWT_SECRET="${JWT}" && log "JWT secret loaded from secrets.yaml"

# ── Ports ─────────────────────────────────────────────────────────────────────
HTTP_PORT="$(cfg 'http_port')"
HTTPS_PORT="$(cfg 'https_port')"
[ -n "${HTTP_PORT}" ]  && export HTTP_PORT
[ -n "${HTTPS_PORT}" ] && export HTTPS_PORT

# ── IPv6 ──────────────────────────────────────────────────────────────────────
[ "$(cfg 'disable_ipv6')" = "true" ] && export DISABLE_IPV6="true"

# ── Misc ──────────────────────────────────────────────────────────────────────
export NODE_ENV="production"
export LOG_LEVEL="$(cfg 'log_level')"

log "ENV set – handing over to NPM /init..."
exec /init
