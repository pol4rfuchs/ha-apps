#!/usr/bin/with-contenv bashio
# ============================================================================
# 05-download-webapps.sh — Element Web, Ketesa (ehem. Synapse Admin), Element Call
#
# Each component tracks its installed version in its own .*_version file
# under /data/matrix/. On every start, the current "latest" version is
# queried via the GitHub API and compared with the installed one — it is
# only downloaded again if they differ (or nothing is installed). No more
# "installed once, frozen forever".
#
# set +e: the bashio environment runs with set -e, i.e. a single failed
# command (e.g. cp on a non-existent path) would otherwise kill the whole
# script and, via s6, the whole container. All error cases are handled
# explicitly with if/else and logged instead.
# ============================================================================
set +e

EW_VERSION_FILE="/data/matrix/.element-web_version"
ADMIN_VERSION_FILE="/data/matrix/.ketesa_version"
EC_VERSION_FILE="/data/matrix/.element-call_version"
mkdir -p /data/matrix

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

# ── Element Web ───────────────────────────────────────────────────────────
bashio::log.info "🔍 Checking Element Web version..."
EW_LATEST=$(curl -sf \
    "https://api.github.com/repos/element-hq/element-web/releases/latest" \
    | jq -r .tag_name 2>/dev/null)
EW_INSTALLED=$(cat "${EW_VERSION_FILE}" 2>/dev/null || echo "")
EW_LATEST=$(pick_version "${EW_LATEST}" "${EW_INSTALLED}" "v1.11.85" "Element Web")

if [ "${EW_INSTALLED}" != "${EW_LATEST}" ]; then
    bashio::log.info "📥 Downloading Element Web ${EW_LATEST} (installed: ${EW_INSTALLED:-none})..."
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
            bashio::log.info "✅ Element Web ${EW_LATEST} installed (${COUNT} files)"
        else
            bashio::log.error "❌ Element Web: index.html not found!"
        fi
        rm -f /tmp/element-web.tar.gz && rm -rf /tmp/ew-extract
    else
        bashio::log.error "❌ Element Web download failed!"
    fi
else
    bashio::log.info "✅ Element Web already up to date (${EW_INSTALLED})"
fi

# ── Ketesa (ehem. Synapse Admin) UI ──────────────────────────────────────
ENABLE_ADMIN=$(bashio::config 'enable_synapse_admin')
if [ "${ENABLE_ADMIN}" = "true" ]; then
    bashio::log.info "🔍 Checking Ketesa version..."
    ADMIN_LATEST=$(curl -sf \
        "https://api.github.com/repos/etkecc/ketesa/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    ADMIN_INSTALLED=$(cat "${ADMIN_VERSION_FILE}" 2>/dev/null || echo "")
    ADMIN_LATEST=$(pick_version "${ADMIN_LATEST}" "${ADMIN_INSTALLED}" "v1.5.1" "Ketesa")

    if [ "${ADMIN_INSTALLED}" != "${ADMIN_LATEST}" ]; then
        bashio::log.info "📥 Downloading Ketesa ${ADMIN_LATEST} (installed: ${ADMIN_INSTALLED:-none})..."
        if wget -q "https://github.com/etkecc/ketesa/releases/download/${ADMIN_LATEST}/ketesa.tar.gz" \
            -O /tmp/synapse-admin.tar.gz 2>/dev/null; then
            mkdir -p /tmp/admin-extract /data/matrix/synapse-admin
            tar -xzf /tmp/synapse-admin.tar.gz -C /tmp/admin-extract 2>/dev/null

            # Ketesa is packaged sometimes flat, sometimes in a subfolder — search robustly
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
                bashio::log.info "✅ Ketesa ${ADMIN_LATEST} installed (${COUNT} files)"
            else
                bashio::log.error "❌ Ketesa: index.html not found!"
            fi
            rm -f /tmp/synapse-admin.tar.gz && rm -rf /tmp/admin-extract
        else
            bashio::log.error "❌ Ketesa download failed!"
        fi
    else
        bashio::log.info "✅ Ketesa already up to date (${ADMIN_INSTALLED})"
    fi
else
    bashio::log.info "⏭️  Ketesa download skipped (enable_synapse_admin: false)"
fi

# ── Element Call (only if voice/video is enabled) ────────────────────────
ENABLE_VOICE=$(bashio::config 'enable_voice_calls')
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "🔍 Checking Element Call version..."
    EC_LATEST=$(curl -sf \
        "https://api.github.com/repos/element-hq/element-call/releases/latest" \
        | jq -r .tag_name 2>/dev/null)
    EC_INSTALLED=$(cat "${EC_VERSION_FILE}" 2>/dev/null || echo "")
    EC_LATEST=$(pick_version "${EC_LATEST}" "${EC_INSTALLED}" "v0.7.0" "Element Call")

    if [ "${EC_INSTALLED}" != "${EC_LATEST}" ]; then
        bashio::log.info "📥 Downloading Element Call ${EC_LATEST} (installed: ${EC_INSTALLED:-none})..."

        # Determine the asset URL. Besides element-call-<ver>.tar.gz, upstream also
        # publishes element-call-embedded-<ver>.tar.gz (a different build): allow only
        # the version directly after "element-call-", do not rely on the API order.
        EC_ASSET_FILTER='.assets[] | select(.name | test("^element-call-v?[0-9][0-9.]*\\.tar\\.gz$")) | .browser_download_url'
        EC_URL=$(curl -sf \
            "https://api.github.com/repos/element-hq/element-call/releases/latest" \
            | jq -r "${EC_ASSET_FILTER}" \
            | head -1)

        if [ -z "${EC_URL}" ]; then
            # The release tag has a "v" (v0.26.1), the file name does not (0.26.1)
            EC_URL="https://github.com/element-hq/element-call/releases/download/${EC_LATEST}/element-call-${EC_LATEST#v}.tar.gz"
        fi

        if wget -q "${EC_URL}" -O /tmp/element-call.tar.gz 2>/dev/null; then
            mkdir -p /tmp/ec-extract /data/matrix/element-call
            tar -xzf /tmp/element-call.tar.gz -C /tmp/ec-extract 2>/dev/null

            # Locate the content (possibly in a subfolder)
            if find /tmp/ec-extract -name "index.html" | grep -q .; then
                ECDIR=$(find /tmp/ec-extract -name "index.html" | head -1 | xargs dirname)
                rm -rf /data/matrix/element-call/*
                cp -r "${ECDIR}/." /data/matrix/element-call/
                echo "${EC_LATEST}" > "${EC_VERSION_FILE}"
                COUNT=$(find /data/matrix/element-call -type f | wc -l)
                bashio::log.info "✅ Element Call ${EC_LATEST} installed (${COUNT} files)"
            else
                bashio::log.error "❌ Element Call: index.html not found!"
                ls -la /tmp/ec-extract/ || true
            fi
            rm -f /tmp/element-call.tar.gz && rm -rf /tmp/ec-extract
        else
            bashio::log.error "❌ Element Call download failed: ${EC_URL}"
        fi
    else
        bashio::log.info "✅ Element Call already up to date (${EC_INSTALLED})"
    fi
fi

# ── Bento theme (a second look next to the original) ──────────────────────
# The files are part of the image and are installed on EVERY start after the downloads:
# a web app update replaces index.html and empties the directory, so <link> and CSS would
# otherwise be gone. Idempotent. Element Web: the CSS is inactive until "Bento Light"
# or "Bento Dark" is selected in the settings (themes are listed in config.json). Element
# Call has no theme picker; the element_call_theme option decides there.
THEMES_DIR="/usr/share/matrix-themes"

# bento_link <webroot> <css-file> <href> <on|off>
bento_link() {
    local root="$1" css="$2" href="$3" mode="$4"
    local index="${root}/index.html"
    local tag="<link rel=\"stylesheet\" href=\"${href}\">"
    [ -f "${index}" ] || return 0
    if [ "${mode}" = "on" ] && [ -f "${THEMES_DIR}/${css}" ]; then
        cp -f "${THEMES_DIR}/${css}" "${root}/${css}"
        if ! grep -qF "${tag}" "${index}"; then
            sed -i "s|</head>|${tag}</head>|" "${index}"
        fi
        bashio::log.info "🎨 Bento stylesheet active: ${root##*/}/${css}"
    else
        if grep -qF "${tag}" "${index}"; then
            sed -i "s|${tag}||" "${index}"
        fi
        rm -f "${root}/${css}"
    fi
    return 0
}

bento_link /data/matrix/element-web bento.css "bento.css" on

EC_THEME="$(bashio::config 'element_call_theme')"
if [ "${EC_THEME}" = "bento" ]; then
    bento_link /data/matrix/element-call bento-ec.css "/bento-ec.css" on
else
    bento_link /data/matrix/element-call bento-ec.css "/bento-ec.css" off
fi

exit 0
