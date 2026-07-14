#!/usr/bin/with-contenv bashio
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Matrix Server ESS CE — Initialisierung"
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
LIVEKIT_SECRET=$(bashio::config 'livekit_secret')
ELEMENT_CALL_URL=$(bashio::config 'element_call_url' | sed 's|/$||')
LIVEKIT_URL=$(bashio::config 'livekit_url' | sed 's|/$||')
LIVEKIT_JWT_URL=$(bashio::config 'livekit_jwt_url' | sed 's|/$||')
# LK_DOMAIN früh ableiten — wird in Synapse TURN-Config und LiveKit-Config benötigt
LK_DOMAIN=$(echo "${LIVEKIT_URL}" | sed 's|wss://||' | sed 's|ws://||' | cut -d'/' -f1)

DATA_DIR="/data/matrix"
SYNAPSE_DATA="${DATA_DIR}/synapse"
PG_DATA="${DATA_DIR}/postgresql"
SYNAPSE_CONFIG="${SYNAPSE_DATA}/homeserver.yaml"
SIGNING_KEY="${SYNAPSE_DATA}/signing.key"
PG_MARKER="${DATA_DIR}/.pg_initialized"
LK_CONFIG="${DATA_DIR}/livekit.yaml"
LK_SECRET_FILE="${DATA_DIR}/.livekit_secret"

mkdir -p "${SYNAPSE_DATA}" "${PG_DATA}" "/media/matrix" \
         "${DATA_DIR}/logs" "${SYNAPSE_DATA}/media_store" \
         "${DATA_DIR}/element-web" "${DATA_DIR}/element-call"

# ── PostgreSQL init (einmalig) ────────────────────────────────────────────
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    bashio::log.info "Initialisiere PostgreSQL Datenbank..."
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
timezone = 'Europe/Vienna'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
EOF

    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl \
        -D "${PG_DATA}" -l /tmp/pg_init.log start -w -t 30
    gosu postgres psql -c "CREATE USER synapse WITH PASSWORD '${PG_PASSWORD}';"
    gosu postgres psql -c "CREATE DATABASE synapse ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0 OWNER synapse;"
    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl -D "${PG_DATA}" stop -w

    touch "${PG_MARKER}"
    bashio::log.info "✅ PostgreSQL initialisiert"
else
    bashio::log.info "✅ PostgreSQL bereits initialisiert"
    touch "${PG_MARKER}"
fi

# ── Synapse Signing Key ───────────────────────────────────────────────────
if [ ! -f "${SIGNING_KEY}" ]; then
    bashio::log.info "Generiere Synapse Signing Key..."
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
        bashio::log.info "✅ registration_shared_secret aus Speicher geladen"
    else
        REG_SECRET=$(cat /proc/sys/kernel/random/uuid | tr -d '-')
        echo "${REG_SECRET}" > "${SECRET_FILE}"
        bashio::log.info "✅ registration_shared_secret generiert und gespeichert"
        bashio::log.info "   → Wert: ${SECRET_FILE} (nicht im Log, siehe Sicherheitshinweis)"
    fi
fi

# ── LiveKit Secret ────────────────────────────────────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    if [ -z "${LIVEKIT_SECRET}" ]; then
        if [ -f "${LK_SECRET_FILE}" ]; then
            LIVEKIT_SECRET=$(cat "${LK_SECRET_FILE}")
            bashio::log.info "✅ LiveKit Secret aus Speicher geladen"
        else
            LIVEKIT_SECRET=$(cat /proc/sys/kernel/random/uuid | tr -d '-')$(cat /proc/sys/kernel/random/uuid | tr -d '-')
            echo "${LIVEKIT_SECRET}" > "${LK_SECRET_FILE}"
            bashio::log.info "✅ LiveKit Secret generiert und gespeichert"
            bashio::log.info "   → Trage es optional in die Addon-Config ein (livekit_secret)"
        fi
    fi
fi

# ── Synapse homeserver.yaml ───────────────────────────────────────────────
bashio::log.info "Schreibe Synapse homeserver.yaml..."

if [ "${ENABLE_FEDERATION}" = "true" ]; then
    FEDERATE_FLAG="true"
else
    FEDERATE_FLAG="false"
fi

cat > "${SYNAPSE_CONFIG}" << EOF
server_name: "${SERVER_NAME}"
# public_baseurl ist zwingend nötig, damit Synapse extra_well_known_client_content
# (siehe rtc_foci weiter unten) ueberhaupt in die /.well-known/matrix/client
# Antwort mit reinmischt — ohne diese Zeile wird der Extra-Content von Synapse
# schlicht ignoriert, auch wenn er syntaktisch korrekt in der Config steht.
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
    password: "${PG_PASSWORD}"
    database: synapse
    host: 127.0.0.1
    port: 5432
    cp_min: 5
    cp_max: 10

media_store_path: "${SYNAPSE_DATA}/media_store"
max_upload_size: "${MAX_UPLOAD}M"
no_tls: true

enable_registration: $([ "${ENABLE_REGISTRATION}" = "true" ] && echo "true" || echo "false")
enable_registration_without_verification: true
registration_shared_secret: "${REG_SECRET}"

signing_key_path: "${SIGNING_KEY}"
suppress_key_server_warning: true
trusted_key_servers:
  - server_name: "matrix.org"

log_config: "${SYNAPSE_DATA}/log.yaml"

rc_message:
  per_second: 0.2
  burst_count: 10

report_stats: false

url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'

# ── ip_range_whitelist — Ausnahme für lokal gehosteten ntfy-Push-Server ──
# Synapses Standard-ip_range_blacklist (privater IP-Bereich) greift auch
# für HTTP-Pusher-Requests, nicht nur für URL-Previews. Der ntfy-Server
# liegt im selben privaten Netz (Split-Horizon-DNS löst die Domain intern
# direkt auf die LAN-IP auf) — ohne explizite Whitelist blockiert Synapse
# den Push aus SSRF-Schutzgründen und schlägt mit DNSLookupError fehl.
ip_range_whitelist:
  - '10.10.20.10'
EOF

# ── Element Call / MSC3401 Support (Voice/Video) ──────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    bashio::log.info "🎤 Konfiguriere Element Call Support in Synapse..."
    cat >> "${SYNAPSE_CONFIG}" << EOF

# ── Element Call / MSC3401 (Voice/Video) ────────────────────────────────
experimental_features:
  msc3266_enabled: true
  msc3401_enabled: true
  msc2285_enabled: true

# Höhere Rate Limits für Call-Signaling
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

# TURN für Legacy 1:1 Calls (behebt "falsch konfigurierter Server" Dialog)
turn_uris:
  - "turn:${LK_DOMAIN}:3478?transport=udp"
turn_shared_secret: "${LIVEKIT_SECRET}"
turn_user_lifetime: 86400000
turn_allow_guests: true

# ── MSC4143 rtc_foci — MatrixRTC-Discovery für moderne Clients ───────────
# Ohne diesen Eintrag im .well-known/matrix/client wissen aktuelle Clients
# (Element X, aktuelles Element Web, SchildiChat) nicht, welchen LiveKit-
# Server sie für Calls verwenden sollen — sie brechen den Call-Versuch
# lokal ab, BEVOR irgendeine Netzwerkverbindung nach draußen aufgebaut
# wird. Betrifft nur den nativen MatrixRTC-Pfad; der alte Widget-Ansatz
# (element_call.url in element-web config.json) läuft weiter unabhängig
# davon, was erklärt, warum ältere/andere Clients teilweise noch funktionieren.
# Referenz: https://github.com/element-hq/synapse/issues/18859
extra_well_known_client_content:
  org.matrix.msc4143.rtc_foci:
    - type: "livekit"
      livekit_service_url: "${LIVEKIT_JWT_URL}"
EOF
fi

# ── Push-Konfiguration (immer aktiv) ─────────────────────────────────────
# include_content: true → Synapse bettet den vollständigen Nachrichtentext
# in Push-Notifications ein. Ohne diese Option sehen Clients nur "New message".
# Gilt für alle Push-Methoden (UnifiedPush, FCM, APNs) — daher bedingungslos.
cat >> "${SYNAPSE_CONFIG}" << EOF

push:
  include_content: true
EOF

# ── ntfy UnifiedPush (optional) ───────────────────────────────────────────
# Hinweis: Synapse muss ntfy_url NICHT kennen — der UnifiedPush-Client
# (Element Android) trägt die Gateway-URL selbst bei Synapse ein.
# ntfy_url wird hier ausschließlich für einen Erreichbarkeitscheck genutzt.
if [ -n "${NTFY_URL}" ]; then
    bashio::log.info "🔔 ntfy UnifiedPush Gateway: ${NTFY_URL}/_matrix/push/v1/notify"
    # Erreichbarkeitscheck (POST erwartet — 400 ist OK, Timeout/000 ist Fehler)
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        --max-time 5 \
        -X POST "${NTFY_URL}/_matrix/push/v1/notify" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null || echo "000")
    if [ "${HTTP_CODE}" = "000" ]; then
        bashio::log.warning "⚠️  ntfy Gateway nicht erreichbar: ${NTFY_URL}"
        bashio::log.warning "   Prüfen: base_url im ntfy Addon gesetzt? Reverse Proxy aktiv?"
    else
        bashio::log.info "✅ ntfy Gateway erreichbar (HTTP ${HTTP_CODE})"
        bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        bashio::log.info " UnifiedPush Setup:"
        bashio::log.info "   1. ntfy App (F-Droid) auf Android installieren"
        bashio::log.info "   2. Server in ntfy App: ${NTFY_URL}"
        bashio::log.info "   3. Element: Einstellungen → Benachrichtigungen"
        bashio::log.info "      → ntfy als UnifiedPush Distributor wählen"
        bashio::log.info "   Synapse wird automatisch vom Client konfiguriert."
        bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
fi

# ── Synapse Log-Config ────────────────────────────────────────────────────
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

# ── LiveKit Server Config ─────────────────────────────────────────────────
if [ "${ENABLE_VOICE}" = "true" ]; then
    # TURN Domain aus livekit_url ableiten (wss://livekit.x.y → livekit.x.y)
    LK_DOMAIN=$(echo "${LIVEKIT_URL}" | sed 's|wss://||' | sed 's|ws://||' | cut -d'/' -f1)

    bashio::log.info "⚙️  Schreibe LiveKit Konfiguration (TURN: ${LK_DOMAIN})..."
    cat > "${LK_CONFIG}" << EOF
# LiveKit Server Config — generiert von Matrix Addon v1.3.8
port: 7880
bind_addresses:
  - "0.0.0.0"

rtc:
  # Kein direktes UDP-Range nötig — alle Clients gehen über TURN
  # TCP-Fallback innerhalb des TURN-Flows
  tcp_port: 7881
  use_external_ip: true

# API-Keys: Key=devkey, Secret=aus Addon-Config
keys:
  devkey: "${LIVEKIT_SECRET}"

logging:
  json: false
  level: info

# TURN built-in — nur UDP 3478 (kein TLS ohne Zertifikat)
# Router: UDP 3478 UND UDP 30000-30020 → Pi freigeben
# Relay-Range explizit klein gehalten (21 Ports statt LiveKit-Default
# 30000-40000 = 10.000 Ports). Grund: Docker/HA Supervisor muss jeden Port
# einzeln im config.yaml "ports:"-Mapping deklarieren — 10.000 Ports sind
# unpraktikabel und laut LiveKit-eigener Doku auch für den Container-Start
# ein Problem (separate iptables-Regel pro Port). 21 Ports reichen für
# mehrere gleichzeitige Calls.
turn:
  enabled: true
  domain: "${LK_DOMAIN}"
  udp_port: 3478
  relay_range_start: 30000
  relay_range_end: 30020
EOF
    bashio::log.info "✅ LiveKit Config: ${LK_CONFIG}"
    bashio::log.info "   TURN UDP 3478 → ${LK_DOMAIN}"
    bashio::log.info "   ⚠️  Router: UDP 3478 UND UDP 30000-30020 → Pi freigeben (sonst kein Ton/Bild bei Calls)"
fi

# ── Element Web config.json ───────────────────────────────────────────────
bashio::log.info "Schreibe Element Web config.json..."

# Primär: Home Assistant Supervisor Network API fragen — das ist die einzige
# zuverlässige, netzwerk-unabhängige Quelle für die echte LAN-IP des Hosts.
# Innerhalb des Containers sieht `hostname -I` / /proc/net/fib_trie nur das
# interne Docker-Bridge-Netz des Supervisors (z.B. 172.30.x.x), NIEMALS die
# tatsächliche LAN-IP — das funktioniert unabhängig vom Subnetz nie zuverlässig.
#
# Kurz nach Container-Start ist die Supervisor-API oft noch nicht routbar
# (Supervisor braucht selbst noch einen Moment, um das interne Netzwerk für
# den gerade gestarteten Container fertig einzurichten) — deshalb 3 Versuche
# mit kurzer Pause statt sofort beim ersten Fehlschlag aufzugeben.
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

# Fallback 1: alte Heuristik (funktioniert nur, falls Supervisor-API nicht
# erreichbar ist UND der Container zufällig doch im Host-Netz hängt).
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    bashio::log.warning "Supervisor Network API nach 3 Versuchen nicht erreichbar — versuche Fallback-Erkennung"
    if [ -f /proc/net/fib_trie ]; then
        LOCAL_IP=$(awk '/32 HOST/ { print last } { last=$2 }' /proc/net/fib_trie 2>/dev/null \
            | grep -E "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" | head -1)
    fi
fi
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    LOCAL_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' \
        | grep -E "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" | head -1)
fi

# Fallback 2: hartcodierter Platzhalter — letzte Instanz, config.<IP>.json
# wird dann zwar geschrieben, aber vom Browser nie unter diesem Hostnamen
# angefragt und daher folgenlos ignoriert.
if [ -z "${LOCAL_IP}" ] || [ "${LOCAL_IP}" = "null" ]; then
    LOCAL_IP="192.168.1.100"
    bashio::log.warning "Konnte LAN-IP nicht ermitteln — Fallback: ${LOCAL_IP}"
fi
bashio::log.info "  Lokale IP: ${LOCAL_IP}"

# Voice-Sektion für element-web config
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

# Externe config.json
cat > /data/matrix/element-web/config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${SERVER_NAME}",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Matrix @ Home",
    "default_theme": "dark",
    "showLabsSettings": true,
    "default_federate": ${FEDERATE_FLAG}${VOICE_CONFIG}
}
EOF

# Lokale config (direkt via IP)
cat > /data/matrix/element-web/config.${LOCAL_IP}.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "http://${LOCAL_IP}:8008",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Matrix @ Home",
    "default_theme": "dark",
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
    "brand": "Matrix @ Home",
    "default_theme": "dark",
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
    bashio::log.info "Schreibe Element Call config.json..."
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
    # Auch domain-spezifische config
    cp /data/matrix/element-call/config.json \
       /data/matrix/element-call/config.${EC_DOMAIN}.json 2>/dev/null || true

    bashio::log.info "✅ Element Call config.json (livekit_jwt: ${LIVEKIT_JWT_URL})"
fi

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "✅ Initialisierung abgeschlossen!"
bashio::log.info "  Server:      ${SERVER_NAME}"
bashio::log.info "  Element Web: http://[HA-IP]:7080"
bashio::log.info "  Synapse API: http://[HA-IP]:8008"
bashio::log.info "  Admin UI:    http://[HA-IP]:8090"
if [ "${ENABLE_VOICE}" = "true" ]; then
bashio::log.info "  Element Call: http://[HA-IP]:7081"
bashio::log.info "  LiveKit API:  http://[HA-IP]:7880"
bashio::log.info "  ⚠️  Router: UDP 3478 + UDP 30000-30020 + TCP 5349 → Pi freigeben!"
fi
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
