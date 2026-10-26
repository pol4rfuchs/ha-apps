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

mkdir -p "${DATA_DIR}"

# ── DB-URI je nach gewähltem Backend zusammenbauen ────────────────────────
if [ "${DB_TYPE}" = "postgres" ]; then
    # Benutzer, Passwort und DB-Name URL-kodieren: Zeichen wie @ : / ? # % im
    # Passwort zerlegen sonst die URI (Host/DB falsch, Passwort abgeschnitten).
    PG_USER=$(jq -rn --arg v "$(bashio::config 'postgres_username')" '$v|@uri')
    PG_PASS=$(jq -rn --arg v "$(bashio::config 'postgres_password')" '$v|@uri')
    PG_DB=$(jq -rn --arg v "$(bashio::config 'postgres_database')" '$v|@uri')
    DB_URI="postgres://${PG_USER}:${PG_PASS}@$(bashio::config 'postgres_host'):$(bashio::config 'postgres_port')/${PG_DB}?sslmode=disable"
    DB_TYPE_VAL="postgres"
else
    DB_URI="file:${DATA_DIR}/mautrix-signal.db?_txlock=immediate"
    DB_TYPE_VAL="sqlite3-fk-wal"
fi

# ── config.yaml erzeugen (nur beim allerersten Start) ──────────────────────
# "-e" schreibt die vollständige Beispiel-Config (network, bridge, database,
# homeserver, appservice, encryption, ...). pkg/connector/example-config.yaml
# aus dem Quellbaum enthält nur den network-Teil und wird von der Bridge als
# Legacy-Config abgelehnt.
if [ ! -f "${CONFIG_PATH}" ]; then
    bashio::log.info "Erzeuge config.yaml (mautrix-signal -e)..."
    if ! mautrix-signal -c "${CONFIG_PATH}" -e; then
        bashio::log.error "mautrix-signal konnte keine Beispiel-Config erzeugen."
        exit 1
    fi
fi

bashio::log.info "Schreibe Options in config.yaml..."
# Werte per Umgebung + strenv() übergeben statt in den Ausdruck zu interpolieren:
# ein " oder \ in Passwort/Hash/Domain machte den yq-Ausdruck sonst ungültig und
# die Config blieb unbemerkt auf dem alten Stand.
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
    bashio::log.error "config.yaml konnte nicht aktualisiert werden (yq rc=${YQ_RC}), Abbruch."
    exit 1
fi

# ── Appservice-Registrierung (nur beim allerersten Start, danach stabil) ──
# WICHTIG: registration.yaml enthält as_token/hs_token — wird NICHT neu
# generiert, sobald sie einmal existiert (sonst verliert Synapse die
# Appservice-Kopplung bei jedem Neustart).
if [ ! -f "${REG_PATH}" ]; then
    bashio::log.info "Erste Registrierung — generiere registration.yaml..."
    if ! mautrix-signal -c "${CONFIG_PATH}" -r "${REG_PATH}" -g || [ ! -f "${REG_PATH}" ]; then
        bashio::log.error "registration.yaml konnte nicht erzeugt werden (Config prüfen, siehe Ausgabe oben)."
        exit 1
    fi
    if cp "${REG_PATH}" "${SHARE_REG_PATH}"; then
        bashio::log.warning "registration.yaml nach ${SHARE_REG_PATH} kopiert!"
        bashio::log.warning "→ Im Matrix-Synapse-Add-on 'signal_bridge_enabled' aktivieren und Synapse neu starten."
    else
        bashio::log.error "registration.yaml konnte NICHT nach ${SHARE_REG_PATH} kopiert werden (siehe cp-Fehler oben)."
        bashio::log.error "→ Synapse findet die Bridge so nicht. Ist /share eingebunden und beschreibbar? Beim nächsten Start wird erneut kopiert."
    fi
else
    # Falls /share leer ist (z.B. nach Restore, wo /data erhalten blieb,
    # /share aber nicht Teil des Backups war) erneut hinkopieren.
    if [ ! -f "${SHARE_REG_PATH}" ]; then
        if cp "${REG_PATH}" "${SHARE_REG_PATH}"; then
            bashio::log.info "registration.yaml erneut nach /share kopiert (war dort nicht vorhanden)."
        else
            bashio::log.error "registration.yaml konnte NICHT nach ${SHARE_REG_PATH} kopiert werden (siehe cp-Fehler oben). Ist /share eingebunden und beschreibbar?"
        fi
    fi
fi

bashio::log.info "Init abgeschlossen."
