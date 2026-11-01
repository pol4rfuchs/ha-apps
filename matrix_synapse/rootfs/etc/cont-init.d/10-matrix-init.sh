#!/usr/bin/with-contenv bashio
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Matrix Server ESS CE — Initialization"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVER_NAME=$(bashio::config 'server_name' | sed 's|/$||')
ELEMENT_WEB_URL=$(bashio::config 'element_web_url' | sed 's|/$||')
ENABLE_REGISTRATION=$(bashio::config 'enable_registration')
REG_SECRET=$(bashio::config 'registration_shared_secret')
ENABLE_FEDERATION=$(bashio::config 'enable_federation')
MAX_UPLOAD=$(bashio::config 'max_upload_size_mb')
PG_PASSWORD=$(bashio::config 'postgres_password')
LOG_LEVEL=$(bashio::config 'log_level')
NTFY_URL=$(bashio::config 'ntfy_url' | sed 's|/$||')
ENABLE_VOICE=$(bashio::config 'enable_voice_calls')
LIVEKIT_TURN_ENABLED=$(bashio::config 'livekit_turn_enabled')
LIVEKIT_SECRET=$(bashio::config 'livekit_secret')
ELEMENT_CALL_URL=$(bashio::config 'element_call_url' | sed 's|/$||')
LIVEKIT_URL=$(bashio::config 'livekit_url' | sed 's|/$||')
LIVEKIT_JWT_URL=$(bashio::config 'livekit_jwt_url' | sed 's|/$||')
MEDIA_RETENTION_LOCAL=$(bashio::config 'media_retention_local_days')
MEDIA_RETENTION_REMOTE=$(bashio::config 'media_retention_remote_days')
CACHE_MAX_MB=$(bashio::config 'cache_max_memory_mb')
LOGIN_RATE_PS=$(bashio::config 'login_rate_limit_per_second')
LOGIN_RATE_BURST=$(bashio::config 'login_rate_limit_burst')
REG_RATE_PS=$(bashio::config 'registration_rate_limit_per_second')
REG_RATE_BURST=$(bashio::config 'registration_rate_limit_burst')
MAS_ENABLED=$(bashio::config 'mas_enabled')
MAS_ENDPOINT=$(bashio::config 'mas_endpoint' | sed 's|/$||')
MAS_SECRET=$(bashio::config 'mas_secret')
WHATSAPP_BRIDGE_ENABLED=$(bashio::config 'whatsapp_bridge_enabled')
SIGNAL_BRIDGE_ENABLED=$(bashio::config 'signal_bridge_enabled')
TELEGRAM_BRIDGE_ENABLED=$(bashio::config 'telegram_bridge_enabled')
# Derive LK_DOMAIN early — needed in the Synapse TURN config and the LiveKit config
LK_DOMAIN=$(echo "${LIVEKIT_URL}" | sed 's|wss://||' | sed 's|ws://||' | cut -d'/' -f1)

DATA_DIR="/data/matrix"
SYNAPSE_DATA="${DATA_DIR}/synapse"
PG_DATA="${DATA_DIR}/postgresql"
SYNAPSE_CONFIG="${SYNAPSE_DATA}/homeserver.yaml"
SIGNING_KEY="${SYNAPSE_DATA}/signing.key"
PG_MARKER="${DATA_DIR}/.pg_initialized"
LK_CONFIG="${DATA_DIR}/livekit.yaml"
LK_SECRET_FILE="${DATA_DIR}/.livekit_secret"
BACKUP_DIR="${DATA_DIR}/backups"

# ── Placeholder guard ─────────────────────────────────────────────────────
# server_name is permanently baked into the database and the signing key and cannot be
# changed after the initial setup. So do not start with a placeholder on first start.
case "${SERVER_NAME}" in
    ""|*example.org|*example.com|*example.net|*deine-domain*|*your-domain*)
        if [ ! -f "${SIGNING_KEY}" ]; then
            bashio::exit.nok "server_name is still a placeholder ('${SERVER_NAME}'). Enter your real server name (e.g. matrix.yourdomain.com) – it cannot be changed after the initial setup."
        else
            bashio::log.warning "server_name is a placeholder ('${SERVER_NAME}') – check the option if that is not intended."
        fi
        ;;
esac

mkdir -p "${SYNAPSE_DATA}" "${PG_DATA}" "/media/matrix" \
         "${DATA_DIR}/logs" "${SYNAPSE_DATA}/media_store" \
         "${DATA_DIR}/element-web" "${DATA_DIR}/element-call" \
         "${BACKUP_DIR}"

# ── DB password ───────────────────────────────────────────────────────────
# Option > stored value > generate. If the option is empty, a random password
# is generated and stored only in /data (not in the log).
PG_PASSWORD_FILE="${DATA_DIR}/.pg_password"
if [ -z "${PG_PASSWORD}" ]; then
    if [ -f "${PG_PASSWORD_FILE}" ]; then
        PG_PASSWORD=$(cat "${PG_PASSWORD_FILE}")
        bashio::log.info "✅ postgres_password loaded from storage"
    else
        PG_PASSWORD=$(tr -d '-' < /proc/sys/kernel/random/uuid)$(tr -d '-' < /proc/sys/kernel/random/uuid)
        (umask 077; printf '%s\n' "${PG_PASSWORD}" > "${PG_PASSWORD_FILE}")
        bashio::log.info "✅ postgres_password generated and stored (only in ${PG_PASSWORD_FILE})"
    fi
fi

# Sets the password of the DB role. The password is passed as a psql variable and
# quoted by psql itself as an SQL literal (:'pw') — special characters like '
# or " break neither the SQL nor the shell.
pg_set_password() {
    printf '%s\n' "$1 synapse WITH PASSWORD :'pw';" \
        | gosu postgres psql -v ON_ERROR_STOP=1 -v pw="${PG_PASSWORD}" >/dev/null
}

# ── PostgreSQL init (once) ────────────────────────────────────────────────
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    bashio::log.info "Initializing PostgreSQL database..."
    chown postgres:postgres "${PG_DATA}"
    gosu postgres /usr/lib/postgresql/15/bin/initdb \
        --pgdata="${PG_DATA}" \
        --auth-local=trust \
        --auth-host=md5 \
        --encoding=UTF8 \
        --locale=C

    cat > "${PG_DATA}/pg_hba.conf" << EOF
local   all             postgres                                trust
local   synapse         synapse                                 md5
host    synapse         synapse         127.0.0.1/32            md5
EOF
    cat > "${PG_DATA}/postgresql.conf" << EOF
listen_addresses = '127.0.0.1'
port = 5432
max_connections = 100
shared_buffers = 128MB
effective_cache_size = 256MB
logging_collector = off
log_min_messages = warning
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
EOF

    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "${PG_DATA}" -l /tmp/pg_init.log start -w -t 30
    pg_set_password "CREATE USER" || { bashio::log.error "Could not create the DB role 'synapse'."; exit 1; }
    gosu postgres psql -c "CREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0 OWNER synapse;"
    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl -D "${PG_DATA}" stop -w

    touch "${PG_MARKER}"
    bashio::log.info "✅ PostgreSQL initialized"
else
    bashio::log.info "✅ PostgreSQL already initialized"
    touch "${PG_MARKER}"
    # The role was created on first start with the password of that time.
    # If the option has changed since, the DB no longer matches the config
    # (login fails) — sync it on every start.
    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "${PG_DATA}" -l /tmp/pg_sync.log start -w -t 30 \
        || { bashio::log.error "PostgreSQL does not start — see /tmp/pg_sync.log"; cat /tmp/pg_sync.log; exit 1; }
    pg_set_password "ALTER USER" || { bashio::log.error "Could not sync the DB password."; exit 1; }
    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl -D "${PG_DATA}" stop -w
fi

# ── Synapse Signing Key ───────────────────────────────────────────────────
if [ ! -f "${SIGNING_KEY}" ]; then
    bashio::log.info "Generating Synapse signing key..."
    /opt/synapse/bin/python -m synapse.app.homeserver \
        --server-name "${SERVER_NAME}" \
        --config-path "${SYNAPSE_CONFIG}" \
        --generate-keys 2>/dev/null || true
fi

# ── Registration Secret ───────────────────────────────────────────────────
SECRET_FILE="/data/matrix/.registration_secret"
if [ -z "${REG_SECRET}" ]; then
    if [ -f "${SECRET_FILE}" ]; then
        REG_SECRET=$(cat "${SECRET_FILE}")
        bashio::log.info "✅ registration_shared_secret loaded from storage"
    else
        REG_SECRET=$(cat /proc/sys/kernel/random/uuid | tr -d '-')
        echo "${REG_SECRET}" > "${SECRET_FILE}"
        bashio::log.info "✅ registration_shared_secret generated and stored"
        bashio::log.info "   → Value: ${SECRET_FILE} (not in the log, see the security note)"
    fi
fi

# ── LiveKit Secret ────────────────────────────────────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    if [ -z "${LIVEKIT_SECRET}" ]; then
        if [ -f "${LK_SECRET_FILE}" ]; then
            LIVEKIT_SECRET=$(cat "${LK_SECRET_FILE}")
            bashio::log.info "✅ LiveKit secret loaded from storage"
        else
            LIVEKIT_SECRET=$(cat /proc/sys/kernel/random/uuid | tr -d '-')$(cat /proc/sys/kernel/random/uuid | tr -d '-')
            echo "${LIVEKIT_SECRET}" > "${LK_SECRET_FILE}"
            bashio::log.info "✅ LiveKit secret generated and stored"
            bashio::log.info "   → Optionally enter it in the add-on config (livekit_secret)"
        fi
    fi
fi

# ── Leftovers of the removed bundled Ketesa (now the matrix_ketesa app) ───
# The old copy of the UI, its version marker and the basic-auth credentials file are
# not used any more; remove them so no unused credentials stay in /data.
for LEFTOVER in "${DATA_DIR}/synapse-admin" "${DATA_DIR}/.ketesa_version" "${DATA_DIR}/.admin_ui_auth"; do
    if [ -e "${LEFTOVER}" ]; then
        rm -rf "${LEFTOVER}"
        bashio::log.info "🧹 Removed leftover of the bundled Ketesa: ${LEFTOVER} (use the matrix_ketesa app instead)"
    fi
done

# ── Synapse homeserver.yaml ───────────────────────────────────────────────
bashio::log.info "Writing Synapse homeserver.yaml..."

if [ "${ENABLE_FEDERATION}" = "true" ]; then
    FEDERATE_FLAG="true"
else
    FEDERATE_FLAG="false"
fi

# enable_federation=false must also take effect in Synapse itself, not only in the
# Element Web default (default_federate). An empty federation_domain_whitelist
# blocks all incoming and outgoing federation.
if [ "${ENABLE_FEDERATION}" = "true" ]; then
    FEDERATION_BLOCK=""
else
    FEDERATION_BLOCK="
# Federation disabled (enable_federation: false)
federation_domain_whitelist: []
"
    bashio::log.info "🔒 Federation disabled — federation_domain_whitelist is empty"
fi

# ── Derive ip_range_whitelist from ntfy_url ───────────────────────────────
# Synapse's default blacklist also applies to HTTP pushers. If the ntfy server
# is on the private network, only its (resolved) IPv4 is allowed. Without
# ntfy_url, or with a public address, no exception is created.
IP_WHITELIST_BLOCK=""
if [ -n "${NTFY_URL}" ]; then
    NTFY_HOST=$(echo "${NTFY_URL}" | sed -e 's|^[a-zA-Z]*://||' -e 's|[/?#].*$||' -e 's|^.*@||' -e 's|:[0-9]*$||')
    if echo "${NTFY_HOST}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        NTFY_IP="${NTFY_HOST}"
    else
        NTFY_IP=$(getent ahostsv4 "${NTFY_HOST}" 2>/dev/null | awk 'NR==1{print $1}')
    fi
    if echo "${NTFY_IP}" | grep -Eq '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'; then
        IP_WHITELIST_BLOCK="
# The ntfy push server is on the private network (derived from ntfy_url)
ip_range_whitelist:
  - '${NTFY_IP}'
"
        bashio::log.info "ntfy is on the private network — ip_range_whitelist: ${NTFY_IP}"
    fi
fi

# ── MAS delegation (variant B: explicit toggle) ───────────────────────────
# With MAS enabled, MAS takes over login/registration completely — Synapse's
# own password_config and enable_registration must be off for that,
# otherwise two competing auth paths work against each other.
# MSC4108_FLAG is NOT written in a separate experimental_features: block
# but merged further below into the ONE block that is also responsible for
# voice calls (msc3266/msc3401/msc2285) — two separate top-level
# experimental_features: keys in the same YAML would otherwise overwrite
# each other (the second one silently wins).
if [ "${MAS_ENABLED}" = "true" ]; then
    if [ -z "${MAS_SECRET}" ]; then
        bashio::log.warning "⚠️  mas_enabled=true, but mas_secret is empty — the MAS link will fail!"
        bashio::log.warning "   → Copy the secret from the matrix-auth-service add-on (generated automatically there if left empty)."
    fi
    MAS_AUTH_BLOCK="
# ── Matrix Authentication Service (MAS) — variant B: active ──────────────
matrix_authentication_service:
  enabled: true
  endpoint: \"${MAS_ENDPOINT}\"
  secret: \"${MAS_SECRET}\"

password_config:
  enabled: false
"
    NATIVE_REGISTRATION_BLOCK=""
    MSC4108_FLAG="  msc4108_enabled: true"
    bashio::log.info "🔐 MAS delegation active — native Synapse auth disabled (endpoint: ${MAS_ENDPOINT})"
else
    MAS_AUTH_BLOCK=""
    NATIVE_REGISTRATION_BLOCK="
enable_registration: $([ \"${ENABLE_REGISTRATION}\" = \"true\" ] && echo \"true\" || echo \"false\")
enable_registration_without_verification: true
registration_shared_secret: \"${REG_SECRET}\"
"
    MSC4108_FLAG=""
fi

# Write the password as a JSON string (including quotes): that is a
# valid YAML double-quoted value, even with " and \ in the password.
PG_PASSWORD_YAML=$(jq -rn --arg p "${PG_PASSWORD}" '$p|@json')

cat > "${SYNAPSE_CONFIG}" << EOF
server_name: "${SERVER_NAME}"
# public_baseurl is required for Synapse to mix extra_well_known_client_content
# (see rtc_foci further below) into the /.well-known/matrix/client
# response at all — without this line Synapse simply ignores the extra content,
# even if it is syntactically correct in the config.
# Ref: https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html#extra_well_known_client_content
public_baseurl: "https://${SERVER_NAME}/"
pid_file: /tmp/synapse.pid

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

enable_admin_api: true

database:
  name: psycopg2
  args:
    user: synapse
    password: ${PG_PASSWORD_YAML}
    database: synapse
    host: 127.0.0.1
    port: 5432
    cp_min: 5
    cp_max: 10

media_store_path: "${SYNAPSE_DATA}/media_store"
max_upload_size: "${MAX_UPLOAD}M"

# Cache upper limit: without it the caches keep growing over time.
# cache_autotuning needs jemalloc (loaded via LD_PRELOAD in synapse/run).
caches:
  cache_autotuning:
    max_cache_memory_usage: ${CACHE_MAX_MB}M
    target_cache_memory_usage: $((CACHE_MAX_MB * 3 / 4))M
    min_cache_ttl: 5m
no_tls: true

${NATIVE_REGISTRATION_BLOCK}
${MAS_AUTH_BLOCK}

signing_key_path: "${SIGNING_KEY}"
suppress_key_server_warning: true
trusted_key_servers:
  - server_name: "matrix.org"

log_config: "${SYNAPSE_DATA}/log.yaml"

rc_message:
  per_second: 0.2
  burst_count: 10

rc_login:
  address:
    per_second: ${LOGIN_RATE_PS}
    burst_count: ${LOGIN_RATE_BURST}
  account:
    per_second: ${LOGIN_RATE_PS}
    burst_count: ${LOGIN_RATE_BURST}

rc_registration:
  per_second: ${REG_RATE_PS}
  burst_count: ${REG_RATE_BURST}

report_stats: false

url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
${IP_WHITELIST_BLOCK}${FEDERATION_BLOCK}
EOF

# ── Bridge appservice registration (mautrix-* bridges via /share) ────────
# IMPORTANT: app_service_config_files may appear only ONCE as a top-level key
# (same principle as experimental_features/MSC4108 below — a second block
# would otherwise silently overwrite the first one).
# So collect all active bridges here in ONE list. For future Signal/Telegram
# bridge add-ons, add another if block here each time, do NOT append a second
# "app_service_config_files:" block.
BRIDGE_REG_LIST=""
if [ "${WHATSAPP_BRIDGE_ENABLED}" = "true" ]; then
    BRIDGE_REG_LIST="${BRIDGE_REG_LIST}  - \"/share/whatsapp_bridge_registration.yaml\"
"
fi
if [ "${SIGNAL_BRIDGE_ENABLED}" = "true" ]; then
    BRIDGE_REG_LIST="${BRIDGE_REG_LIST}  - \"/share/signal_bridge_registration.yaml\"
"
fi
if [ "${TELEGRAM_BRIDGE_ENABLED}" = "true" ]; then
    BRIDGE_REG_LIST="${BRIDGE_REG_LIST}  - \"/share/telegram_bridge_registration.yaml\"
"
fi

if [ -n "${BRIDGE_REG_LIST}" ]; then
    bashio::log.info "🌉 Appservice bridge(s) registered — restart Synapse after changes"
    cat >> "${SYNAPSE_CONFIG}" << EOF

app_service_config_files:
${BRIDGE_REG_LIST}EOF
fi

# ── Media retention (optional auto-purge) ─────────────────────────────────
# 0 = disabled (Synapse default behavior: media is never deleted)
if [ "${MEDIA_RETENTION_LOCAL}" != "0" ] || [ "${MEDIA_RETENTION_REMOTE}" != "0" ]; then
    bashio::log.info "🗑️  Media Retention: local=${MEDIA_RETENTION_LOCAL}d remote=${MEDIA_RETENTION_REMOTE}d"
    cat >> "${SYNAPSE_CONFIG}" << EOF

media_retention:
EOF
    if [ "${MEDIA_RETENTION_LOCAL}" != "0" ]; then
        cat >> "${SYNAPSE_CONFIG}" << EOF
  local_media_lifetime: ${MEDIA_RETENTION_LOCAL}d
EOF
    fi
    if [ "${MEDIA_RETENTION_REMOTE}" != "0" ]; then
        cat >> "${SYNAPSE_CONFIG}" << EOF
  remote_media_lifetime: ${MEDIA_RETENTION_REMOTE}d
EOF
    fi
fi

# ── Element Call / MSC3401 Support (Voice/Video) ──────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "🎤 Configuring Element Call support in Synapse..."
    cat >> "${SYNAPSE_CONFIG}" << EOF

# ── Element Call / MSC3401 (Voice/Video) ────────────────────────────────
experimental_features:
  msc3266_enabled: true
  msc3401_enabled: true
  msc2285_enabled: true
${MSC4108_FLAG}

# Higher rate limits for call signaling
rc_message:
  per_second: 1
  burst_count: 50

rc_joins:
  local:
    per_second: 0.5
    burst_count: 10
  remote:
    per_second: 0.1
    burst_count: 10
EOF

    # TURN for legacy 1:1 calls (fixes the "misconfigured server" dialog)
    # Only relevant if the internal LiveKit TURN server is running too — otherwise
    # a dead endpoint (port 3478) would be declared here.
    if [ "${LIVEKIT_TURN_ENABLED}" = "true" ]; then
        cat >> "${SYNAPSE_CONFIG}" << EOF

# TURN for legacy 1:1 calls (fixes the "misconfigured server" dialog)
turn_uris:
  - "turn:${LK_DOMAIN}:3478?transport=udp"
turn_shared_secret: "${LIVEKIT_SECRET}"
turn_user_lifetime: 86400000
turn_allow_guests: true
EOF
    fi

    cat >> "${SYNAPSE_CONFIG}" << EOF

# ── MSC4143 rtc_foci — MatrixRTC discovery for modern clients ────────────
# Without this entry in .well-known/matrix/client, current clients
# (Element X, current Element Web, SchildiChat) do not know which LiveKit
# server to use for calls — they abort the call attempt locally, BEFORE
# any network connection to the outside is made. This only affects the
# native MatrixRTC path; the old widget approach (element_call.url in the
# element-web config.json) keeps working independently of it, which explains
# why older/other clients still partly work.
# Reference: https://github.com/element-hq/synapse/issues/18859
extra_well_known_client_content:
  org.matrix.msc4143.rtc_foci:
    - type: "livekit"
      livekit_service_url: "${LIVEKIT_JWT_URL}"
EOF
elif [ "${MAS_ENABLED}" = "true" ]; then
    # Voice calls off, but MAS on: the block above does not run, so
    # msc4108 (prerequisite for QR login) needs its own, single
    # experimental_features: block here.
    bashio::log.info "🔑 MSC4108 (QR login) enabled, without the voice call block..."
    cat >> "${SYNAPSE_CONFIG}" << EOF

# ── MSC4108 (MAS QR login), without voice call features ──────────────────
experimental_features:
${MSC4108_FLAG}
EOF
fi

# ── Push configuration (always active) ───────────────────────────────────
# include_content: true → Synapse embeds the full message text in push
# notifications. Without this option clients only see "New message".
# Applies to all push methods (UnifiedPush, FCM, APNs) — hence unconditional.
cat >> "${SYNAPSE_CONFIG}" << EOF

push:
  include_content: true
EOF

# ── ntfy UnifiedPush (optional) ───────────────────────────────────────────
# Note: Synapse does NOT need to know ntfy_url — the UnifiedPush client
# (Element Android) registers the gateway URL with Synapse itself.
# ntfy_url is used here only for a reachability check.
if [ -n "${NTFY_URL}" ]; then
    bashio::log.info "🔔 ntfy UnifiedPush Gateway: ${NTFY_URL}/_matrix/push/v1/notify"
    # Reachability check (POST expected — 400 is OK, timeout/000 is an error)
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        --max-time 5 \
        -X POST "${NTFY_URL}/_matrix/push/v1/notify" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null || echo "000")
    if [ "${HTTP_CODE}" = "000" ]; then
        bashio::log.warning "⚠️  ntfy gateway not reachable: ${NTFY_URL}"
        bashio::log.warning "   Check: is base_url set in the ntfy add-on? Is the reverse proxy active?"
    else
        bashio::log.info "✅ ntfy gateway reachable (HTTP ${HTTP_CODE})"
        bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        bashio::log.info " UnifiedPush Setup:"
        bashio::log.info "   1. Install the ntfy app (F-Droid) on Android"
        bashio::log.info "   2. Server in the ntfy app: ${NTFY_URL}"
        bashio::log.info "   3. Element: Settings → Notifications"
        bashio::log.info "      → select ntfy as the UnifiedPush distributor"
        bashio::log.info "   Synapse is configured automatically by the client."
        bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
fi

# ── Synapse log config ────────────────────────────────────────────────────
cat > "${SYNAPSE_DATA}/log.yaml" << EOF
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
loggers:
  synapse.storage.SQL:
    level: WARNING
root:
  level: ${LOG_LEVEL}
  handlers: [console]
disable_existing_loggers: false
EOF

# ── LiveKit server config ─────────────────────────────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    # Derive the TURN domain from livekit_url (wss://livekit.x.y → livekit.x.y)
    LK_DOMAIN=$(echo "${LIVEKIT_URL}" | sed 's|wss://||' | sed 's|ws://||' | cut -d'/' -f1)

    bashio::log.info "⚙️  Writing LiveKit configuration..."
    cat > "${LK_CONFIG}" << EOF
# LiveKit server config — generated by Matrix add-on v1.3.8
port: 7880
bind_addresses:
  - "0.0.0.0"

rtc:
  # Direct UDP port range for the SFU candidates (host + STUN-srflx).
  # Up to v1.3.8 everything had to go through the internal TURN server
  # (turn.enabled: true), which meant that for some clients ICE had to use
  # only the TURN relay path. That relay path, however, comes back via the
  # same public IP as the server itself (server → own WAN IP → TURN relay
  # port), which consistently fails without NAT hairpin on the router
  # (confirmed: LiveKit GitHub issue #4487, pion/turn issue #82 — TURN
  # relay-to-relay hairpin is a known, unsupported limitation). The direct
  # SFU path does not need this hairpin, which is why it is the more
  # reliable default. The internal TURN server can still be enabled
  # optionally (livekit_turn_enabled) for very restrictive networks that
  # allow only port 443/HTTPS.
  port_range_start: 30000
  port_range_end: 30020
  tcp_port: 7881
  use_external_ip: true
  # The public IPv4 found via STUN is accepted without a self-ping.
  # Routers without NAT hairpin never answer the validation ping: LiveKit
  # then discards the IP ("could not validate external IP", ~5 s delay)
  # and falls back to "no external IPs found, using node IP" instead of
  # setting the mapping local IP → public IP. Tested with LiveKit 1.13.10.
  skip_external_ip_validation: true

# API keys: key=devkey, secret from the add-on config
keys:
  devkey: "${LIVEKIT_SECRET}"

logging:
  json: false
  level: info
EOF

    if [ "${LIVEKIT_TURN_ENABLED}" = "true" ]; then
        cat >> "${LK_CONFIG}" << EOF

# TURN built-in — UDP 3478 only (no TLS without a certificate)
# Router: forward UDP 3478 AND UDP 30000-30020 → Pi
# Relay range deliberately kept small (21 ports instead of the LiveKit default
# 30000-40000 = 10,000 ports). Reason: Docker/HA Supervisor must declare every
# port individually in the config.yaml "ports:" mapping — 10,000 ports are
# impractical and, according to LiveKit's own docs, also a problem for the
# container start (separate iptables rule per port). 21 ports are enough for
# several simultaneous calls.
# Note: shares the 30000-30020 range with the direct SFU candidates
# above — LiveKit intends it that way and it is not a conflict.
turn:
  enabled: true
  domain: "${LK_DOMAIN}"
  udp_port: 3478
  relay_range_start: 30000
  relay_range_end: 30020
EOF
        bashio::log.info "   TURN UDP 3478 → ${LK_DOMAIN} (livekit_turn_enabled=true)"
    else
        bashio::log.info "   TURN disabled — direct SFU path via UDP 30000-30020 (livekit_turn_enabled=false)"
    fi
    bashio::log.info "✅ LiveKit Config: ${LK_CONFIG}"
    if [ "${LIVEKIT_TURN_ENABLED}" = "true" ]; then
        bashio::log.info "   ⚠️  Router: forward UDP 3478 AND UDP 30000-30020 → Pi (otherwise no audio/video in calls)"
    else
        bashio::log.info "   ⚠️  Router: forward UDP 30000-30020 → Pi (otherwise no audio/video in calls)"
    fi
fi

# ── Element Web config.json ───────────────────────────────────────────────
bashio::log.info "Writing Element Web config.json..."

# Primary: ask the Home Assistant Supervisor network API — that is the only
# reliable, network-independent source for the host's real LAN IP.
# Inside the container, `hostname -I` / /proc/net/fib_trie only see the
# Supervisor's internal Docker bridge network (e.g. 172.30.x.x), NEVER the
# actual LAN IP — that never works reliably, regardless of the subnet.
#
# Shortly after container start the Supervisor API is often not yet routable
# (the Supervisor itself needs a moment to finish setting up the internal
# network for the container that was just started) — hence 3 attempts
# with a short pause instead of giving up at the first failure.
LOCAL_IP=""
NETWORK_INFO=""
for attempt in 1 2 3; do
    NETWORK_INFO=$(curl -sf --max-time 5 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/network/info" 2>/dev/null)
    if [ -n "${NETWORK_INFO}" ]; then
        break
    fi
    [ "${attempt}" -lt 3 ] && sleep 2
done
if [ -n "${NETWORK_INFO}" ]; then
    LOCAL_IP=$(echo "${NETWORK_INFO}" \
        | jq -r '.data.interfaces[]? | select(.primary == true) | .ipv4.address[0]?' 2>/dev/null \
        | cut -d'/' -f1)
fi

# Fallback 1: old heuristic (only works if the Supervisor API is not
# reachable AND the container happens to be on the host network after all).
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    bashio::log.warning "Supervisor network API not reachable after 3 attempts — trying fallback detection"
    if [ -f /proc/net/fib_trie ]; then
        LOCAL_IP=$(awk '/32 HOST/ { print last } { last=$2 }' /proc/net/fib_trie 2>/dev/null \
            | grep -E "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" | head -1)
    fi
fi
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    LOCAL_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' \
        | grep -E "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" | head -1)
fi

# Fallback 2: hard-coded placeholder — last resort; config.<IP>.json
# is then written, but the browser never requests it under this hostname
# and it is therefore ignored without consequences.
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    LOCAL_IP="192.168.1.100"
    bashio::log.warning "Could not determine LAN IP — fallback: ${LOCAL_IP}"
fi
bashio::log.info "  Local IP: ${LOCAL_IP}"

# Voice section for the element-web config
VOICE_CONFIG=""
if [ "${ENABLE_VOICE}" = "true" ]; then
    VOICE_CONFIG=",
    \"features\": {
        \"feature_threads\": true,
        \"feature_group_calls\": true
    },
    \"element_call\": {
        \"url\": \"${ELEMENT_CALL_URL}\",
        \"participant_limit\": 8,
        \"brand\": \"Element Call\"
    }"
else
    VOICE_CONFIG=",
    \"features\": {
        \"feature_threads\": true
    }"
fi

# Bento themes as an additional choice next to light/dark (Settings → Appearance).
# The default stays default_theme. If the file is missing or broken, there are simply no
# additional themes — Element Web still starts.
BENTO_THEMES_FILE="/usr/share/matrix-themes/element-web-themes.json"
BENTO_THEMES="$(jq -c . "${BENTO_THEMES_FILE}" 2>/dev/null)" || BENTO_THEMES="[]"
[ -n "${BENTO_THEMES}" ] || BENTO_THEMES="[]"

# External config.json
cat > /data/matrix/element-web/config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${SERVER_NAME}",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Matrix",
    "default_theme": "dark",
    "setting_defaults": {
        "custom_themes": ${BENTO_THEMES}
    },
    "showLabsSettings": true,
    "default_federate": ${FEDERATE_FLAG}${VOICE_CONFIG}
}
EOF

# Local config (directly via IP)
cat > /data/matrix/element-web/config.${LOCAL_IP}.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "http://${LOCAL_IP}:8008",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Matrix",
    "default_theme": "dark",
    "setting_defaults": {
        "custom_themes": ${BENTO_THEMES}
    },
    "showLabsSettings": true,
    "default_federate": ${FEDERATE_FLAG}${VOICE_CONFIG}
}
EOF

ELEMENT_DOMAIN=$(echo "${ELEMENT_WEB_URL}" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)
cat > /data/matrix/element-web/config.${ELEMENT_DOMAIN}.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${SERVER_NAME}",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Matrix",
    "default_theme": "dark",
    "setting_defaults": {
        "custom_themes": ${BENTO_THEMES}
    },
    "showLabsSettings": true,
    "default_federate": ${FEDERATE_FLAG}${VOICE_CONFIG}
}
EOF

ELEMENT_HOSTNAME=$(echo "${ELEMENT_DOMAIN}" | sed 's/^matrix\./element./')
if [ "${ELEMENT_HOSTNAME}" != "${ELEMENT_DOMAIN}" ]; then
    cp /data/matrix/element-web/config.${ELEMENT_DOMAIN}.json \
       /data/matrix/element-web/config.${ELEMENT_HOSTNAME}.json 2>/dev/null || true
fi

# ── Element Call config.json ──────────────────────────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "Writing Element Call config.json..."
    EC_DOMAIN=$(echo "${ELEMENT_CALL_URL}" | sed 's|https://||' | sed 's|http://||' | cut -d'/' -f1)

    cat > /data/matrix/element-call/config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${SERVER_NAME}",
            "server_name": "${SERVER_NAME}"
        }
    },
    "livekit_service_url": "${LIVEKIT_JWT_URL}",
    "brand": "Element Call",
    "default_theme": "dark",
    "showLabsSettings": false
}
EOF
    # Also the domain-specific config
    cp /data/matrix/element-call/config.json \
       /data/matrix/element-call/config.${EC_DOMAIN}.json 2>/dev/null || true

    bashio::log.info "✅ Element Call config.json (livekit_jwt: ${LIVEKIT_JWT_URL})"
fi

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "✅ Initialization complete!"
bashio::log.info "  Server:      ${SERVER_NAME}"
bashio::log.info "  Element Web: http://[HA-IP]:7080"
bashio::log.info "  Synapse API: http://[HA-IP]:8008"
bashio::log.info "  Admin UI:    install the matrix_ketesa app (port 8091)"
if [ "${ENABLE_VOICE}" = "true" ]; then
bashio::log.info "  Element Call: http://[HA-IP]:7081"
bashio::log.info "  LiveKit API:  http://[HA-IP]:7880"
if [ "${LIVEKIT_TURN_ENABLED}" = "true" ]; then
bashio::log.info "  ⚠️  Router: forward UDP 3478 + UDP 30000-30020 + TCP 5349 → Pi! (TURN active)"
else
bashio::log.info "  ⚠️  Router: forward UDP 30000-30020 → Pi! (direct SFU path, TURN disabled)"
fi
fi
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
