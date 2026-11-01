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

# ── Tor (optional) ────────────────────────────────────────────────────────────
# The onion engines (ahmia, torch) stay inactive in SearXNG unless they use a
# Tor proxy. With `enable_tor` we start a local Tor client and write a runtime
# copy of settings.yml in which only these two engines use it. The user's own
# settings.yml is never modified.
TOR_BOOTSTRAP_TIMEOUT=120
RUNTIME_SETTINGS="/etc/searxng/.settings.runtime.yml"
rm -f "${RUNTIME_SETTINGS}"

start_tor() {
    if ! command -v tor >/dev/null 2>&1; then
        warn "Tor is not installed in this image — starting without Tor."
        return 1
    fi
    mkdir -p /tmp/tor
    chmod 700 /tmp/tor
    chown tor:tor /tmp/tor 2>/dev/null || true
    rm -f /tmp/tor/notice.log
    cat > /tmp/torrc << 'ENDOFTORRC'
User tor
DataDirectory /tmp/tor
ClientOnly 1
SocksPort 127.0.0.1:9050
Log notice file /tmp/tor/notice.log
ENDOFTORRC
    log "Starting Tor (waiting up to ${TOR_BOOTSTRAP_TIMEOUT}s for the connection)..."
    tor -f /tmp/torrc > /dev/null 2>&1 &
    TOR_PID=$!
    waited=0
    while [ "${waited}" -lt "${TOR_BOOTSTRAP_TIMEOUT}" ]; do
        if grep -q "Bootstrapped 100%" /tmp/tor/notice.log 2>/dev/null; then
            log "Tor is connected."
            return 0
        fi
        if ! kill -0 "${TOR_PID}" 2>/dev/null; then
            warn "Tor exited early — starting without Tor."
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    warn "Tor did not connect within ${TOR_BOOTSTRAP_TIMEOUT}s — starting without Tor."
    kill "${TOR_PID}" 2>/dev/null || true
    return 1
}

write_tor_settings() {
    /usr/local/searxng/.venv/bin/python3 - "${SETTINGS_FILE}" "${RUNTIME_SETTINGS}" << 'ENDOFPY'
import os
import sys

import yaml

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    cfg = yaml.safe_load(fh) or {}

defaults = cfg.get("use_default_settings")
if not defaults:
    print("settings.yml does not set use_default_settings: the onion engines cannot be added", file=sys.stderr)
    sys.exit(2)

remove, keep_only = [], None
if isinstance(defaults, dict):
    eng = defaults.get("engines") or {}
    if isinstance(eng, dict):
        remove = eng.get("remove") or []
        keep_only = eng.get("keep_only")

engines = cfg.get("engines") or []
for name in ("ahmia", "torch"):
    if name in remove or (keep_only is not None and name not in keep_only):
        continue
    entry = next((e for e in engines if e.get("name") == name), None)
    if entry is None:
        entry = {"name": name}
        engines.append(entry)
    entry["using_tor_proxy"] = True
    entry["proxies"] = {"all://": ["socks5h://127.0.0.1:9050"]}
cfg["engines"] = engines

fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    yaml.safe_dump(cfg, fh, default_flow_style=False, sort_keys=False, allow_unicode=True)
ENDOFPY
}

ENABLE_TOR=$(python3 -c "import json; print(str(json.load(open('/data/options.json')).get('enable_tor', False)).lower())" 2>/dev/null) || ENABLE_TOR="false"
if [ "${ENABLE_TOR}" = "true" ]; then
    if start_tor; then
        if write_tor_settings; then
            export SEARXNG_SETTINGS_PATH="${RUNTIME_SETTINGS}"
            log "Onion engines enabled (SEARXNG_SETTINGS_PATH=${RUNTIME_SETTINGS})."
        else
            warn "Could not add the onion engines to the settings — starting without them."
            kill "${TOR_PID}" 2>/dev/null || true
        fi
    fi
fi

# ── Start ─────────────────────────────────────────────────────────────────────
log "Starting SearXNG via custom.sh..."
exec "${CUSTOM_SH}"
