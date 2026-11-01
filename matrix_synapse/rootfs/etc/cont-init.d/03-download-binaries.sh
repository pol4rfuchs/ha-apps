#!/usr/bin/with-contenv bashio
# ============================================================================
# 03-download-binaries.sh — LiveKit Server + lk-jwt-service
#
# Like 05-download-webapps.sh: each binary tracks its installed version in
# its own .*_version file under /data/matrix/. On every start, "latest" is
# queried via the GitHub API and compared with the installed version —
# it is only downloaded again if they differ.
# Always exit 0 — the container must never crash because of this script.
# set +e: the bashio environment runs with set -e, which would otherwise abort
# the script (and, via s6, the container) on a single failed command, before
# the final exit 0 is reached.
# ============================================================================
set +e

if ! bashio::config.true 'enable_voice_calls'; then
    bashio::log.info "Voice calls disabled — binaries are not downloaded"
    exit 0
fi

BIN_DIR="/data/matrix/bin"
LK_VERSION_FILE="/data/matrix/.livekit-server_version"
LKJWT_VERSION_FILE="/data/matrix/.lk-jwt-service_version"
mkdir -p "${BIN_DIR}"

# pick_version <api-tag> <installed> <fallback> <name>
# Prints the target version. If the GitHub API is not reachable (e.g. rate limit
# of 60 requests/hour without authentication), the installed version stays.
# The fixed fallback applies only if nothing is installed yet: otherwise an
# API outage would downgrade to this old version on every start.
pick_version() {
    local api="$1" installed="$2" fallback="$3" name="$4"
    if [ -n "${api}" ] && [ "${api}" != "null" ]; then
        echo "${api}"
    elif [ -n "${installed}" ]; then
        bashio::log.warning "⚠️  ${name}: GitHub API not reachable — keeping installed version ${installed}" >&2
        echo "${installed}"
    else
        bashio::log.warning "⚠️  ${name}: GitHub API not reachable — installing fallback ${fallback}" >&2
        echo "${fallback}"
    fi
}

if [ "$(uname -m)" = "aarch64" ]; then
    LK_ARCH="arm64"
else
    LK_ARCH="amd64"
fi
bashio::log.info "🔍 Checking voice binaries (${LK_ARCH})..."

# ── LiveKit Server ───────────────────────────────────────────────────────────
LK_LATEST=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/livekit/livekit/releases/latest" \
    | jq -r '.tag_name // empty' 2>/dev/null)
LK_INSTALLED=$(cat "${LK_VERSION_FILE}" 2>/dev/null || echo "")
LK_LATEST=$(pick_version "${LK_LATEST}" "${LK_INSTALLED}" "v1.8.2" "LiveKit Server")

if [ "${LK_INSTALLED}" = "${LK_LATEST}" ] && [ -x "${BIN_DIR}/livekit-server" ]; then
    bashio::log.info "✅ LiveKit Server already up to date (${LK_INSTALLED})"
else
    bashio::log.info "📥 Downloading LiveKit Server ${LK_LATEST} (installed: ${LK_INSTALLED:-none})..."

    # Repo: livekit/livekit (not livekit/livekit-server — that was the bug!)
    LK_VER_CLEAN=$(echo "${LK_LATEST}" | tr -d 'v')
    LK_URL="https://github.com/livekit/livekit/releases/download/${LK_LATEST}/livekit_${LK_VER_CLEAN}_linux_${LK_ARCH}.tar.gz"
    bashio::log.info "   URL: ${LK_URL}"

    if wget -q --timeout=60 "${LK_URL}" -O /tmp/livekit.tar.gz 2>/dev/null; then
        if tar -xzf /tmp/livekit.tar.gz -C "${BIN_DIR}/" livekit-server 2>/dev/null; then
            chmod +x "${BIN_DIR}/livekit-server"
            echo "${LK_LATEST}" > "${LK_VERSION_FILE}"
            bashio::log.info "✅ LiveKit Server ${LK_LATEST} installed"
        else
            bashio::log.error "❌ LiveKit: tar extraction failed"
        fi
        rm -f /tmp/livekit.tar.gz
    else
        bashio::log.error "❌ LiveKit download failed (${LK_URL})"
        bashio::log.warning "   Voice calls will only work after another restart"
    fi
fi
[ -x "${BIN_DIR}/livekit-server" ] && ln -sf "${BIN_DIR}/livekit-server" /usr/local/bin/livekit-server

# ── lk-jwt-service ───────────────────────────────────────────────────────────
LKJWT_API_RESP=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/element-hq/lk-jwt-service/releases/latest" 2>/dev/null)
LKJWT_LATEST=$(echo "${LKJWT_API_RESP}" | jq -r '.tag_name // empty' 2>/dev/null)
LKJWT_INSTALLED=$(cat "${LKJWT_VERSION_FILE}" 2>/dev/null || echo "")
LKJWT_LATEST=$(pick_version "${LKJWT_LATEST}" "${LKJWT_INSTALLED}" "v0.1.0" "lk-jwt-service")

if [ "${LKJWT_INSTALLED}" = "${LKJWT_LATEST}" ] && [ -x "${BIN_DIR}/lk-jwt-service" ]; then
    bashio::log.info "✅ lk-jwt-service already up to date (${LKJWT_INSTALLED})"
else
    bashio::log.info "📥 Downloading lk-jwt-service ${LKJWT_LATEST} (installed: ${LKJWT_INSTALLED:-none})..."

    # Get the asset URL from the API, but safely
    LKJWT_URL=$(echo "${LKJWT_API_RESP}" \
        | jq -r ".assets[]? | select(.name | test(\"linux.*${LK_ARCH}\")) | .browser_download_url" \
        2>/dev/null | head -1)

    # Fallback: direct binary name
    if [ -z "${LKJWT_URL}" ]; then
        LKJWT_URL="https://github.com/element-hq/lk-jwt-service/releases/download/${LKJWT_LATEST}/lk-jwt-service-linux-${LK_ARCH}"
    fi
    bashio::log.info "   URL: ${LKJWT_URL}"

    if wget -q --timeout=60 "${LKJWT_URL}" -O /tmp/lkjwt.download 2>/dev/null; then
        if file /tmp/lkjwt.download 2>/dev/null | grep -q "gzip\|tar"; then
            tar -xzf /tmp/lkjwt.download -C "${BIN_DIR}/" 2>/dev/null
        else
            cp /tmp/lkjwt.download "${BIN_DIR}/lk-jwt-service"
        fi
        chmod +x "${BIN_DIR}/lk-jwt-service"
        echo "${LKJWT_LATEST}" > "${LKJWT_VERSION_FILE}"
        rm -f /tmp/lkjwt.download
        bashio::log.info "✅ lk-jwt-service ${LKJWT_LATEST} installed"
    else
        bashio::log.error "❌ lk-jwt-service download failed"
        bashio::log.warning "   Voice calls will only work after another restart"
    fi
fi
[ -x "${BIN_DIR}/lk-jwt-service" ] && ln -sf "${BIN_DIR}/lk-jwt-service" /usr/local/bin/lk-jwt-service

exit 0
