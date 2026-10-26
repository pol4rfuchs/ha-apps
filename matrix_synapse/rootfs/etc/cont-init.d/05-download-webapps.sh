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

# pick_version <api-tag> <installiert> <fallback> <name>
# Gibt die Zielversion aus. Ist die GitHub-API nicht erreichbar (z. B. Rate-Limit
# von 60 Abfragen/Stunde ohne Anmeldung), bleibt die installierte Version stehen.
# Der feste Fallback gilt nur, wenn noch nichts installiert ist: sonst würde ein
# API-Ausfall bei jedem Start auf diese alte Version zurückstufen.
pick_version() {
    local api="$1" installed="$2" fallback="$3" name="$4"
    if [ -n "${api}" ] && [ "${api}" != "null" ]; then
        echo "${api}"
    elif [ -n "${installed}" ]; then
        bashio::log.warning "⚠️  ${name}: GitHub-API nicht erreichbar — installierte Version ${installed} bleibt" >&2
        echo "${installed}"
    else
        bashio::log.warning "⚠️  ${name}: GitHub-API nicht erreichbar — installiere Fallback ${fallback}" >&2
        echo "${fallback}"
    fi
}

# ── Element Web ───────────────────────────────────────────────────────────
bashio::log.info "🔍 Prüfe Element Web Version..."
EW_LATEST=$(curl -sf \
    "https://api.github.com/repos/element-hq/element-web/releases/latest" \
    | jq -r .tag_name 2>/dev/null)
EW_INSTALLED=$(cat "${EW_VERSION_FILE}" 2>/dev/null || echo "")
EW_LATEST=$(pick_version "${EW_LATEST}" "${EW_INSTALLED}" "v1.11.85" "Element Web")

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
ENABLE_ADMIN=$(bashio::config 'enable_synapse_admin')
if [ "${ENABLE_ADMIN}" = "true" ]; then
    bashio::log.info "🔍 Prüfe Ketesa Version..."
    ADMIN_LATEST=$(curl -sf \
        "https://api.github.com/repos/etkecc/ketesa/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    ADMIN_INSTALLED=$(cat "${ADMIN_VERSION_FILE}" 2>/dev/null || echo "")
    ADMIN_LATEST=$(pick_version "${ADMIN_LATEST}" "${ADMIN_INSTALLED}" "v1.5.1" "Ketesa")

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
else
    bashio::log.info "⏭️  Ketesa-Download übersprungen (enable_synapse_admin: false)"
fi

# ── Element Call (nur wenn Voice/Video aktiviert) ────────────────────────
ENABLE_VOICE=$(bashio::config 'enable_voice_calls')
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "🔍 Prüfe Element Call Version..."
    EC_LATEST=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-call/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    EC_INSTALLED=$(cat "${EC_VERSION_FILE}" 2>/dev/null || echo "")
    EC_LATEST=$(pick_version "${EC_LATEST}" "${EC_INSTALLED}" "v0.7.0" "Element Call")

    if [ "${EC_INSTALLED}" != "${EC_LATEST}" ]; then
        bashio::log.info "📥 Lade Element Call ${EC_LATEST} (installiert: ${EC_INSTALLED:-keine})..."

        # Asset URL ermitteln. Upstream veröffentlicht neben element-call-<ver>.tar.gz
        # auch element-call-embedded-<ver>.tar.gz (anderer Build): nur die Version
        # direkt nach "element-call-" zulassen, nicht auf die Reihenfolge der API verlassen.
        EC_ASSET_FILTER='.assets[] | select(.name | test("^element-call-v?[0-9][0-9.]*\\.tar\\.gz$")) | .browser_download_url'
        EC_URL=$(curl -sf \
            "https://api.github.com/repos/element-hq/element-call/releases/latest" \
            | jq -r "${EC_ASSET_FILTER}" \
            | head -1)

        if [ -z "${EC_URL}" ]; then
            # Der Release-Tag hat ein "v" (v0.26.1), der Dateiname nicht (0.26.1)
            EC_URL="https://github.com/element-hq/element-call/releases/download/${EC_LATEST}/element-call-${EC_LATEST#v}.tar.gz"
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

# ── Bento-Theme (zweite Optik neben dem Original) ─────────────────────────
# Die Dateien liegen im Image und werden bei JEDEM Start nach den Downloads eingespielt:
# ein Webapp-Update ersetzt index.html und leert das Verzeichnis, <link> und CSS wären sonst
# weg. Idempotent. Element Web: das CSS ist inaktiv, bis in den Einstellungen "Bento Light"
# oder "Bento Dark" gewählt wird (Themes stehen in der config.json). Element Call hat keine
# Theme-Auswahl, dort entscheidet die Option element_call_theme.
THEMES_DIR="/usr/share/matrix-themes"

# bento_link <webroot> <css-datei> <href> <an|aus>
bento_link() {
    local root="$1" css="$2" href="$3" mode="$4"
    local index="${root}/index.html"
    local tag="<link rel=\"stylesheet\" href=\"${href}\">"
    [ -f "${index}" ] || return 0
    if [ "${mode}" = "an" ] && [ -f "${THEMES_DIR}/${css}" ]; then
        cp -f "${THEMES_DIR}/${css}" "${root}/${css}"
        if ! grep -qF "${tag}" "${index}"; then
            sed -i "s|</head>|${tag}</head>|" "${index}"
        fi
        bashio::log.info "🎨 Bento-Stylesheet aktiv: ${root##*/}/${css}"
    else
        if grep -qF "${tag}" "${index}"; then
            sed -i "s|${tag}||" "${index}"
        fi
        rm -f "${root}/${css}"
    fi
    return 0
}

bento_link /data/matrix/element-web bento.css "bento.css" an

EC_THEME="$(bashio::config 'element_call_theme')"
if [ "${EC_THEME}" = "bento" ]; then
    bento_link /data/matrix/element-call bento-ec.css "/bento-ec.css" an
else
    bento_link /data/matrix/element-call bento-ec.css "/bento-ec.css" aus
fi

exit 0
