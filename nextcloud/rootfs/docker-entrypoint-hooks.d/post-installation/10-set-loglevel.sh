#!/bin/bash
# Applies the HA add-on's log_level option to Nextcloud's config.php.
# Runs via the official Nextcloud image's docker-entrypoint-hooks.d
# mechanism, right after installation — occ isn't usable before this point
# because config.php doesn't exist yet on a fresh install.
set -euo pipefail

if [[ -n "${NC_LOG_LEVEL_NUM:-}" ]]; then
    php occ config:system:set loglevel --value="${NC_LOG_LEVEL_NUM}" --type=integer
fi
