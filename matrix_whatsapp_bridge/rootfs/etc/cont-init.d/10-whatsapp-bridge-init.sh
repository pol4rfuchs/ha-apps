#!/usr/bin/with-contenv bashio
# ==============================================================================
# WhatsApp Bridge (mautrix) — Config-Init
# Läuft einmalig vor dem Service-Start (legacy-cont-init), s6-rc.d/whatsapp-
# bridge/run wartet auf das Ergebnis (config.yaml).
# ==============================================================================
set +e

bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  WhatsApp Bridge (mautrix) — Initialisierung"
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
SHARE_REG_PATH="/share/whatsapp_bridge_registration.yaml"

mkdir -p "${DATA_DIR}"

# ── DB-URI je nach gewähltem Backend zusammenbauen ────────────────────────
if [ "${DB_TYPE}" = "postgres" ]; then
    DB_URI="postgres://$(bashio::config 'postgres_username'):$(bashio::config 'postgres_password')@$(bashio::config 'postgres_host'):$(bashio::config 'postgres_port')/$(bashio::config 'postgres_database')?sslmode=disable"
    DB_TYPE_VAL="postgres"
else
    DB_URI="${DATA_DIR}/mautrix-whatsapp.db"
    DB_TYPE_VAL="sqlite3-fk-wal"
fi

# ── config.yaml erzeugen (nur beim allerersten Start) ──────────────────────
# "-e" schreibt die vollständige Beispiel-Config (network, bridge, database,
# homeserver, appservice, encryption, ...). pkg/connector/example-config.yaml
# aus dem Quellbaum enthält nur den network-Teil und wird von der Bridge als
# Legacy-Config abgelehnt.
if [ ! -f "${CONFIG_PATH}" ]; then
    bashio::log.info "Erzeuge config.yaml (mautrix-whatsapp -e)..."
    if ! mautrix-whatsapp -c "${CONFIG_PATH}" -e; then
        bashio::log.error "mautrix-whatsapp konnte keine Beispiel-Config erzeugen."
        exit 1
    fi
fi

bashio::log.info "Schreibe Options in config.yaml..."
yq -i "
  .homeserver.address = \"${HOMESERVER_ADDRESS}\" |
  .homeserver.domain = \"${HOMESERVER_DOMAIN}\" |
  .appservice.address = \"${APPSERVICE_ADDRESS}\" |
  .appservice.hostname = \"0.0.0.0\" |
  .appservice.port = 29318 |
  .appservice.id = \"${APPSERVICE_ID}\" |
  .database.type = \"${DB_TYPE_VAL}\" |
  .database.uri = \"${DB_URI}\" |
  .encryption.allow = ${ENCRYPTION} |
  .encryption.default = ${ENCRYPTION} |
  .bridge.permissions = {\"*\": \"relay\", \"${HOMESERVER_DOMAIN}\": \"user\"}
" "${CONFIG_PATH}"

# ── Appservice-Registrierung (nur beim allerersten Start, danach stabil) ──
# WICHTIG: registration.yaml enthält as_token/hs_token — wird NICHT neu
# generiert, sobald sie einmal existiert (sonst verliert Synapse die
# Appservice-Kopplung bei jedem Neustart).
if [ ! -f "${REG_PATH}" ]; then
    bashio::log.info "Erste Registrierung — generiere registration.yaml..."
    if ! mautrix-whatsapp -c "${CONFIG_PATH}" -r "${REG_PATH}" -g || [ ! -f "${REG_PATH}" ]; then
        bashio::log.error "registration.yaml konnte nicht erzeugt werden (Config prüfen, siehe Ausgabe oben)."
        exit 1
    fi
    cp "${REG_PATH}" "${SHARE_REG_PATH}"
    bashio::log.warning "registration.yaml nach ${SHARE_REG_PATH} kopiert!"
    bashio::log.warning "→ Im Matrix-Synapse-Add-on 'whatsapp_bridge_enabled' aktivieren und Synapse neu starten."
else
    # Falls /share leer ist (z.B. nach Restore, wo /data erhalten blieb,
    # /share aber nicht Teil des Backups war) erneut hinkopieren.
    if [ ! -f "${SHARE_REG_PATH}" ]; then
        cp "${REG_PATH}" "${SHARE_REG_PATH}"
        bashio::log.info "registration.yaml erneut nach /share kopiert (war dort nicht vorhanden)."
    fi
fi

bashio::log.info "Init abgeschlossen."
