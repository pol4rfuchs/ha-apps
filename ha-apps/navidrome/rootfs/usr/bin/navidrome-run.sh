#!/bin/bash
# Startet Navidrome.
# Sourct /run/navidrome.env damit alle ND_* Variablen aus der Init-Phase
# auch wirklich ankommen.
set -e

readonly ENVFILE="/run/navidrome.env"

# ENV-Datei laden (aus 10-config.sh geschrieben)
if [ -f "${ENVFILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  . "${ENVFILE}"
  set +a
  echo "[run] ENV geladen aus ${ENVFILE}"
else
  echo "[run] WARNUNG: ${ENVFILE} nicht gefunden — ENV fehlt möglicherweise!"
fi

# Sanity check
if [ -z "${ND_MUSICFOLDER}" ]; then
  echo "[run] FEHLER: ND_MUSICFOLDER ist leer nach ENV-Load. Abbruch."
  exit 1
fi

echo "[run] ND_MUSICFOLDER = ${ND_MUSICFOLDER}"
echo "[run] ND_DATAFOLDER  = ${ND_DATAFOLDER}"
echo "[run] ND_BASEURL     = ${ND_BASEURL:-<nicht gesetzt>}"

# Navidrome im Vordergrund (exec = PID 1 Signal-Handling korrekt)
echo "[run] Starte Navidrome..."
exec /app/navidrome
