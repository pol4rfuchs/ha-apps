#!/usr/bin/with-contenv bashio
# ============================================================================
# 05-download-webapps.sh — Element Web, Ketesa (ehem. Synapse Admin), Element Call
#
# Jede Komponente trackt ihre installierte Version in einer eigenen
# .*_version Datei unter /data/matrix/. Bei jedem Start wird die aktuelle
# "latest" Version per GitHub API abgefragt und mit der installierten
# verglichen — nur bei Unterschied (oder fehlender Installation) wird neu
# heruntergeladen. Kein "einmal installiert, für immer eingefroren" mehr.
#
# set +e: bashio-Umgebung läuft mit set -e, d.h. ein einzelner fehlgeschlagener
# Befehl (z.B. cp auf nicht existierenden Pfad) killt sonst sofort das ganze
# Script und damit per s6 den ganzen Container. Alle Fehlerfälle werden
# stattdessen explizit per if/else behandelt und geloggt.
# ============================================================================
set +e

EW_VERSION_FILE="/data/matrix/.element-web_version"
ADMIN_VERSION_FILE="/data/matrix/.ketesa_version"
EC_VERSION_FILE="/data/matrix/.element-call_version"
mkdir -p /data/matrix

# ── Element Web ───────────────────────────────────────────────────────────
bashio::log.info "🔍 Prüfe Element Web Version..."
EW_LATEST=$(curl -sf \
    "https://api.github.com/repos/element-hq/element-web/releases/latest" \
    | jq -r .tag_name 2>/dev/null)
[ -z "${EW_LATEST}" ] || [ "${EW_LATEST}" = "null" ] && EW_LATEST="v1.11.85"
EW_INSTALLED=$(cat "${EW_VERSION_FILE}" 2>/dev/null || echo "")

if [ "${EW_INSTALLED}" != "${EW_LATEST}" ]; then
    bashio::log.info "📥 Lade Element Web ${EW_LATEST} (installiert: ${EW_INSTALLED:-keine})..."
    if wget -q "https://github.com/element-hq/element-web/releases/download/${EW_LATEST}/element-${EW_LATEST}.tar.gz" \
        -O /tmp/element-web.tar.gz 2>/dev/null; then
        mkdir -p /tmp/ew-extract /data/matrix/element-web
        tar -xzf /tmp/element-web.tar.gz -C /tmp/ew-extract 2>/dev/null
        EXTRACTED=$(find /tmp/ew-extract -maxdepth 1 -mindepth 1 -type d | head -1)
        if [ -n "${EXTRACTED}" ] && [ -f "${EXTRACTED}/index.html" ]; then
            rm -rf /data/matrix/element-web/*
            cp -r "${EXTRACTED}/." /data/matrix/element-web/
            echo "${EW_LATEST}" > "${EW_VERSION_FILE}"
            COUNT=$(find /data/matrix/element-web -type f | wc -l)
            bashio::log.info "✅ Element Web ${EW_LATEST} installiert (${COUNT} Dateien)"
        else
            bashio::log.error "❌ Element Web: index.html nicht gefunden!"
        fi
        rm -f /tmp/element-web.tar.gz && rm -rf /tmp/ew-extract
    else
        bashio::log.error "❌ Element Web Download fehlgeschlagen!"
    fi
else
    bashio::log.info "✅ Element Web bereits aktuell (${EW_INSTALLED})"
fi

# ── Ketesa (ehem. Synapse Admin) UI ──────────────────────────────────────
bashio::log.info "🔍 Prüfe Ketesa Version..."
ADMIN_LATEST=$(curl -sf \
    "https://api.github.com/repos/etkecc/ketesa/releases/latest" \
    | jq -r .tag_name 2>/dev/null)
[ -z "${ADMIN_LATEST}" ] || [ "${ADMIN_LATEST}" = "null" ] && ADMIN_LATEST="v1.4.0"
ADMIN_INSTALLED=$(cat "${ADMIN_VERSION_FILE}" 2>/dev/null || echo "")

if [ "${ADMIN_INSTALLED}" != "${ADMIN_LATEST}" ]; then
    bashio::log.info "📥 Lade Ketesa ${ADMIN_LATEST} (installiert: ${ADMIN_INSTALLED:-keine})..."
    if wget -q "https://github.com/etkecc/ketesa/releases/download/${ADMIN_LATEST}/ketesa.tar.gz" \
        -O /tmp/synapse-admin.tar.gz 2>/dev/null; then
        mkdir -p /tmp/admin-extract /data/matrix/synapse-admin
        tar -xzf /tmp/synapse-admin.tar.gz -C /tmp/admin-extract 2>/dev/null

        # Ketesa packt teils flach, teils in einem Unterordner — robust suchen
        if [ -f /tmp/admin-extract/index.html ]; then
            ADMINDIR="/tmp/admin-extract"
        else
            ADMINDIR=$(find /tmp/admin-extract -maxdepth 2 -name "index.html" | head -1 | xargs dirname 2>/dev/null)
        fi

        if [ -n "${ADMINDIR}" ] && [ -f "${ADMINDIR}/index.html" ]; then
            rm -rf /data/matrix/synapse-admin/*
            cp -r "${ADMINDIR}/." /data/matrix/synapse-admin/
            echo "${ADMIN_LATEST}" > "${ADMIN_VERSION_FILE}"
            COUNT=$(find /data/matrix/synapse-admin -type f | wc -l)
            bashio::log.info "✅ Ketesa ${ADMIN_LATEST} installiert (${COUNT} Dateien)"
        else
            bashio::log.error "❌ Ketesa: index.html nicht gefunden!"
        fi
        rm -f /tmp/synapse-admin.tar.gz && rm -rf /tmp/admin-extract
    else
        bashio::log.error "❌ Ketesa Download fehlgeschlagen!"
    fi
else
    bashio::log.info "✅ Ketesa bereits aktuell (${ADMIN_INSTALLED})"
fi

# ── Element Call (nur wenn Voice/Video aktiviert) ────────────────────────
ENABLE_VOICE=$(bashio::config 'enable_voice_calls')
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "🔍 Prüfe Element Call Version..."
    EC_LATEST=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-call/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    [ -z "${EC_LATEST}" ] || [ "${EC_LATEST}" = "null" ] && EC_LATEST="v0.7.0"
    EC_INSTALLED=$(cat "${EC_VERSION_FILE}" 2>/dev/null || echo "")

    if [ "${EC_INSTALLED}" != "${EC_LATEST}" ]; then
        bashio::log.info "📥 Lade Element Call ${EC_LATEST} (installiert: ${EC_INSTALLED:-keine})..."

        # Asset URL ermitteln (tarball oder zip)
        EC_URL=$(curl -sf \
            "https://api.github.com/repos/element-hq/element-call/releases/latest" \
            | jq -r '.assets[] | select(.name | test("element-call.*\\.tar\\.gz")) | .browser_download_url' \
            | head -1)

        if [ -z "${EC_URL}" ]; then
            EC_URL="https://github.com/element-hq/element-call/releases/download/${EC_LATEST}/element-call-${EC_LATEST}.tar.gz"
        fi

        if wget -q "${EC_URL}" -O /tmp/element-call.tar.gz 2>/dev/null; then
            mkdir -p /tmp/ec-extract /data/matrix/element-call
            tar -xzf /tmp/element-call.tar.gz -C /tmp/ec-extract 2>/dev/null

            # Inhalt ermitteln (evtl. in Unterordner)
            if find /tmp/ec-extract -name "index.html" | grep -q .; then
                ECDIR=$(find /tmp/ec-extract -name "index.html" | head -1 | xargs dirname)
                rm -rf /data/matrix/element-call/*
                cp -r "${ECDIR}/." /data/matrix/element-call/
                echo "${EC_LATEST}" > "${EC_VERSION_FILE}"
                COUNT=$(find /data/matrix/element-call -type f | wc -l)
                bashio::log.info "✅ Element Call ${EC_LATEST} installiert (${COUNT} Dateien)"
            else
                bashio::log.error "❌ Element Call: index.html nicht gefunden!"
                ls -la /tmp/ec-extract/ || true
            fi
            rm -f /tmp/element-call.tar.gz && rm -rf /tmp/ec-extract
        else
            bashio::log.error "❌ Element Call Download fehlgeschlagen: ${EC_URL}"
        fi
    else
        bashio::log.info "✅ Element Call bereits aktuell (${EC_INSTALLED})"
    fi
fi

exit 0
