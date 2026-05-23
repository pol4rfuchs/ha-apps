#!/usr/bin/with-contenv bashio
# ============================================================================
# 05-download-webapps.sh — Element Web, Synapse Admin, Element Call
# ============================================================================

MARKER="/data/matrix/.webapps_downloaded"
VOICE_MARKER="/data/matrix/.voice_downloaded"
mkdir -p /data/matrix

# ── Element Web + Synapse Admin (einmalig) ───────────────────────────────────
if [ ! -f "${MARKER}" ]; then
    bashio::log.info "Erster Start: Lade Web-Apps herunter..."

    # ── Element Web ──────────────────────────────────────────────────────────
    bashio::log.info "📥 Lade Element Web..."
    EW_VERSION=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-web/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    [ -z "${EW_VERSION}" ] || [ "${EW_VERSION}" = "null" ] && EW_VERSION="v1.11.85"
    bashio::log.info "   Version: ${EW_VERSION}"

    if wget -q "https://github.com/element-hq/element-web/releases/download/${EW_VERSION}/element-${EW_VERSION}.tar.gz" \
        -O /tmp/element-web.tar.gz 2>/dev/null; then
        mkdir -p /tmp/ew-extract /data/matrix/element-web
        tar -xzf /tmp/element-web.tar.gz -C /tmp/ew-extract 2>/dev/null
        EXTRACTED=$(find /tmp/ew-extract -maxdepth 1 -mindepth 1 -type d | head -1)
        if [ -n "${EXTRACTED}" ] && [ -f "${EXTRACTED}/index.html" ]; then
            cp -r "${EXTRACTED}/." /data/matrix/element-web/
            COUNT=$(find /data/matrix/element-web -type f | wc -l)
            bashio::log.info "✅ Element Web installiert (${COUNT} Dateien)"
        else
            bashio::log.error "❌ index.html nicht gefunden!"
        fi
        rm -f /tmp/element-web.tar.gz && rm -rf /tmp/ew-extract
    else
        bashio::log.error "❌ Element Web Download fehlgeschlagen!"
    fi

    # ── Synapse Admin UI ─────────────────────────────────────────────────────
    bashio::log.info "📥 Lade Synapse Admin UI..."
    ADMIN_VERSION="v0.10.3-etke32"
    if wget -q "https://github.com/etkecc/synapse-admin/releases/download/${ADMIN_VERSION}/synapse-admin.tar.gz" \
        -O /tmp/synapse-admin.tar.gz 2>/dev/null; then
        mkdir -p /data/matrix/synapse-admin
        tar -xzf /tmp/synapse-admin.tar.gz -C /tmp/ 2>/dev/null
        cp -r /tmp/synapse-admin/. /data/matrix/synapse-admin/
        rm -rf /tmp/synapse-admin /tmp/synapse-admin.tar.gz
        COUNT=$(find /data/matrix/synapse-admin -type f | wc -l)
        bashio::log.info "✅ Synapse Admin installiert (${COUNT} Dateien)"
    else
        bashio::log.error "❌ Synapse Admin Download fehlgeschlagen!"
    fi

    touch "${MARKER}"
    bashio::log.info "✅ Web-Apps Setup abgeschlossen"
else
    bashio::log.info "✅ Web-Apps bereits vorhanden"
fi

# ── Element Call (unabhängig vom Haupt-Marker — Upgrade-sicher) ──────────────
ENABLE_VOICE=$(bashio::config 'enable_voice_calls')
if [ "${ENABLE_VOICE}" = "true" ] && [ ! -f "${VOICE_MARKER}" ]; then
    bashio::log.info "📥 Lade Element Call WebApp..."

    EC_VERSION=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-call/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    [ -z "${EC_VERSION}" ] || [ "${EC_VERSION}" = "null" ] && EC_VERSION="v0.7.0"
    bashio::log.info "   Element Call Version: ${EC_VERSION}"

    # Asset URL ermitteln (tarball oder zip)
    EC_URL=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-call/releases/latest" \
        | jq -r '.assets[] | select(.name | test("element-call.*\\.tar\\.gz")) | .browser_download_url' \
        | head -1)

    if [ -z "${EC_URL}" ]; then
        EC_URL="https://github.com/element-hq/element-call/releases/download/${EC_VERSION}/element-call-${EC_VERSION}.tar.gz"
    fi

    if wget -q "${EC_URL}" -O /tmp/element-call.tar.gz 2>/dev/null; then
        mkdir -p /tmp/ec-extract /data/matrix/element-call
        tar -xzf /tmp/element-call.tar.gz -C /tmp/ec-extract 2>/dev/null

        # Inhalt ermitteln (evtl. in Unterordner)
        if find /tmp/ec-extract -name "index.html" | grep -q .; then
            ECDIR=$(find /tmp/ec-extract -name "index.html" | head -1 | xargs dirname)
            cp -r "${ECDIR}/." /data/matrix/element-call/
            COUNT=$(find /data/matrix/element-call -type f | wc -l)
            bashio::log.info "✅ Element Call installiert (${COUNT} Dateien)"
        else
            bashio::log.error "❌ Element Call: index.html nicht gefunden!"
            ls -la /tmp/ec-extract/ || true
        fi
        rm -f /tmp/element-call.tar.gz && rm -rf /tmp/ec-extract
    else
        bashio::log.error "❌ Element Call Download fehlgeschlagen: ${EC_URL}"
    fi

    touch "${VOICE_MARKER}"
elif [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "✅ Element Call bereits vorhanden"
fi

exit 0
