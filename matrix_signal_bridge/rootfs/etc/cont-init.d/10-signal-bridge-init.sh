#!/usr/bin/with-contenv bashio
# ==============================================================================
# Signal Bridge (mautrix) — config init
# Runs once before the service starts (legacy-cont-init); s6-rc.d/signal-
# bridge/run waits for the result (config.yaml).
# ==============================================================================
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Signal Bridge (mautrix) — Initialization"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LOG_LEVEL=$(bashio::config 'log_level')
bashio::log.level "${LOG_LEVEL}"

HOMESERVER_ADDRESS=$(bashio::config 'homeserver_address')
HOMESERVER_DOMAIN=$(bashio::config 'homeserver_domain')
APPSERVICE_ADDRESS=$(bashio::config 'appservice_address')
APPSERVICE_ID=$(bashio::config 'appservice_id')
DB_TYPE=$(bashio::config 'db_type')
ENCRYPTION=$(bashio::config 'encryption')

DATA_DIR="/data"
CONFIG_PATH="${DATA_DIR}/config.yaml"
REG_PATH="${DATA_DIR}/registration.yaml"
SHARE_REG_PATH="/share/signal_bridge_registration.yaml"

mkdir -p "${DATA_DIR}"

# ── Build the DB URI depending on the selected backend ────────────────────────
if [ "${DB_TYPE}" = "postgres" ]; then
    # URL-encode user, password and DB name: characters like @ : / ? # % in the
    # password would otherwise break the URI (wrong host/DB, truncated password).
    PG_USER=$(jq -rn --arg v "$(bashio::config 'postgres_username')" '$v|@uri')
    PG_PASS=$(jq -rn --arg v "$(bashio::config 'postgres_password')" '$v|@uri')
    PG_DB=$(jq -rn --arg v "$(bashio::config 'postgres_database')" '$v|@uri')
    DB_URI="postgres://${PG_USER}:${PG_PASS}@$(bashio::config 'postgres_host'):$(bashio::config 'postgres_port')/${PG_DB}?sslmode=disable"
    DB_TYPE_VAL="postgres"
else
    DB_URI="file:${DATA_DIR}/mautrix-signal.db?_txlock=immediate"
    DB_TYPE_VAL="sqlite3-fk-wal"
fi

# ── Generate config.yaml (only on the very first start) ──────────────────────
# "-e" writes the complete example config (network, bridge, database,
# homeserver, appservice, encryption, ...). pkg/connector/example-config.yaml
# from the source tree contains only the network part and is rejected by the
# bridge as a legacy config.
if [ ! -f "${CONFIG_PATH}" ]; then
    bashio::log.info "Generating config.yaml (mautrix-signal -e)..."
    if ! mautrix-signal -c "${CONFIG_PATH}" -e; then
        bashio::log.error "mautrix-signal could not generate an example config."
        exit 1
    fi
fi

bashio::log.info "Writing options to config.yaml..."
# Pass values via the environment + strenv() instead of interpolating them into
# the expression: a " or \ in a password/hash/domain would otherwise make the
# yq expression invalid and the config would silently stay at the old state.
YQ_HOMESERVER_ADDRESS="${HOMESERVER_ADDRESS}" \
YQ_HOMESERVER_DOMAIN="${HOMESERVER_DOMAIN}" \
YQ_APPSERVICE_ADDRESS="${APPSERVICE_ADDRESS}" \
YQ_APPSERVICE_ID="${APPSERVICE_ID}" \
YQ_DB_TYPE_VAL="${DB_TYPE_VAL}" \
YQ_DB_URI="${DB_URI}" \
YQ_LOG_LEVEL="${LOG_LEVEL}" \
YQ_ENCRYPTION="${ENCRYPTION}" \
yq -i '
  .homeserver.address = strenv(YQ_HOMESERVER_ADDRESS) |
  .homeserver.domain = strenv(YQ_HOMESERVER_DOMAIN) |
  .appservice.address = strenv(YQ_APPSERVICE_ADDRESS) |
  .appservice.hostname = "0.0.0.0" |
  .appservice.port = 29328 |
  .appservice.id = strenv(YQ_APPSERVICE_ID) |
  .database.type = strenv(YQ_DB_TYPE_VAL) |
  .database.uri = strenv(YQ_DB_URI) |
  .encryption.allow = env(YQ_ENCRYPTION) |
  .encryption.default = env(YQ_ENCRYPTION) |
  .logging.min_level = strenv(YQ_LOG_LEVEL) |
  .bridge.permissions = {"*": "relay", strenv(YQ_HOMESERVER_DOMAIN): "user"}
' "${CONFIG_PATH}"
YQ_RC=$?
if [ "${YQ_RC}" -ne 0 ]; then
    bashio::log.error "config.yaml could not be updated (yq rc=${YQ_RC}), aborting."
    exit 1
fi

# ── Appservice registration (only on the very first start, stable afterwards) ──
# IMPORTANT: registration.yaml contains as_token/hs_token — it is NOT
# regenerated once it exists (otherwise Synapse loses the appservice
# link on every restart).
if [ ! -f "${REG_PATH}" ]; then
    bashio::log.info "First registration — generating registration.yaml..."
    if ! mautrix-signal -c "${CONFIG_PATH}" -r "${REG_PATH}" -g || [ ! -f "${REG_PATH}" ]; then
        bashio::log.error "registration.yaml could not be generated (check the config, see the output above)."
        exit 1
    fi
    if cp "${REG_PATH}" "${SHARE_REG_PATH}"; then
        bashio::log.warning "registration.yaml copied to ${SHARE_REG_PATH}!"
        bashio::log.warning "→ Enable 'signal_bridge_enabled' in the Matrix Synapse add-on and restart Synapse."
    else
        bashio::log.error "registration.yaml could NOT be copied to ${SHARE_REG_PATH} (see the cp error above)."
        bashio::log.error "→ Synapse will not find the bridge this way. Is /share mounted and writable? It will be copied again on the next start."
    fi
else
    # If /share is empty (e.g. after a restore where /data was kept but
    # /share was not part of the backup), copy it there again.
    if [ ! -f "${SHARE_REG_PATH}" ]; then
        if cp "${REG_PATH}" "${SHARE_REG_PATH}"; then
            bashio::log.info "registration.yaml copied to /share again (it was not there)."
        else
            bashio::log.error "registration.yaml could NOT be copied to ${SHARE_REG_PATH} (see the cp error above). Is /share mounted and writable?"
        fi
    fi
fi

bashio::log.info "Init complete."
