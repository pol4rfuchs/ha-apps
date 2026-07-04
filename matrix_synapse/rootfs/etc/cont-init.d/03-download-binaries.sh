#!/usr/bin/with-contenv bashio
# ============================================================================
# 03-download-binaries.sh — LiveKit Server + lk-jwt-service
#
# Wie 05-download-webapps.sh: jede Binary trackt ihre installierte Version in
# einer eigenen .*_version Datei unter /data/matrix/. Bei jedem Start wird
# "latest" per GitHub API abgefragt und mit der installierten Version
# verglichen — nur bei Unterschied wird neu geladen.
# Immer exit 0 — Container darf nie wegen diesem Script crashen.
# ============================================================================

if ! bashio::config.true 'enable_voice_calls'; then
    bashio::log.info "Voice Calls deaktiviert — Binaries werden nicht geladen"
    exit 0
fi

BIN_DIR="/data/matrix/bin"
LK_VERSION_FILE="/data/matrix/.livekit-server_version"
LKJWT_VERSION_FILE="/data/matrix/.lk-jwt-service_version"
mkdir -p "${BIN_DIR}"

if [ "$(uname -m)" = "aarch64" ]; then
    LK_ARCH="arm64"
else
    LK_ARCH="amd64"
fi
bashio::log.info "🔍 Prüfe Voice-Binaries (${LK_ARCH})..."

# ── LiveKit Server ───────────────────────────────────────────────────────────
LK_LATEST=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/livekit/livekit/releases/latest" \
    | jq -r '.tag_name // empty' 2>/dev/null)
[ -z "${LK_LATEST}" ] && LK_LATEST="v1.8.2"
LK_INSTALLED=$(cat "${LK_VERSION_FILE}" 2>/dev/null || echo "")

if [ "${LK_INSTALLED}" = "${LK_LATEST}" ] && [ -x "${BIN_DIR}/livekit-server" ]; then
    bashio::log.info "✅ LiveKit Server bereits aktuell (${LK_INSTALLED})"
else
    bashio::log.info "📥 Lade LiveKit Server ${LK_LATEST} (installiert: ${LK_INSTALLED:-keine})..."

    # Repo: livekit/livekit (nicht livekit/livekit-server — das war der Bug!)
    LK_VER_CLEAN=$(echo "${LK_LATEST}" | tr -d 'v')
    LK_URL="https://github.com/livekit/livekit/releases/download/${LK_LATEST}/livekit_${LK_VER_CLEAN}_linux_${LK_ARCH}.tar.gz"
    bashio::log.info "   URL: ${LK_URL}"

    if wget -q --timeout=60 "${LK_URL}" -O /tmp/livekit.tar.gz 2>/dev/null; then
        if tar -xzf /tmp/livekit.tar.gz -C "${BIN_DIR}/" livekit-server 2>/dev/null; then
            chmod +x "${BIN_DIR}/livekit-server"
            echo "${LK_LATEST}" > "${LK_VERSION_FILE}"
            bashio::log.info "✅ LiveKit Server ${LK_LATEST} installiert"
        else
            bashio::log.error "❌ LiveKit: tar Extraktion fehlgeschlagen"
        fi
        rm -f /tmp/livekit.tar.gz
    else
        bashio::log.error "❌ LiveKit Download fehlgeschlagen (${LK_URL})"
        bashio::log.warning "   Voice Calls funktionieren erst nach erneutem Neustart"
    fi
fi
[ -x "${BIN_DIR}/livekit-server" ] && ln -sf "${BIN_DIR}/livekit-server" /usr/local/bin/livekit-server

# ── lk-jwt-service ───────────────────────────────────────────────────────────
LKJWT_API_RESP=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/element-hq/lk-jwt-service/releases/latest" 2>/dev/null)
LKJWT_LATEST=$(echo "${LKJWT_API_RESP}" | jq -r '.tag_name // empty' 2>/dev/null)
[ -z "${LKJWT_LATEST}" ] && LKJWT_LATEST="v0.1.0"
LKJWT_INSTALLED=$(cat "${LKJWT_VERSION_FILE}" 2>/dev/null || echo "")

if [ "${LKJWT_INSTALLED}" = "${LKJWT_LATEST}" ] && [ -x "${BIN_DIR}/lk-jwt-service" ]; then
    bashio::log.info "✅ lk-jwt-service bereits aktuell (${LKJWT_INSTALLED})"
else
    bashio::log.info "📥 Lade lk-jwt-service ${LKJWT_LATEST} (installiert: ${LKJWT_INSTALLED:-keine})..."

    # Asset-URL aus API holen, aber sicher
    LKJWT_URL=$(echo "${LKJWT_API_RESP}" \
        | jq -r ".assets[]? | select(.name | test(\"linux.*${LK_ARCH}\")) | .browser_download_url" \
        2>/dev/null | head -1)

    # Fallback: direkter Binary-Name
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
        bashio::log.info "✅ lk-jwt-service ${LKJWT_LATEST} installiert"
    else
        bashio::log.error "❌ lk-jwt-service Download fehlgeschlagen"
        bashio::log.warning "   Voice Calls funktionieren erst nach erneutem Neustart"
    fi
fi
[ -x "${BIN_DIR}/lk-jwt-service" ] && ln -sf "${BIN_DIR}/lk-jwt-service" /usr/local/bin/lk-jwt-service

exit 0
