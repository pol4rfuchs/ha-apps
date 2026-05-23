#!/usr/bin/env bashio
# shellcheck shell=bash
set -e

bashio::log.blue "-----------------------------------------------------------"
bashio::log.blue "  Addon : $(bashio::addon.name)"
bashio::log.blue "  $(bashio::addon.description)"
bashio::log.blue "-----------------------------------------------------------"
bashio::log.blue "  Addon version : $(bashio::addon.version)"

if bashio::var.true "$(bashio::addon.update_available)"; then
  bashio::log.magenta "  Update available! Latest: $(bashio::addon.version_latest)"
else
  bashio::log.green "  Running latest version"
fi

bashio::log.blue "  System : $(bashio::info.operating_system) ($(bashio::info.arch)/$(bashio::info.machine))"
bashio::log.blue "  HA Core     : $(bashio::info.homeassistant)"
bashio::log.blue "  Supervisor  : $(bashio::info.supervisor)"
bashio::log.blue "-----------------------------------------------------------"
bashio::log.blue "  Navidrome binary: $(/app/navidrome --version 2>&1 | head -1 || echo 'n/a')"
bashio::log.blue "-----------------------------------------------------------"

# PUID / PGID
if bashio::config.has_value "PUID" && bashio::config.has_value "PGID"; then
  PUID="$(bashio::config 'PUID')"
  PGID="$(bashio::config 'PGID')"
  bashio::log.blue "  PUID: ${PUID}  PGID: ${PGID}"
  usermod -o -u "${PUID}" navidrome 2>/dev/null || true
  groupmod -o -g "${PGID}" navidrome 2>/dev/null || true
fi
bashio::log.blue "-----------------------------------------------------------"
