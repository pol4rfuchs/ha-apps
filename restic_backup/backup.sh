#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
#
# Runs one restic backup cycle: backup -> prune (retention) -> ntfy notify.
# Invoked either by cron (see run.sh) or once at startup if run_on_start=true.
set -uo pipefail  # no -e: we need to reach the ntfy notification even on failure

LOCK_FILE="/tmp/restic-backup.lock"
if [ -e "${LOCK_FILE}" ]; then
    bashio::log.warning "Backup already in progress (lock file present) — skipping this run."
    exit 0
fi
touch "${LOCK_FILE}"
trap 'rm -f "${LOCK_FILE}"' EXIT

START_TIME=$(date +%s)
STATUS="success"
SUMMARY_LINES=()

# --- build backup path + exclude arguments from the two list options ------
mapfile -t BACKUP_PATHS < <(bashio::config 'backup_paths')
mapfile -t EXCLUDE_PATTERNS < <(bashio::config 'exclude_patterns')

if [ "${#BACKUP_PATHS[@]}" -eq 0 ]; then
    bashio::log.fatal "No backup_paths configured — nothing to back up."
    exit 1
fi

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    [ -n "${pattern}" ] && EXCLUDE_ARGS+=(--exclude "${pattern}")
done

# --- run the backup ---------------------------------------------------------
bashio::log.info "Starting restic backup of: ${BACKUP_PATHS[*]}"
BACKUP_JSON=$(mktemp)
if restic backup "${BACKUP_PATHS[@]}" "${EXCLUDE_ARGS[@]}" --json > "${BACKUP_JSON}" 2>/tmp/restic-backup.err; then
    ADDED=$(jq -rs 'map(select(.message_type=="summary")) | last | .data_added // 0' "${BACKUP_JSON}" 2>/dev/null || echo "?")
    FILES=$(jq -rs 'map(select(.message_type=="summary")) | last | .files_new // 0' "${BACKUP_JSON}" 2>/dev/null || echo "?")
    SUMMARY_LINES+=("Backup OK — new data: ${ADDED} bytes, new files: ${FILES}")
    bashio::log.info "Backup finished successfully."
else
    STATUS="failure"
    SUMMARY_LINES+=("Backup FAILED — see add-on log for details")
    bashio::log.error "restic backup failed: $(tail -n 20 /tmp/restic-backup.err)"
fi
rm -f "${BACKUP_JSON}"

# --- retention / prune (only if the backup itself succeeded) ---------------
if [ "${STATUS}" = "success" ]; then
    RETENTION_DAILY="$(bashio::config 'retention_daily')"
    RETENTION_WEEKLY="$(bashio::config 'retention_weekly')"
    RETENTION_MONTHLY="$(bashio::config 'retention_monthly')"

    bashio::log.info "Applying retention: daily=${RETENTION_DAILY} weekly=${RETENTION_WEEKLY} monthly=${RETENTION_MONTHLY}"
    if restic forget \
        --keep-daily "${RETENTION_DAILY}" \
        --keep-weekly "${RETENTION_WEEKLY}" \
        --keep-monthly "${RETENTION_MONTHLY}" \
        --prune >/tmp/restic-prune.log 2>&1; then
        SUMMARY_LINES+=("Retention applied cleanly.")
    else
        SUMMARY_LINES+=("Retention/prune step FAILED — old snapshots may be piling up")
        bashio::log.warning "restic forget/prune failed: $(tail -n 20 /tmp/restic-prune.log)"
        # Don't flip STATUS to failure for this — the backup itself is safe,
        # but it's worth surfacing in the ntfy notification below.
    fi
fi

DURATION=$(( $(date +%s) - START_TIME ))
SUMMARY="$(printf '%s\n' "${SUMMARY_LINES[@]}") (took ${DURATION}s)"

# --- ntfy notification -------------------------------------------------------
NTFY_URL="$(bashio::config 'ntfy_url')"
NTFY_TOPIC="$(bashio::config 'ntfy_topic')"

if [ -n "${NTFY_URL}" ] && [ -n "${NTFY_TOPIC}" ]; then
    NTFY_TARGET="${NTFY_URL%/}/${NTFY_TOPIC}"
    NTFY_TITLE="Restic Backup: ${STATUS}"
    NTFY_PRIORITY="default"
    NTFY_TAGS="floppy_disk"
    [ "${STATUS}" = "failure" ] && NTFY_PRIORITY="urgent" && NTFY_TAGS="rotating_light"

    CURL_AUTH=()
    NTFY_USERNAME="$(bashio::config 'ntfy_username')"
    NTFY_PASSWORD="$(bashio::config 'ntfy_password')"
    if [ -n "${NTFY_USERNAME}" ] && [ -n "${NTFY_PASSWORD}" ]; then
        CURL_AUTH=(-u "${NTFY_USERNAME}:${NTFY_PASSWORD}")
    fi

    curl -fsS "${CURL_AUTH[@]}" \
        -H "Title: ${NTFY_TITLE}" \
        -H "Priority: ${NTFY_PRIORITY}" \
        -H "Tags: ${NTFY_TAGS}" \
        -d "${SUMMARY}" \
        "${NTFY_TARGET}" >/dev/null \
        || bashio::log.warning "Failed to send ntfy notification (backup result above still stands)."
else
    bashio::log.debug "ntfy_url/ntfy_topic not configured — skipping notification."
fi

[ "${STATUS}" = "success" ] && exit 0 || exit 1
