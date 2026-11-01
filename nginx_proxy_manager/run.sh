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
        | jq -r "(.data // .) | .${1} // empty"
}

log "Reading Home Assistant configuration..."

# ── s6-overlay: /run/ is noexec in HA → use /tmp/ ────────────────────────
export S6_BASEDIR=/tmp/s6
mkdir -p /tmp/s6

# ── Data Paths ────────────────────────────────────────────────────────────────
mkdir -p /data/npm/data /data/npm/letsencrypt /data/npm/logs

# ── Persistent certificates ────────────────────────────────────────────────────
mkdir -p /etc/letsencrypt
if [ -d /data/npm/letsencrypt ] && [ "$(ls -A /data/npm/letsencrypt 2>/dev/null)" ]; then
    cp -rn /data/npm/letsencrypt/. /etc/letsencrypt/ 2>/dev/null || true
    log "Certificates restored from persistent storage"
fi

# Background sync every 5 minutes: container → persistent
(
    while true; do
        sleep 300
        rsync -a --delete /etc/letsencrypt/ /data/npm/letsencrypt/ 2>/dev/null || \
        cp -ru /etc/letsencrypt/. /data/npm/letsencrypt/ 2>/dev/null || true
    done
) &
trap "cp -ru /etc/letsencrypt/. /data/npm/letsencrypt/ 2>/dev/null || true" EXIT INT TERM

# ── Self-healing: missing certificates (dummy instead of crash loop) ──────────────
# If a Certbot request fails (e.g. a DuckDNS DNS-01 error), NPM still
# generates an nginx config pointing at the (never created) certificate.
# nginx then crashes in an endless loop and takes ALL proxy hosts down with
# it, not just the faulty one. This watcher patches missing certificate files
# with a short-lived self-signed dummy so nginx starts — the host with the
# broken certificate then only shows a browser warning instead of crippling
# the whole reverse proxy. Once a real certificate is issued successfully,
# Certbot overwrites the dummy automatically.
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

# ── Database ─────────────────────────────────────────────────────────────────
DB_TYPE="$(cfg 'db_type')"

if [ "${DB_TYPE}" = "mariadb" ]; then
    export DB_MYSQL_HOST="$(cfg 'mariadb_host')"
    export DB_MYSQL_PORT="$(cfg 'mariadb_port')"
    export DB_MYSQL_NAME="$(cfg 'mariadb_name')"
    export DB_MYSQL_USER="$(cfg 'mariadb_user')"

    export DB_MYSQL_PASSWORD="$(cfg 'mariadb_password')"
    if [ -z "${DB_MYSQL_PASSWORD}" ]; then
        log "WARNING: mariadb_password is empty - the database connection will most likely fail."
    fi
    log "MariaDB: ${DB_MYSQL_HOST}:${DB_MYSQL_PORT}/${DB_MYSQL_NAME}"
else
    export DB_SQLITE_FILE="/data/npm/data/database.sqlite"
    log "SQLite: ${DB_SQLITE_FILE}"
fi

# ── IPv6 ──────────────────────────────────────────────────────────────────────
[ "$(cfg 'disable_ipv6')" = "true" ] && export DISABLE_IPV6="true"

# ── Misc ──────────────────────────────────────────────────────────────────────
export NODE_ENV="production"
export LOG_LEVEL="$(cfg 'log_level')"

log "ENV set – handing over to NPM /init..."
exec /init
