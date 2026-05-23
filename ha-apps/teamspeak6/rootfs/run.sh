#!/usr/bin/env bash
set -Eeuo pipefail

OPTIONS_FILE="/data/options.json"
if [ ! -f "${OPTIONS_FILE}" ]; then
    echo "[ERROR] No options.json found"
    exit 1
fi

get_option() {
    jq -r ".${1} // empty" "${OPTIONS_FILE}"
}

has_dir_contents() {
    local dir="$1"
    [ -d "$dir" ] && [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}

LICENSE_ACCEPTED="$(get_option "license_accepted")"
if [ "${LICENSE_ACCEPTED}" != "true" ]; then
    echo "WARNING: Please accept the TeamSpeak License in the Configuration tab first!"
    exit 1
fi

QUERY_ADMIN_PASSWORD="$(get_option "query_admin_password")"
LOG_LEVEL="$(get_option "log_level")"
LOG_LEVEL="${LOG_LEVEL:-3}"

TS_DATA_DIR="/data/teamspeak6"
TS_RUNTIME_DIR="/var/tsserver"
TS_SERVER_STORE="${TS_DATA_DIR}/server"
TS_LOG_DIR="${TS_DATA_DIR}/logs"
TOKEN_SHOWN_FILE="${TS_DATA_DIR}/.token_was_shown"

mkdir -p "${TS_DATA_DIR}" "${TS_LOG_DIR}" "${TS_SERVER_STORE}"

# Migrate legacy data from pre-1.1.0 (data was stored directly in /data/)
migrate_legacy_data() {
    local legacy_files=(
        "tsserver.sqlitedb"
        "tsserver.sqlitedb-shm"
        "tsserver.sqlitedb-wal"
        "ssh_host_rsa_key"
        "query_ip_allowlist.txt"
        "query_ip_denylist.txt"
    )
    local migrated=0
    for f in "${legacy_files[@]}"; do
        if [ -f "/data/${f}" ] && [ ! -f "${TS_SERVER_STORE}/${f}" ]; then
            cp -a "/data/${f}" "${TS_SERVER_STORE}/"
            migrated=1
        fi
    done
    for d in files sql; do
        if [ -d "/data/${d}" ] && [ ! -d "${TS_SERVER_STORE}/${d}" ]; then
            cp -a "/data/${d}" "${TS_SERVER_STORE}/"
            migrated=1
        fi
    done
    if [ "${migrated}" = "1" ]; then
        echo "[INFO] Legacy data migrated from /data/ to ${TS_SERVER_STORE}"
    fi
}

# Sync persisted data INTO /var/tsserver (which is a fixed volume mount, cannot be replaced)
sync_to_runtime() {
    if has_dir_contents "${TS_SERVER_STORE}"; then
        echo "[INFO] Restoring persisted server data into ${TS_RUNTIME_DIR}..."
        cp -a "${TS_SERVER_STORE}/." "${TS_RUNTIME_DIR}/"
    fi
}

# Sync runtime data BACK to persistent store after server stops
sync_from_runtime() {
    echo "[INFO] Syncing server data back to persistent store..."
    cp -a "${TS_RUNTIME_DIR}/." "${TS_SERVER_STORE}/" 2>/dev/null || true
}

migrate_legacy_data
sync_to_runtime

# Clear TS6 logs on every restart
rm -f "${TS_LOG_DIR}"/*.log 2>/dev/null || true
mkdir -p "${TS_LOG_DIR}"

EXISTING_SERVER_STATE=0
if has_dir_contents "${TS_SERVER_STORE}"; then
    EXISTING_SERVER_STATE=1
fi

# Stale token marker cleanup
if [ "${EXISTING_SERVER_STATE}" = "0" ] && [ -f "${TOKEN_SHOWN_FILE}" ]; then
    echo "[WARN] Stale token marker found without persisted server data — removing marker."
    rm -f "${TOKEN_SHOWN_FILE}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "   TeamSpeak 6 Server — Home Assistant Add-on"
echo "═══════════════════════════════════════════════════════════════"
echo "   Voice Port (UDP) : 9987"
echo "   SSH Query Port   : 10022"
echo "   HTTP Query Port  : 10080"
echo "   File Transfer    : 30033"
echo "   Log Level        : ${LOG_LEVEL}"
echo "   Persistent Store : ${TS_SERVER_STORE}"
echo "   Runtime Path     : ${TS_RUNTIME_DIR}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ -f "${TOKEN_SHOWN_FILE}" ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  WARNING                                                      ║"
    echo "║  The admin token is only visible in the log on FIRST start!  ║"
    echo "║  If you lost it, create a new token via ServerQuery:         ║"
    echo "║  telnet <pi-ip> 10011 -> login serveradmin <pw>              ║"
    echo "║  -> use sid=1 -> tokenadd tokentype=0 tokenid1=6 tokenid2=0  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
fi

export TSSERVER_LICENSE_ACCEPTED=accept
export TSSERVER_QUERY_SSH_ENABLED=1
export TSSERVER_QUERY_HTTP_ENABLED=1
export TSSERVER_LOG_LEVEL="${LOG_LEVEL}"

if [ -n "${QUERY_ADMIN_PASSWORD}" ]; then
    export TSSERVER_QUERY_ADMIN_PASSWORD="${QUERY_ADMIN_PASSWORD}"
fi

# Trap to sync data back on shutdown
trap sync_from_runtime EXIT

if [ ! -f "${TOKEN_SHOWN_FILE}" ] && [ "${EXISTING_SERVER_STATE}" = "0" ]; then
    echo "[INFO] Fresh server — waiting for admin token..."
    TOKEN_FOUND=0
    set +o pipefail
    tsserver --log-path="${TS_LOG_DIR}" 2>&1 | while IFS= read -r line; do
        echo "$line"
        if [ "${TOKEN_FOUND}" = "0" ] && echo "$line" | grep -q "token="; then
            TOKEN="$(echo "$line" | grep -o 'token=[^ ]*' | head -1)"
            echo ""
            echo "╔═══════════════════════════════════════════════════════════════╗"
            echo "║  ADMIN TOKEN — ONLY VISIBLE NOW! SAVE IT IMMEDIATELY!        ║"
            echo "╠═══════════════════════════════════════════════════════════════╣"
            printf '║  %-59s║\n' "${TOKEN}"
            echo "╠═══════════════════════════════════════════════════════════════╣"
            echo "║  Take a screenshot or write it down!                         ║"
            echo "║  After a restart this token will NOT appear in the log!      ║"
            echo "╚═══════════════════════════════════════════════════════════════╝"
            echo ""
            touch "${TOKEN_SHOWN_FILE}"
            TOKEN_FOUND=1
        fi
    done
else
    echo "[INFO] Starting TeamSpeak 6 with persisted server data..."
    exec tsserver --log-path="${TS_LOG_DIR}"
fi
