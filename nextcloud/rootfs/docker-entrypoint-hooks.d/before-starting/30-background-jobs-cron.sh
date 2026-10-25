#!/bin/bash
# Background jobs run through the crond started by ha-init.sh, so tell
# Nextcloud to stop running them on page loads (AJAX mode). Idempotent.
set -euo pipefail

php occ background:cron
