#!/usr/bin/with-contenv bashio
# ==============================================================================
# Signal Bridge (mautrix) — Config-Init
# Läuft einmalig vor dem Service-Start (legacy-cont-init), s6-rc.d/signal-
# bridge/run wartet auf das Ergebnis (config.yaml).
# ==============================================================================
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Signal Bridge (mautrix) — Initialisierung"
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
EXAMPLE_CONFIG="/opt/mautrix-signal/example-config.yaml"

mkdir -p "${DATA_DIR}"

# ── DB-URI je nach gewähltem Backend zusammenbauen ────────────────────────
if [ "${DB_TYPE}" = "postgres" ]; then
    DB_URI="postgres://$(bashio::config 'postgres_username'):$(bashio::config 'postgres_password')@$(bashio::config 'postgres_host'):$(bashio::config 'postgres_port')/$(bashio::config 'postgres_database')?sslmode=disable"
    DB_TYPE_VAL="postgres"
else
    DB_URI="${DATA_DIR}/mautrix-signal.db"
    DB_TYPE_VAL="sqlite3"
fi

# ── config.yaml aus example-config.yaml erzeugen (nur beim allerersten Start) ──
if [ ! -f "${CONFIG_PATH}" ]; then
    bashio::log.info "Erzeuge config.yaml aus example-config.yaml..."
    cp "${EXAMPLE_CONFIG}" "${CONFIG_PATH}"
fi

bashio::log.info "Schreibe Options in config.yaml..."
yq -i "
  .homeserver.address = \"${HOMESERVER_ADDRESS}\" |
  .homeserver.domain = \"${HOMESERVER_DOMAIN}\" |
  .appservice.address = \"${APPSERVICE_ADDRESS}\" |
  .appservice.hostname = \"0.0.0.0\" |
  .appservice.port = 29328 |
  .appservice.id = \"${APPSERVICE_ID}\" |
  .appservice.database.type = \"${DB_TYPE_VAL}\" |
  .appservice.database.uri = \"${DB_URI}\" |
  .bridge.encryption.allow = ${ENCRYPTION} |
  .bridge.encryption.default = ${ENCRYPTION}
" "${CONFIG_PATH}"

# ── Appservice-Registrierung (nur beim allerersten Start, danach stabil) ──
# WICHTIG: registration.yaml enthält as_token/hs_token — wird NICHT neu
# generiert, sobald sie einmal existiert (sonst verliert Synapse die
# Appservice-Kopplung bei jedem Neustart).
if [ ! -f "${REG_PATH}" ]; then
    bashio::log.info "Erste Registrierung — generiere registration.yaml..."
    mautrix-signal -c "${CONFIG_PATH}" -r "${REG_PATH}" -g
    cp "${REG_PATH}" "${SHARE_REG_PATH}"
    bashio::log.warning "registration.yaml nach ${SHARE_REG_PATH} kopiert!"
    bashio::log.warning "→ Im Matrix-Synapse-Add-on 'signal_bridge_enabled' aktivieren und Synapse neu starten."
else
    # Falls /share leer ist (z.B. nach Restore, wo /data erhalten blieb,
    # /share aber nicht Teil des Backups war) erneut hinkopieren.
    if [ ! -f "${SHARE_REG_PATH}" ]; then
        cp "${REG_PATH}" "${SHARE_REG_PATH}"
        bashio::log.info "registration.yaml erneut nach /share kopiert (war dort nicht vorhanden)."
    fi
fi

bashio::log.info "Init abgeschlossen."
