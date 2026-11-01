#!/bin/sh
set -e

log()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
warn() { echo "[WARN]  $(date '+%H:%M:%S') $*"; }

# ── Secret key ────────────────────────────────────────────────────────────────
SECRET_FILE="/etc/searxng/.secret_key"
if [ ! -f "${SECRET_FILE}" ]; then
    log "Generating new SearXNG secret key..."
    openssl rand -hex 32 > "${SECRET_FILE}"
fi
SECRET_KEY=$(cat "${SECRET_FILE}")

# ── Default settings.yml (first start only) ─────────────────────────────────
SETTINGS_FILE="/etc/searxng/settings.yml"
if [ ! -f "${SETTINGS_FILE}" ]; then
    log "No settings.yml found — creating default configuration..."
    cat > "${SETTINGS_FILE}" << EOF
# SearXNG settings.yml
# Docs: https://docs.searxng.org/admin/settings/index.html

use_default_settings: true

general:
  debug: false
  instance_name: "SearXNG"
  privacypolicy_url: false
  donation_url: false
  contact_url: false
  enable_metrics: false

search:
  safe_search: 0
  autocomplete: ""
  default_lang: "auto"
  formats:
    - html
    - json

server:
  secret_key: "${SECRET_KEY}"
  base_url: false
  port: 8080
  bind_address: "0.0.0.0"
  image_proxy: false
  http_protocol_version: "1.0"

ui:
  static_use_hash: true
  default_locale: ""
  query_in_title: false
  infinite_scroll: false
  default_theme: simple
  center_alignment: false
  results_on_new_tab: false

outgoing:
  request_timeout: 3.0
  max_request_timeout: 6.0
  useragent_suffix: ""
  pool_connections: 100
  pool_maxsize: 20
EOF
    log "settings.yml created: ${SETTINGS_FILE}"
fi

# ── Log level ─────────────────────────────────────────────────────────────────
# SearXNG itself only exposes an on/off debug switch (general.debug in
# settings.yml), not a graded level. "debug" maps to true; info/warning/error
# all map to false, since there's nothing finer-grained below debug to map
# them to. Patched on EVERY start (not just first boot), so changing the
# option later actually takes effect on the next restart.
LOG_LEVEL=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('log_level','info'))" 2>/dev/null)
if [ "${LOG_LEVEL}" = "debug" ]; then
    DEBUG_BOOL="true"
else
    DEBUG_BOOL="false"
fi
if [ -f "${SETTINGS_FILE}" ]; then
    sed -i "s/^  debug: .*/  debug: ${DEBUG_BOOL}/" "${SETTINGS_FILE}"
    log "Log level: ${LOG_LEVEL} (general.debug=${DEBUG_BOOL})"
fi

# ── custom.sh hook (first start only) ───────────────────────────────────────
CUSTOM_SH="/etc/searxng/custom.sh"
if [ ! -f "${CUSTOM_SH}" ]; then
    log "Creating custom.sh hook..."
    cat > "${CUSTOM_SH}" << 'ENDOFCUSTOM'
#!/bin/sh
# custom.sh — add your own commands to run before SearXNG starts here.
# Created only once and never overwritten afterwards.

exec /usr/local/searxng/entrypoint.sh
ENDOFCUSTOM
fi
chmod +x "${CUSTOM_SH}"

# ── Ingress base URL ──────────────────────────────────────────────────────────
SET_URL=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(str(d.get('set_base_url_for_ingress', False)).lower())" 2>/dev/null)
if [ "${SET_URL}" = "true" ]; then
    log "Fetching ingress URL from the Supervisor..."
    INGRESS_RESP=$(wget -qO- \
        --header="Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/addons/self/info" 2>/dev/null) || true
    INGRESS_URL=$(echo "${INGRESS_RESP}" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('data',{}).get('ingress_url',''))" 2>/dev/null) || true
    if [ -n "${INGRESS_URL}" ]; then
        export SEARXNG_BASE_URL="${INGRESS_URL}"
        log "SEARXNG_BASE_URL=${INGRESS_URL}"
    else
        warn "Could not determine the ingress URL — base_url stays unset."
    fi
fi

# ── Start ─────────────────────────────────────────────────────────────────────
log "Starting SearXNG via custom.sh..."
exec "${CUSTOM_SH}"
