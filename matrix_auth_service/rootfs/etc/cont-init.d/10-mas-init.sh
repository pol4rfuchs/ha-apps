#!/usr/bin/with-contenv bashio
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Matrix Auth Service — Initialisierung"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MAS_DOMAIN=$(bashio::config 'mas_domain' | sed 's|/$||')
SYNAPSE_SERVER_NAME=$(bashio::config 'synapse_server_name' | sed 's|/$||')
SYNAPSE_ENDPOINT=$(bashio::config 'synapse_endpoint' | sed 's|/$||')
SYNAPSE_SECRET=$(bashio::config 'synapse_secret')
PG_PASSWORD=$(bashio::config 'postgres_password')
ADMIN_USERS=$(bashio::config 'admin_users')
PW_REGISTRATION=$(bashio::config 'password_registration_enabled')
PW_LOGIN=$(bashio::config 'password_login_enabled')
ACCOUNT_DEACTIVATION=$(bashio::config 'account_deactivation_allowed')
LOG_LEVEL=$(bashio::config 'log_level')

DATA_DIR="/data/mas"
PG_DATA="${DATA_DIR}/postgresql"
PG_MARKER="${DATA_DIR}/.pg_initialized"
CONFIG_MAIN="${DATA_DIR}/config.yaml"
CONFIG_SECRETS="${DATA_DIR}/secrets.yaml"
SYNAPSE_SECRET_FILE="${DATA_DIR}/.synapse_secret"

mkdir -p "${PG_DATA}" "${DATA_DIR}/logs"

# ── PostgreSQL init (einmalig) ────────────────────────────────────────────
# Eigene, von Synapse komplett getrennte Postgres-Instanz — kein Schema-
# Sharing, kein gemeinsamer Cluster. Port 5433 statt 5432, rein zur
# Klarheit falls jemand die Container mal im selben Netzwerk-Namespace
# debuggt; für die Isolation selbst ist es wegen getrennter Container
# nicht nötig.
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
local   mas             mas                                     md5
host    mas             mas             127.0.0.1/32            md5
EOF
    cat > "${PG_DATA}/postgresql.conf" << EOF
listen_addresses = '127.0.0.1'
port = 5433
max_connections = 50
shared_buffers = 64MB
effective_cache_size = 128MB
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
        -D "${PG_DATA}" -l /tmp/pg_init.log -o "-p 5433" start -w -t 30
    gosu postgres psql -p 5433 -c "CREATE USER mas WITH PASSWORD '${PG_PASSWORD}';"
    gosu postgres psql -p 5433 -c "CREATE DATABASE mas ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0 OWNER mas;"
    gosu postgres /usr/lib/postgresql/15/bin/pg_ctl -D "${PG_DATA}" stop -w

    touch "${PG_MARKER}"
    bashio::log.info "✅ PostgreSQL initialisiert"
else
    bashio::log.info "✅ PostgreSQL bereits initialisiert"
    touch "${PG_MARKER}"
fi

# ── Synapse Shared Secret ─────────────────────────────────────────────────
# Muss 1:1 dem Wert entsprechen, der im Synapse-Add-on unter
# matrix_authentication_service.secret eingetragen wird (dortige Option:
# mas_secret). Bleibt die Addon-Option leer, wird ein Wert generiert und
# persistiert — muss dann manuell ins Synapse-Add-on übertragen werden.
if [ -z "${SYNAPSE_SECRET}" ]; then
    if [ -f "${SYNAPSE_SECRET_FILE}" ]; then
        SYNAPSE_SECRET=$(cat "${SYNAPSE_SECRET_FILE}")
        bashio::log.info "✅ synapse_secret aus Speicher geladen"
    else
        SYNAPSE_SECRET=$(tr -d '-' < /proc/sys/kernel/random/uuid)$(tr -d '-' < /proc/sys/kernel/random/uuid)
        echo "${SYNAPSE_SECRET}" > "${SYNAPSE_SECRET_FILE}"
        bashio::log.info "✅ synapse_secret generiert und gespeichert"
        bashio::log.info "   → Wert: ${SYNAPSE_SECRET_FILE}"
        bashio::log.info "   → Diesen Wert im Synapse-Add-on unter 'mas_secret' eintragen!"
    fi
fi

# ── MAS Secrets (Encryption-Key + Signing-Keys) ───────────────────────────
# Einmalig generieren, danach NIE wieder — ein Wechsel invalidiert alle
# bestehenden Sessions/Tokens. mas-cli config generate schreibt eine
# vollständige Config inkl. zufälliger secrets/encryption + secrets/keys
# nach stdout; wir behalten daraus nur den secrets-Teil und pflegen den
# Rest (http/database/matrix/account/policy) selbst in CONFIG_MAIN.
if [ ! -f "${CONFIG_SECRETS}" ]; then
    bashio::log.info "Generiere MAS Secrets (Encryption + Signing-Keys)..."
    mas-cli config generate > "${CONFIG_SECRETS}" 2>/tmp/mas_generate.log
    if [ ! -s "${CONFIG_SECRETS}" ]; then
        bashio::log.error "mas-cli config generate fehlgeschlagen — siehe /tmp/mas_generate.log"
        cat /tmp/mas_generate.log
        exit 1
    fi
    chmod 600 "${CONFIG_SECRETS}"
    bashio::log.info "✅ Secrets generiert: ${CONFIG_SECRETS} (NICHT löschen — invalidiert alle Sessions!)"
else
    bashio::log.info "✅ MAS Secrets bereits vorhanden"
fi

# ── Admin-User-Liste als YAML-Block vorbereiten ───────────────────────────
# Policy-Block wird nur geschrieben, wenn mindestens ein Admin-User gesetzt
# ist — leeres "policy: data: admin_users:" ohne Einträge ist zwar gültiges
# YAML, aber unnötiger Ballast in der Config.
POLICY_BLOCK=""
if [ -n "${ADMIN_USERS}" ]; then
    POLICY_BLOCK="policy:
  data:
    admin_users:
"
    IFS=',' read -ra USERS <<< "${ADMIN_USERS}"
    for u in "${USERS[@]}"; do
        u_trimmed=$(echo "${u}" | xargs)
        [ -n "${u_trimmed}" ] && POLICY_BLOCK="${POLICY_BLOCK}      - ${u_trimmed}
"
    done
fi

# ── Haupt-Config (config.yaml) ────────────────────────────────────────────
bashio::log.info "Schreibe MAS config.yaml..."

cat > "${CONFIG_MAIN}" << EOF
# public_base/issuer sind zwingend nötig, damit MAS korrekte absolute
# Redirect-URIs für den OAuth/OIDC-Flow baut — ohne diese zwei Zeilen war
# mas_domain bislang eine reine Phantom-Option (wurde gelesen, aber nie
# tatsächlich verwendet).
http:
  public_base: "https://${MAS_DOMAIN}/"
  issuer: "https://${MAS_DOMAIN}/"
  listeners:
    - name: web
      resources:
        - name: discovery
        - name: human
        - name: oauth
        - name: compat
        - name: graphql
          playground: false
        - name: assets
          path: /usr/local/share/mas-cli/assets
      binds:
        - address: "0.0.0.0:8082"
      proxy_protocol: false
    - name: internal
      resources:
        - name: health
      binds:
        - address: "0.0.0.0:8083"

database:
  uri: "postgresql://mas:${PG_PASSWORD}@127.0.0.1:5433/mas"
  max_connections: 10

matrix:
  homeserver: "${SYNAPSE_SERVER_NAME}"
  secret: "${SYNAPSE_SECRET}"
  endpoint: "${SYNAPSE_ENDPOINT}"

account:
  password_registration_enabled: $([ "${PW_REGISTRATION}" = "true" ] && echo "true" || echo "false")
  password_login_enabled: $([ "${PW_LOGIN}" = "true" ] && echo "true" || echo "false")
  password_recovery_enabled: false
  account_deactivation_allowed: $([ "${ACCOUNT_DEACTIVATION}" = "true" ] && echo "true" || echo "false")
  login_with_email_allowed: false

${POLICY_BLOCK}
telemetry:
  tracing:
    enabled: false
  metrics:
    enabled: false

logging:
  format: text
  level: "${LOG_LEVEL}"
EOF

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "✅ Initialisierung abgeschlossen!"
bashio::log.info "  MAS Domain:      ${MAS_DOMAIN}"
bashio::log.info "  Synapse Server:  ${SYNAPSE_SERVER_NAME}"
bashio::log.info "  Synapse Endpoint: ${SYNAPSE_ENDPOINT}"
bashio::log.info "  Account-UI:      http://[HA-IP]:8082"
bashio::log.info "  ⚠️  Im Synapse-Add-on: mas_enabled=true, mas_secret=<siehe oben>, mas_endpoint=http://[HA-IP]:8082 setzen"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
