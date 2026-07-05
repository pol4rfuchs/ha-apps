#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

bashio::log.level "$(bashio::config 'log_level')"
bashio::log.info "Starting Restic Backup add-on ($(bashio::app.version))..."

REPOSITORY="$(bashio::config 'repository')"
CRON_SCHEDULE="$(bashio::config 'cron_schedule')"
RUN_ON_START="$(bashio::config 'run_on_start')"

export RESTIC_REPOSITORY="${REPOSITORY}"
export RESTIC_PASSWORD="$(bashio::config 'restic_password')"

# Optional S3/B2/MinIO-compatible credentials — only exported if set, so a
# purely local repository (default: /share/restic-backup/repo) never needs
# them and nothing empty leaks into the environment.
if bashio::config.has_value 'aws_access_key_id'; then
    export AWS_ACCESS_KEY_ID="$(bashio::config 'aws_access_key_id')"
fi
if bashio::config.has_value 'aws_secret_access_key'; then
    export AWS_SECRET_ACCESS_KEY="$(bashio::config 'aws_secret_access_key')"
fi
if bashio::config.has_value 'aws_default_region'; then
    export AWS_DEFAULT_REGION="$(bashio::config 'aws_default_region')"
fi

# Initialize the repository on first run. `restic snapshots` is used as a
# cheap "does this repo already exist" probe instead of parsing init errors.
if ! restic snapshots --json >/dev/null 2>&1; then
    bashio::log.info "No existing restic repository found at ${REPOSITORY} — initializing..."
    if restic init; then
        bashio::log.info "Repository initialized."
    else
        bashio::log.fatal "Failed to initialize restic repository. Check 'repository' and 'restic_password'."
        exit 1
    fi
else
    bashio::log.info "Existing restic repository found."
fi

# Write the crontab. Running via dcron rather than a sleep-loop so
# CRON_SCHEDULE follows normal cron syntax and DST/timezone changes are
# handled by the system clock instead of drifting sleep math.
echo "${CRON_SCHEDULE} /usr/local/bin/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" > /etc/crontabs/root
bashio::log.info "Backup schedule: ${CRON_SCHEDULE}"

if bashio::var.true "${RUN_ON_START}"; then
    bashio::log.info "run_on_start enabled — running an initial backup now..."
    /usr/local/bin/backup.sh || bashio::log.warning "Initial backup run failed, continuing — next attempt follows the cron schedule."
fi

bashio::log.info "Handing off to crond."
exec crond -f -d 8
