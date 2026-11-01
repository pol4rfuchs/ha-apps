#!/usr/bin/with-contenv bashio
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Matrix Auth Service — Initialization"
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
PG_PASSWORD_FILE="${DATA_DIR}/.pg_password"

mkdir -p "${PG_DATA}" "${DATA_DIR}/logs"

# ── DB password ───────────────────────────────────────────────────────────
# Option > stored value > generate. If the option is empty, a random password
# is generated and stored only in /data (not in the log).
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
    printf '%s\n' "$1 mas WITH PASSWORD :'pw';" \
        | gosu postgres psql -p 5433 -v ON_ERROR_STOP=1 -v pw="${PG_PASSWORD}" >/dev/null
}

# ── PostgreSQL init (once) ────────────────────────────────────────────────
# Own Postgres instance, completely separate from Synapse — no schema
# sharing, no shared cluster. Port 5433 instead of 5432, purely for
# clarity in case someone debugs the containers in the same network
# namespace; the isolation itself does not need it because the containers
# are separate.
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    bashio::log.info "Initializing PostgreSQL database..."
    chown postgres:postgres "${PG_DATA}"
    gosu postgres /usr/lib/postgresql/17/bin/initdb \
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
timezone = 'UTC'
lc_messages = 'C'
lc_monetary = 'C'
lc_numeric = 'C'
lc_time = 'C'
EOF

    gosu postgres /usr/lib/postgresql/17/bin/pg_ctl \
        -D "${PG_DATA}" -l /tmp/pg_init.log -o "-p 5433" start -w -t 30
    pg_set_password "CREATE USER" || { bashio::log.error "Could not create the DB role 'mas'."; exit 1; }
    gosu postgres psql -p 5433 -c "CREATE DATABASE mas ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' template=template0 OWNER mas;"
    gosu postgres /usr/lib/postgresql/17/bin/pg_ctl -D "${PG_DATA}" stop -w

    touch "${PG_MARKER}"
    bashio::log.info "✅ PostgreSQL initialized"
else
    bashio::log.info "✅ PostgreSQL already initialized"
    touch "${PG_MARKER}"
    # The role was created on first start with the password of that time.
    # If the option has changed since, the DB no longer matches the config
    # (login fails) — sync it on every start.
    gosu postgres /usr/lib/postgresql/17/bin/pg_ctl \
        -D "${PG_DATA}" -l /tmp/pg_sync.log -o "-p 5433" start -w -t 30 \
        || { bashio::log.error "PostgreSQL does not start — see /tmp/pg_sync.log"; cat /tmp/pg_sync.log; exit 1; }
    pg_set_password "ALTER USER" || { bashio::log.error "Could not sync the DB password."; exit 1; }
    gosu postgres /usr/lib/postgresql/17/bin/pg_ctl -D "${PG_DATA}" stop -w
fi

# ── Synapse shared secret ─────────────────────────────────────────────────
# Must match 1:1 the value entered in the Synapse add-on under
# matrix_authentication_service.secret (option there: mas_secret).
# If the add-on option stays empty, a value is generated and persisted —
# it then has to be copied manually into the Synapse add-on.
if [ -z "${SYNAPSE_SECRET}" ]; then
    if [ -f "${SYNAPSE_SECRET_FILE}" ]; then
        SYNAPSE_SECRET=$(cat "${SYNAPSE_SECRET_FILE}")
        bashio::log.info "✅ synapse_secret loaded from storage"
    else
        SYNAPSE_SECRET=$(tr -d '-' < /proc/sys/kernel/random/uuid)$(tr -d '-' < /proc/sys/kernel/random/uuid)
        echo "${SYNAPSE_SECRET}" > "${SYNAPSE_SECRET_FILE}"
        bashio::log.info "✅ synapse_secret generated and stored"
        bashio::log.info "   → Value: ${SYNAPSE_SECRET_FILE}"
        bashio::log.info "   → Enter this value in the Synapse add-on under 'mas_secret'!"
    fi
fi

# ── MAS secrets (encryption key + signing keys) ───────────────────────────
# Generate once, NEVER again afterwards — a change invalidates all existing
# sessions/tokens. mas-cli config generate writes a complete config incl.
# random secrets/encryption + secrets/keys to stdout; we keep only the
# secrets part of it and maintain the rest (http/database/matrix/account/
# policy) ourselves in CONFIG_MAIN.
if [ ! -s "${CONFIG_SECRETS}" ]; then
    bashio::log.info "Generating MAS secrets (encryption + signing keys)..."
    mas-cli config generate > "${CONFIG_SECRETS}" 2>/tmp/mas_generate.log
    if [ ! -s "${CONFIG_SECRETS}" ]; then
        bashio::log.error "mas-cli config generate failed — see /tmp/mas_generate.log"
        cat /tmp/mas_generate.log
        exit 1
    fi
    chmod 600 "${CONFIG_SECRETS}"
    bashio::log.info "✅ Secrets generated: ${CONFIG_SECRETS} (do NOT delete — invalidates all sessions!)"
else
    bashio::log.info "✅ MAS secrets already present"
fi

# ── Prepare the admin user list as a YAML block ───────────────────────────
# The policy block is only written if at least one admin user is set —
# an empty "policy: data: admin_users:" without entries is valid YAML,
# but unnecessary ballast in the config.
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

# ── Main config (config.yaml) ────────────────────────────────────────────
bashio::log.info "Writing MAS config.yaml..."

# The password is part of the DB URI and must be URL-encoded (@ : / ? # % ...).
PG_PASSWORD_URI=$(jq -rn --arg p "${PG_PASSWORD}" '$p|@uri')

cat > "${CONFIG_MAIN}" << EOF
# public_base/issuer are required for MAS to build correct absolute
# redirect URIs for the OAuth/OIDC flow — without these two lines
# mas_domain used to be a pure phantom option (it was read, but never
# actually used).
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
  uri: "postgresql://mas:${PG_PASSWORD_URI}@127.0.0.1:5433/mas"
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
bashio::log.info "✅ Initialization complete!"
bashio::log.info "  MAS Domain:      ${MAS_DOMAIN}"
bashio::log.info "  Synapse Server:  ${SYNAPSE_SERVER_NAME}"
bashio::log.info "  Synapse endpoint: ${SYNAPSE_ENDPOINT}"
bashio::log.info "  Account-UI:      http://[HA-IP]:8082"
bashio::log.info "  ⚠️  In the Synapse add-on set: mas_enabled=true, mas_secret=<see above>, mas_endpoint=http://[HA-IP]:8082"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
