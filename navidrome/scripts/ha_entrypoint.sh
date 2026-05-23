#!/bin/bash
set -e

echo "[entrypoint] Navidrome HA Add-on starting..."

# Bashio laden — einmal hier, gilt für alle gesourcten Scripts
if [ -f /usr/lib/bashio/bashio.sh ]; then
  # shellcheck source=/dev/null
  source /usr/lib/bashio/bashio.sh
  echo "[entrypoint] bashio loaded"
else
  echo "[entrypoint] ERROR: bashio not found at /usr/lib/bashio/bashio.sh"
  exit 1
fi

for script in /etc/cont-init.d/*; do
  [ -f "$script" ] || continue
  chmod +x "$script"
  echo "[entrypoint] Sourcing: $script"
  # shellcheck source=/dev/null
  . "$script" || { echo "[entrypoint] ERROR: $script failed (exit $?)"; exit 1; }
done

echo "[entrypoint] Init complete — launching Navidrome"
exec /usr/bin/navidrome-run.sh
