#!/usr/bin/env bashio
# shellcheck shell=bash
# Reads /data/options.json, exports all ND_* as ENV and writes
# /run/navidrome.env as a persistent copy for navidrome-run.sh.
# IMPORTANT: no 'readonly' for variables that other scripts use too —
# this script is loaded via 'source', so readonly stays in the shell!
set -e

JSONSOURCE="/data/options.json"
ENVFILE="/run/navidrome.env"

# --- Log level (applies to the app logs and to Navidrome) ---
LOG_LEVEL="$(bashio::config 'log_level')"
bashio::log.level "${LOG_LEVEL}"

bashio::log.info "Loading Navidrome configuration..."

# --- Required fields ---
ND_MUSICFOLDER="$(bashio::config 'ND_MUSICFOLDER')"
ND_DATAFOLDER="$(bashio::config 'ND_DATAFOLDER')"

if bashio::var.is_empty "${ND_MUSICFOLDER}"; then
  bashio::log.fatal "ND_MUSICFOLDER is not set — please configure the music folder!"
  exit 1
fi

# --- Migration: old, NON-persistent data path (bug up to v2.1.2) ---
# Up to v2.1.2 the default pointed to /config/addons_config/navidrome without
# "addon_config" being in the map block -> the path lived in the ephemeral
# container layer and was emptied on every restart/recreate (DB + admin user gone).
LEGACY_DATAFOLDER="/config/addons_config/navidrome"
if [ "${ND_DATAFOLDER}" != "${LEGACY_DATAFOLDER}" ] && [ -f "${LEGACY_DATAFOLDER}/navidrome.db" ] && [ ! -f "${ND_DATAFOLDER}/navidrome.db" ]; then
  bashio::log.warning "Migrating old data from ${LEGACY_DATAFOLDER} to ${ND_DATAFOLDER} (data folder bugfix)..."
  mkdir -p "${ND_DATAFOLDER}"
  cp -a "${LEGACY_DATAFOLDER}/." "${ND_DATAFOLDER}/"
  bashio::log.warning "Migration finished. Please check that your admin user is back."
fi

# --- Persistence guard ---
# Only /data is guaranteed to be persistent without a map entry. Every other
# path needs the matching map entry in config.yaml, otherwise the DB is lost
# again on the next container recreate.
case "${ND_DATAFOLDER}" in
  /data|/data/*) : ;;
  /config/addons_config/*)
    bashio::log.warning "ND_DATAFOLDER=${ND_DATAFOLDER} -- make sure 'addon_config' is in the map block of config.yaml, otherwise this path is NOT persistent!"
    ;;
  *)
    bashio::log.warning "ND_DATAFOLDER=${ND_DATAFOLDER} is neither /data nor /config/addons_config/* -- this path is most likely NOT persistent and the database will be lost on the next restart!"
    ;;
esac

# --- Create folders ---
mkdir -p "${ND_DATAFOLDER}"

if [ ! -d "${ND_MUSICFOLDER}" ]; then
  bashio::log.warning "Music folder '${ND_MUSICFOLDER}' does not exist yet."
else
  bashio::log.info "Music folder: ${ND_MUSICFOLDER}"
fi
bashio::log.info "Data folder : ${ND_DATAFOLDER}"

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
        bashio::log.info "Extra music folder: ${DIR} -> ${LINKNAME}"
      else
        bashio::log.info "Symlink exists: ${LINKNAME}"
      fi
    else
      bashio::log.warning "Extra music folder not found: ${DIR} (skipped)"
    fi
  done
fi

# --- Initialize the ENV file ---
mkdir -p /run
: > "${ENVFILE}"
chmod 600 "${ENVFILE}"

_env_write() {
  local KEY="$1"
  local VALUE="$2"
  export "${KEY}=${VALUE}"
  printf '%s=%s\n' "${KEY}" "$(printf '%q' "${VALUE}")" >> "${ENVFILE}"
}

# Always set the required fields
_env_write ND_MUSICFOLDER "${ND_MUSICFOLDER}"
_env_write ND_DATAFOLDER  "${ND_DATAFOLDER}"
_env_write ND_ADDRESS     "0.0.0.0"
_env_write ND_PORT        "4533"
# Navidrome uses "warn" instead of "warning"
case "${LOG_LEVEL}" in
  warning) _env_write ND_LOGLEVEL "warn" ;;
  *)       _env_write ND_LOGLEVEL "${LOG_LEVEL}" ;;
esac

# --- Export all ND_* from options.json ---
bashio::log.info "Exporting Navidrome variables:"

mapfile -t ALL_KEYS < <(jq -r 'keys[]' "${JSONSOURCE}")

for KEY in "${ALL_KEYS[@]}"; do
  [[ "${KEY}" != ND_* ]] && continue
  [[ "${KEY}" == "ND_MUSICFOLDER" ]]           && continue
  [[ "${KEY}" == "ND_DATAFOLDER" ]]            && continue
  [[ "${KEY}" == "ND_EXTRA_MUSIC_FOLDERS" ]]   && continue
  [[ "${KEY}" == "ND_LOGLEVEL" ]]              && continue  # comes from log_level

  # jq: boolean false → "false", null → "", empty → ""
  VALUE="$(jq -r --arg k "${KEY}" '
    .[$k] |
    if . == null then "" 
    elif type == "boolean" then tostring
    elif type == "number" then tostring
    else .
    end
  ' "${JSONSOURCE}")"

  # Skip empty strings (optional fields that are not set)
  [ -z "${VALUE}" ] && continue

  _env_write "${KEY}" "${VALUE}"

  if [[ "${KEY}" == *SECRET* ]] || [[ "${KEY}" == *APIKEY* ]] || [[ "${KEY}" == *PASSWORD* ]]; then
    bashio::log.blue "  ${KEY}=******"
  else
    bashio::log.blue "  ${KEY}=${VALUE}"
  fi
done

bashio::log.info "ENV file written: ${ENVFILE}"
bashio::log.info "Navidrome listens on 0.0.0.0:4533"
