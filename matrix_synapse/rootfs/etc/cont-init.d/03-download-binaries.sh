#!/usr/bin/with-contenv bashio
# ============================================================================
# 03-download-binaries.sh — LiveKit + lk-jwt-service beim ersten Start laden
# Immer exit 0 — Container darf nie wegen diesem Script crashen
# ============================================================================

if ! bashio::config.true 'enable_voice_calls'; then
    bashio::log.info "Voice Calls deaktiviert — Binaries werden nicht geladen"
    exit 0
fi

BIN_DIR="/data/matrix/bin"
BIN_MARKER="/data/matrix/.binaries_downloaded"
mkdir -p "${BIN_DIR}"

if [ "$(uname -m)" = "aarch64" ]; then
    LK_ARCH="arm64"
else
    LK_ARCH="amd64"
fi
bashio::log.info "📦 Lade Voice-Binaries (${LK_ARCH})..."

if [ -f "${BIN_MARKER}" ] && \
   [ -x "${BIN_DIR}/livekit-server" ] && \
   [ -x "${BIN_DIR}/lk-jwt-service" ]; then
    bashio::log.info "✅ Binaries bereits vorhanden"
    ln -sf "${BIN_DIR}/livekit-server" /usr/local/bin/livekit-server
    ln -sf "${BIN_DIR}/lk-jwt-service" /usr/local/bin/lk-jwt-service
    exit 0
fi

# ── LiveKit Server ───────────────────────────────────────────────────────────
bashio::log.info "📥 Lade LiveKit Server..."

# Direkte Download-URL ohne GitHub API (Rate-Limit-sicher)
# Bekannte stabile Version als Fallback
LK_VERSION="v1.8.2"

# Versuche aktuelle Version via API (mit Timeout)
LK_API_RESP=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/livekit/livekit/releases/latest" 2>/dev/null)
LK_API_VERSION=$(echo "${LK_API_RESP}" | jq -r '.tag_name // empty' 2>/dev/null)
if [ -n "${LK_API_VERSION}" ]; then
    LK_VERSION="${LK_API_VERSION}"
    bashio::log.info "   GitHub API: ${LK_VERSION}"
else
    bashio::log.info "   GitHub API nicht erreichbar — nutze Fallback ${LK_VERSION}"
fi

# Repo: livekit/livekit (nicht livekit/livekit-server — das war der Bug!)
LK_VER_CLEAN=$(echo "${LK_VERSION}" | tr -d 'v')
LK_URL="https://github.com/livekit/livekit/releases/download/${LK_VERSION}/livekit_${LK_VER_CLEAN}_linux_${LK_ARCH}.tar.gz"
bashio::log.info "   URL: ${LK_URL}"

if wget -q --timeout=60 "${LK_URL}" -O /tmp/livekit.tar.gz 2>/dev/null; then
    if tar -xzf /tmp/livekit.tar.gz -C "${BIN_DIR}/" livekit-server 2>/dev/null; then
        chmod +x "${BIN_DIR}/livekit-server"
        ln -sf "${BIN_DIR}/livekit-server" /usr/local/bin/livekit-server
        bashio::log.info "✅ LiveKit Server ${LK_VERSION} installiert"
    else
        bashio::log.error "❌ LiveKit: tar Extraktion fehlgeschlagen"
    fi
    rm -f /tmp/livekit.tar.gz
else
    bashio::log.error "❌ LiveKit Download fehlgeschlagen (${LK_URL})"
    bashio::log.warning "   Voice Calls funktionieren erst nach erneutem Neustart"
    exit 0
fi

# ── lk-jwt-service ───────────────────────────────────────────────────────────
bashio::log.info "📥 Lade lk-jwt-service..."

LKJWT_VERSION="v0.1.0"
LKJWT_API_RESP=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/element-hq/lk-jwt-service/releases/latest" 2>/dev/null)
LKJWT_API_VERSION=$(echo "${LKJWT_API_RESP}" | jq -r '.tag_name // empty' 2>/dev/null)
if [ -n "${LKJWT_API_VERSION}" ]; then
    LKJWT_VERSION="${LKJWT_API_VERSION}"
fi

# Asset-URL aus API holen, aber sicher
LKJWT_URL=$(echo "${LKJWT_API_RESP}" \
    | jq -r ".assets[]? | select(.name | test(\"linux.*${LK_ARCH}\")) | .browser_download_url" \
    2>/dev/null | head -1)

# Fallback: direkter Binary-Name
if [ -z "${LKJWT_URL}" ]; then
    LKJWT_URL="https://github.com/element-hq/lk-jwt-service/releases/download/${LKJWT_VERSION}/lk-jwt-service-linux-${LK_ARCH}"
fi
bashio::log.info "   URL: ${LKJWT_URL}"

if wget -q --timeout=60 "${LKJWT_URL}" -O /tmp/lkjwt.download 2>/dev/null; then
    if file /tmp/lkjwt.download 2>/dev/null | grep -q "gzip\|tar"; then
        tar -xzf /tmp/lkjwt.download -C "${BIN_DIR}/" 2>/dev/null
    else
        cp /tmp/lkjwt.download "${BIN_DIR}/lk-jwt-service"
    fi
    chmod +x "${BIN_DIR}/lk-jwt-service"
    ln -sf "${BIN_DIR}/lk-jwt-service" /usr/local/bin/lk-jwt-service
    rm -f /tmp/lkjwt.download
    bashio::log.info "✅ lk-jwt-service ${LKJWT_VERSION} installiert"
else
    bashio::log.error "❌ lk-jwt-service Download fehlgeschlagen"
    bashio::log.warning "   Voice Calls funktionieren erst nach erneutem Neustart"
    exit 0
fi

touch "${BIN_MARKER}"
bashio::log.info "✅ Alle Voice-Binaries bereit"
exit 0
