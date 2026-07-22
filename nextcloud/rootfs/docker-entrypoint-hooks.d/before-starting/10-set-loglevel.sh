#!/bin/bash
# Re-applies the HA add-on's log_level option on every start, in case the
# user changed it since the last boot. Runs after installation/upgrade is
# already done, so occ is guaranteed to work here.
set -euo pipefail

if [[ -n "${NC_LOG_LEVEL_NUM:-}" ]]; then
    php occ config:system:set loglevel --value="${NC_LOG_LEVEL_NUM}" --type=integer
fi
