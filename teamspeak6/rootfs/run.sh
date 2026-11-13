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

# Restore persisted data into /var/tsserver.
# After copying, delete WAL and SHM so tsserver always starts from a clean
# checkpointed main DB. A stale WAL copied from /data would be replayed by
# SQLite on open and overwrite newer data that is already in the main DB.
sync_to_runtime() {
    if has_dir_contents "${TS_SERVER_STORE}"; then
        echo "[INFO] Restoring persisted server data into ${TS_RUNTIME_DIR}..."
        cp -a "${TS_SERVER_STORE}/." "${TS_RUNTIME_DIR}/"
        rm -f "${TS_RUNTIME_DIR}/"*.sqlitedb-wal \
              "${TS_RUNTIME_DIR}/"*.sqlitedb-shm 2>/dev/null || true
        echo "[INFO] Restore completed (WAL/SHM removed for clean start)."
    fi
}

# Back up runtime data to /data after the server stops.
# WAL and SHM are deleted from /data after the copy so the stored backup
# never carries a stale WAL that could corrupt the next restore.
sync_from_runtime() {
    echo "[INFO] Backing up server data to persistent store..."
    if cp -a "${TS_RUNTIME_DIR}/." "${TS_SERVER_STORE}/"; then
        rm -f "${TS_SERVER_STORE}/"*.sqlitedb-wal \
              "${TS_SERVER_STORE}/"*.sqlitedb-shm 2>/dev/null || true
        echo "[INFO] Backup completed."
    else
        echo "[ERROR] Backup failed — /data may be outdated!"
    fi
}

# Periodic copy while the server runs. The runtime DB lives in /var/tsserver
# (outside /data) and is otherwise only copied when the app stops cleanly, so a
# crash, OOM kill or power loss lost everything since the last start. The copy
# itself is done by /usr/local/bin/ts6-backup-sync (SQLite online backup, see
# there); the Supervisor runs the same script as backup_pre (config.yaml), so a
# Home Assistant backup does not depend on this interval.
#
# To spare the SD card / SSD, the script only runs when the database (or its
# WAL) changed since the last run.
TS_SYNC_INTERVAL="${TS_SYNC_INTERVAL:-300}"
periodic_sync() {
    local last_db_state="" db_state
    while sleep "${TS_SYNC_INTERVAL}"; do
        [ -f "${TS_RUNTIME_DIR}/tsserver.sqlitedb" ] || continue
        db_state="$(stat -c '%Y %s' "${TS_RUNTIME_DIR}/tsserver.sqlitedb" \
            "${TS_RUNTIME_DIR}/tsserver.sqlitedb-wal" 2>/dev/null || true)"
        if [ "${db_state}" != "${last_db_state}" ]; then
            if /usr/local/bin/ts6-backup-sync >/dev/null; then
                last_db_state="${db_state}"
                echo "[INFO] Periodic backup: server data saved to persistent store."
            else
                echo "[WARN] Periodic backup failed — /data may be outdated."
            fi
        else
            # Database unchanged: still pick up changed non-database files.
            /usr/local/bin/ts6-backup-sync --files-only >/dev/null || true
        fi
    done
}

migrate_legacy_data
rm -f "${TS_SERVER_STORE}/"*.tmp 2>/dev/null || true
sync_to_runtime

# Logs: TeamSpeak writes one ever growing file per virtual server and per
# instance (TSSERVER_APPEND_LOGS) instead of new files at every start. They are
# kept across restarts because TeamSpeak creates the log file of a virtual
# server only with its first log line; without the kept file the "Logs" page of
# TS6 Manager (logview) fails right after every start. Files over 5 MiB are cut
# to their last 1 MiB at start; the logs are not part of Home Assistant backups.
mkdir -p "${TS_LOG_DIR}"
rm -f "${TS_LOG_DIR}"/tsserver_20*.log 2>/dev/null || true   # per-start files of older versions of this app
for log_file in "${TS_LOG_DIR}"/*.log; do
    if [ -f "${log_file}" ] && [ "$(stat -c %s "${log_file}")" -gt 5242880 ]; then
        tail -c 1048576 "${log_file}" > "${log_file}.tmp" && mv -f "${log_file}.tmp" "${log_file}"
    fi
done
export TSSERVER_APPEND_LOGS=1

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
    echo "║  The admin token is only visible in the log on FIRST start!   ║"
    echo "║  If you lost it, create a new token via ServerQuery over SSH: ║"
    echo "║  ssh -p 10022 serveradmin@<ha-host> (query_admin_password)    ║"
    echo "║  -> use sid=1 -> tokenadd tokentype=0 tokenid1=6 tokenid2=0   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
fi

# Query flood-protection allowlist. TeamSpeak locks a query client out (default
# ban: 10 minutes) that sends more than 10 commands in 3 seconds. Another app, such
# as TS6 Manager, is a "foreign" client for the server, so the addresses in
# query_ip_allowlist.txt are exempt from that. The file is written at every start
# from the option query_ip_allowlist (plus loopback); manual edits are replaced.
# Only single addresses and networks that are not too wide are accepted: never a
# catch-all such as 0.0.0.0/0 or ::/0.
valid_allowlist_entry() {
    local entry="$1" addr prefix="" o
    addr="${entry%%/*}"
    [ "${addr}" != "${entry}" ] && prefix="${entry#*/}"
    if [[ "${addr}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        for o in "${BASH_REMATCH[@]:1:4}"; do
            [ "$((10#${o}))" -le 255 ] || return 1
        done
        [ -z "${prefix}" ] && return 0
        [[ "${prefix}" =~ ^[0-9]{1,2}$ ]] || return 1
        [ "$((10#${prefix}))" -ge 16 ] && [ "$((10#${prefix}))" -le 32 ]
    elif [[ "${addr}" == *:* && "${addr}" =~ ^[0-9a-fA-F:]+$ ]]; then
        [ -z "${prefix}" ] && return 0
        [[ "${prefix}" =~ ^[0-9]{1,3}$ ]] || return 1
        [ "$((10#${prefix}))" -ge 48 ] && [ "$((10#${prefix}))" -le 128 ]
    else
        return 1
    fi
}

write_query_allowlist() {
    local file="${TS_RUNTIME_DIR}/query_ip_allowlist.txt" entry
    local -a entries=()
    mapfile -t entries < <(jq -r '.query_ip_allowlist[]? // empty' "${OPTIONS_FILE}")
    for entry in "${entries[@]}"; do
        [ -n "${entry}" ] || continue
        if ! valid_allowlist_entry "${entry}"; then
            echo "[ERROR] query_ip_allowlist: '${entry}' is not accepted. Use an IP address or a network such as 172.30.32.0/23 (IPv4 prefix 16-32, IPv6 prefix 48-128); catch-all networks like 0.0.0.0/0 are refused."
            exit 1
        fi
    done
    mkdir -p "${TS_RUNTIME_DIR}"
    { echo "127.0.0.1"; echo "::1"; printf '%s\n' "${entries[@]}"; } | awk 'NF && !seen[$0]++' > "${file}"
    echo "[INFO] Query flood-protection allowlist: $(paste -sd' ' "${file}")"
}
write_query_allowlist

export TSSERVER_LICENSE_ACCEPTED=accept
export TSSERVER_QUERY_SSH_ENABLED=1
export TSSERVER_QUERY_HTTP_ENABLED=1
# Upstream allows unauthenticated guest sessions on the SSH and HTTP query
# interfaces by default. Nobody needs them here (the API key or the serveradmin
# password is used), so switch them off.
export TSSERVER_QUERY_SSH_ALLOW_GUEST=0
export TSSERVER_QUERY_HTTP_ALLOW_GUEST=0
export TSSERVER_LOG_LEVEL="${LOG_LEVEL}"

if [ -n "${QUERY_ADMIN_PASSWORD}" ]; then
    export TSSERVER_QUERY_ADMIN_PASSWORD="${QUERY_ADMIN_PASSWORD}"
fi

# Shutdown handler:
# 1. PASSIVE checkpoint while tsserver is alive — WAL header is valid, all
#    committed frames are flushed to the main DB (verified: 0|30|30, 0|116|116)
# 2. Send SIGTERM, wait for clean exit
# 3. Delete WAL + SHM from runtime so the backup contains only the clean main DB
# 4. Copy to /data
TS_PID=""
SYNC_PID=""
_CLEANUP_DONE=0
cleanup() {
    [ "${_CLEANUP_DONE}" = "1" ] && return
    _CLEANUP_DONE=1
    if [ -n "${SYNC_PID}" ]; then
        kill "${SYNC_PID}" 2>/dev/null || true
        wait "${SYNC_PID}" 2>/dev/null || true
    fi
    if [ -n "${TS_PID}" ]; then
        echo "[INFO] Pre-shutdown WAL checkpoint (server still running)..."
        sqlite3 "${TS_RUNTIME_DIR}/tsserver.sqlitedb" \
            "PRAGMA wal_checkpoint(PASSIVE);" 2>/dev/null \
            && echo "[INFO] WAL checkpoint completed." \
            || echo "[WARN] WAL checkpoint failed."
        kill -TERM "${TS_PID}" 2>/dev/null || true
        wait "${TS_PID}" 2>/dev/null || true
        echo "[INFO] Removing WAL/SHM before backup..."
        rm -f "${TS_RUNTIME_DIR}/"*.sqlitedb-wal \
              "${TS_RUNTIME_DIR}/"*.sqlitedb-shm 2>/dev/null || true
    fi
    sync_from_runtime
}
trap cleanup EXIT TERM INT

periodic_sync &
SYNC_PID=$!

if [ ! -f "${TOKEN_SHOWN_FILE}" ] && [ "${EXISTING_SERVER_STATE}" = "0" ]; then
    echo "[INFO] Fresh server — waiting for admin token..."
    _FIFO=$(mktemp -u /tmp/ts6_output.XXXXXX)
    mkfifo "${_FIFO}"
    set +o pipefail
    tsserver --log-path="${TS_LOG_DIR}" >"${_FIFO}" 2>&1 &
    TS_PID=$!
    TOKEN_FOUND=0
    while IFS= read -r line; do
        # On the very first start TeamSpeak prints the generated ServerQuery
        # password and API key in clear text. Hide both so they never end up in
        # the Supervisor log; query_admin_password is the way to get a known
        # password (it is applied at every start).
        printf '%s\n' "$line" | sed -E 's/(password|apikey)= "[^"]*"/\1= "<hidden>"/g'
        if [ "${TOKEN_FOUND}" = "0" ] && echo "$line" | grep -q "token="; then
            TOKEN="$(echo "$line" | grep -o 'token=[^ ]*' | head -1)"
            echo ""
            echo "╔═══════════════════════════════════════════════════════════════╗"
            echo "║  ADMIN TOKEN — ONLY VISIBLE NOW! SAVE IT IMMEDIATELY!         ║"
            echo "╠═══════════════════════════════════════════════════════════════╣"
            printf '║  %-59s║\n' "${TOKEN}"
            echo "╠═══════════════════════════════════════════════════════════════╣"
            echo "║  Take a screenshot or write it down!                          ║"
            echo "║  After a restart this token will NOT appear in the log!       ║"
            echo "╚═══════════════════════════════════════════════════════════════╝"
            echo ""
            touch "${TOKEN_SHOWN_FILE}"
            TOKEN_FOUND=1
            if [ -z "${QUERY_ADMIN_PASSWORD}" ]; then
                echo "[INFO] The generated ServerQuery password is not shown in the log."
                echo "[INFO] To use ServerQuery, set query_admin_password and restart the app."
            fi
        fi
    done < "${_FIFO}"
    rm -f "${_FIFO}"
else
    echo "[INFO] Starting TeamSpeak 6 with persisted server data..."
    tsserver --log-path="${TS_LOG_DIR}" &
    TS_PID=$!
    wait "${TS_PID}" || true
fi
