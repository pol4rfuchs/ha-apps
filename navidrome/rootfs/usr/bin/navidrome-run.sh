#!/bin/bash
# Starts Navidrome.
# Sources /run/navidrome.env so all ND_* variables from the init phase
# actually arrive.
set -e

readonly ENVFILE="/run/navidrome.env"

# Load the ENV file (written by 10-config.sh)
if [ -f "${ENVFILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  . "${ENVFILE}"
  set +a
  echo "[run] ENV loaded from ${ENVFILE}"
else
  echo "[run] WARNING: ${ENVFILE} not found — ENV may be missing!"
fi

# Sanity check
if [ -z "${ND_MUSICFOLDER}" ]; then
  echo "[run] ERROR: ND_MUSICFOLDER is empty after ENV load. Aborting."
  exit 1
fi

echo "[run] ND_MUSICFOLDER = ${ND_MUSICFOLDER}"
echo "[run] ND_DATAFOLDER  = ${ND_DATAFOLDER}"
echo "[run] ND_BASEURL     = ${ND_BASEURL:-<not set>}"

# Navidrome in the foreground (exec = correct PID 1 signal handling)
echo "[run] Starting Navidrome..."
exec /app/navidrome
