#!/usr/bin/env bash
# Regressionstest für die Element-Call-Asset-Auswahl in 05-download-webapps.sh.
#
# Upstream veröffentlicht neben element-call-<ver>.tar.gz auch
# element-call-embedded-<ver>.tar.gz (anderer Build). Die frühere Regex
# "element-call.*\.tar\.gz" traf beide und verließ sich auf die Reihenfolge der
# GitHub-API. Der Filter wird aus dem echten Script geladen, nicht dupliziert.
# Läuft ohne bashio und ohne Netzwerk, braucht nur bash und jq.
set -euo pipefail
S="$(dirname "$0")/../rootfs/etc/cont-init.d/05-download-webapps.sh"

FILTER="$(sed -n "s/^ *EC_ASSET_FILTER='\(.*\)'\$/\1/p" "${S}")"
[ -n "${FILTER}" ] || { echo "EC_ASSET_FILTER not found in ${S}"; exit 1; }

BASE="https://github.com/element-hq/element-call/releases/download/v0.26.1"
asset() { printf '{"name":"%s","browser_download_url":"%s/%s"}' "$1" "${BASE}" "$1"; }
A_SHA="$(asset element-call-0.26.1.sha256)"
A_MAIN="$(asset element-call-0.26.1.tar.gz)"
A_EMB_SHA="$(asset element-call-embedded-0.26.1.sha256)"
A_EMB="$(asset element-call-embedded-0.26.1.tar.gz)"
WANT="${BASE}/element-call-0.26.1.tar.gz"

pick() { printf '{"assets":[%s]}' "$1" | jq -r "${FILTER}" | head -1; }

# 1. Reihenfolge wie bei GitHub (alphabetisch)
[ "$(pick "${A_SHA},${A_MAIN},${A_EMB_SHA},${A_EMB}")" = "${WANT}" ] || { echo "normal order picked wrong asset"; exit 1; }

# 2. Umgekehrte Reihenfolge: das embedded-Tarball steht vor dem normalen
[ "$(pick "${A_EMB},${A_EMB_SHA},${A_MAIN},${A_SHA}")" = "${WANT}" ] || { echo "reversed order picked wrong asset"; exit 1; }

# 3. Fork-Tag mit "v" im Dateinamen wird ebenfalls erkannt
FORK="$(asset element-call-v0.27.0.tar.gz)"
[ "$(pick "${FORK}")" = "${BASE}/element-call-v0.27.0.tar.gz" ] || { echo "v-prefixed name not matched"; exit 1; }

# 4. Nur embedded und Prüfsummen: nichts auswählen (das Script nimmt dann die Fallback-URL)
[ -z "$(pick "${A_SHA},${A_EMB_SHA},${A_EMB}")" ] || { echo "embedded-only release must not match"; exit 1; }

echo "ec-asset-select tests passed"
