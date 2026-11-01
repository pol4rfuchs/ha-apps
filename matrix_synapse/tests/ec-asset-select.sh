#!/usr/bin/env bash
# Regression test for the Element Call asset selection in 05-download-webapps.sh.
#
# Besides element-call-<ver>.tar.gz, upstream also publishes
# element-call-embedded-<ver>.tar.gz (a different build). The earlier regex
# "element-call.*\.tar\.gz" matched both and relied on the order of the
# GitHub API. The filter is loaded from the real script, not duplicated.
# Runs without bashio and without network, needs only bash and jq.
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

# 1. Order as returned by GitHub (alphabetical)
[ "$(pick "${A_SHA},${A_MAIN},${A_EMB_SHA},${A_EMB}")" = "${WANT}" ] || { echo "normal order picked wrong asset"; exit 1; }

# 2. Reversed order: the embedded tarball comes before the normal one
[ "$(pick "${A_EMB},${A_EMB_SHA},${A_MAIN},${A_SHA}")" = "${WANT}" ] || { echo "reversed order picked wrong asset"; exit 1; }

# 3. A fork tag with "v" in the file name is matched as well
FORK="$(asset element-call-v0.27.0.tar.gz)"
[ "$(pick "${FORK}")" = "${BASE}/element-call-v0.27.0.tar.gz" ] || { echo "v-prefixed name not matched"; exit 1; }

# 4. Only embedded and checksums: select nothing (the script then uses the fallback URL)
[ -z "$(pick "${A_SHA},${A_EMB_SHA},${A_EMB}")" ] || { echo "embedded-only release must not match"; exit 1; }

echo "ec-asset-select tests passed"
