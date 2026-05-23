#!/usr/bin/env bashio
# shellcheck shell=bash
# Liest /data/options.json, exportiert alle ND_* als ENV und schreibt
# /run/navidrome.env als persistente Kopie für navidrome-run.sh.
# WICHTIG: kein 'readonly' bei Variablen die auch andere Scripts nutzen —
# dieses Script wird via 'source' eingelesen, readonly bleibt in der Shell!
set -e

JSONSOURCE="/data/options.json"
ENVFILE="/run/navidrome.env"

bashio::log.info "Loading Navidrome configuration..."

# --- Pflichtfelder ---
ND_MUSICFOLDER="$(bashio::config 'ND_MUSICFOLDER')"
ND_DATAFOLDER="$(bashio::config 'ND_DATAFOLDER')"

if bashio::var.is_empty "${ND_MUSICFOLDER}"; then
  bashio::log.fatal "ND_MUSICFOLDER ist nicht gesetzt — bitte Musikordner konfigurieren!"
  exit 1
fi

# --- Ordner anlegen ---
mkdir -p "${ND_DATAFOLDER}"

if [ ! -d "${ND_MUSICFOLDER}" ]; then
  bashio::log.warning "Musikordner '${ND_MUSICFOLDER}' existiert noch nicht."
else
  bashio::log.info "Musikordner : ${ND_MUSICFOLDER}"
fi
bashio::log.info "Datenordner : ${ND_DATAFOLDER}"

# --- Multiple music folders via Symlinks ---
if bashio::config.has_value 'ND_EXTRA_MUSIC_FOLDERS'; then
  EXTRA="$(bashio::config 'ND_EXTRA_MUSIC_FOLDERS')"
  IFS=',' read -ra EXTRA_DIRS <<< "${EXTRA}"
  for DIR in "${EXTRA_DIRS[@]}"; do
    DIR="${DIR// /}"
    [ -z "${DIR}" ] && continue
    LINKNAME="${ND_MUSICFOLDER}/$(basename "${DIR}")"
    if [ -d "${DIR}" ]; then
      if [ ! -L "${LINKNAME}" ]; then
        ln -sf "${DIR}" "${LINKNAME}"
        bashio::log.info "Extra-Musikordner: ${DIR} -> ${LINKNAME}"
      else
        bashio::log.info "Symlink vorhanden: ${LINKNAME}"
      fi
    else
      bashio::log.warning "Extra-Musikordner nicht gefunden: ${DIR} (übersprungen)"
    fi
  done
fi

# --- ENV-Datei initialisieren ---
mkdir -p /run
: > "${ENVFILE}"
chmod 600 "${ENVFILE}"

_env_write() {
  local KEY="$1"
  local VALUE="$2"
  export "${KEY}=${VALUE}"
  printf '%s=%s\n' "${KEY}" "$(printf '%q' "${VALUE}")" >> "${ENVFILE}"
}

# Pflichtfelder immer setzen
_env_write ND_MUSICFOLDER "${ND_MUSICFOLDER}"
_env_write ND_DATAFOLDER  "${ND_DATAFOLDER}"
_env_write ND_ADDRESS     "0.0.0.0"
_env_write ND_PORT        "4533"

# HA Ingress:
# ND_BASEURL NICHT setzen — nginx (sub_filter) übernimmt das href-Rewriting.
# X-Frame-Options: SAMEORIGIN wird von nginx als Header gesetzt.

# --- Alle ND_* aus options.json exportieren ---
bashio::log.info "Exportiere Navidrome-Variablen:"

mapfile -t ALL_KEYS < <(jq -r 'keys[]' "${JSONSOURCE}")

for KEY in "${ALL_KEYS[@]}"; do
  [[ "${KEY}" != ND_* ]] && continue
  [[ "${KEY}" == "ND_MUSICFOLDER" ]]           && continue
  [[ "${KEY}" == "ND_DATAFOLDER" ]]            && continue
  [[ "${KEY}" == "ND_EXTRA_MUSIC_FOLDERS" ]]   && continue

  # jq: boolean false → "false", null → "", leer → ""
  VALUE="$(jq -r --arg k "${KEY}" '
    .[$k] |
    if . == null then "" 
    elif type == "boolean" then tostring
    elif type == "number" then tostring
    else .
    end
  ' "${JSONSOURCE}")"

  # Leere Strings überspringen (optionale Felder die nicht gesetzt sind)
  [ -z "${VALUE}" ] && continue

  _env_write "${KEY}" "${VALUE}"

  if [[ "${KEY}" == *SECRET* ]] || [[ "${KEY}" == *APIKEY* ]] || [[ "${KEY}" == *PASSWORD* ]]; then
    bashio::log.blue "  ${KEY}=******"
  else
    bashio::log.blue "  ${KEY}=${VALUE}"
  fi
done

bashio::log.info "ENV-Datei geschrieben: ${ENVFILE}"
bashio::log.info "Navidrome lauscht auf 0.0.0.0:4533"
