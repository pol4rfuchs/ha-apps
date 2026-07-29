ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.7.1
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
    io.hass.name="Matrix Server (ESS CE)" \
    io.hass.description="Matrix Homeserver (Synapse) + Element Web + Element Call (Voice/Video) — ESS Community Edition Style" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.title="Matrix Server (ESS CE)" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# ── System Pakete ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    libffi-dev libssl-dev libjpeg-dev libwebp-dev \
    libxml2-dev libxslt1-dev libpq-dev \
    postgresql-15 postgresql-client-15 \
    curl wget ca-certificates jq gettext-base \
    gosu \
    gcc g++ make \
    && rm -rf /var/lib/apt/lists/*

# ── Synapse via pip ─────────────────────────────────────────────────────────
RUN python3 -m venv /opt/synapse && \
    /opt/synapse/bin/pip install --upgrade pip wheel && \
    /opt/synapse/bin/pip install \
        "matrix-synapse[all]>=1.157.2" \
        "psycopg2-binary" \
        "pyOpenSSL>=24.0.0"

# LiveKit + lk-jwt-service werden zur LAUFZEIT geladen (nicht im Build)
# Grund: GitHub ist im HA Build-Netzwerk geblockt
# → 03-download-binaries.sh in cont-init.d erledigt das beim ersten Start

# ── Verzeichnisse vorbereiten ────────────────────────────────────────────────
RUN mkdir -p /opt/element-web /opt/synapse-admin /opt/element-call \
             /var/lib/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql

# ── S6-Overlay Configs kopieren ─────────────────────────────────────────────
COPY rootfs/ /

# ── Berechtigungen ──────────────────────────────────────────────────────────
RUN chmod +x /etc/cont-init.d/*.sh && \
    chmod +x /usr/local/bin/*.sh && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgresql/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/synapse/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgresql/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/synapse/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/livekit/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/livekit-jwt/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/element-call/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/synapse-admin/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgres-backup/run && \
    chmod +x /usr/local/bin/admin-ui-auth-server.py
# Hinweis: livekit-server + lk-jwt-service Binaries werden beim ersten Start
# durch 03-download-binaries.sh nach /data/matrix/bin/ geladen

# ── Ports ───────────────────────────────────────────────────────────────────
# 7080 = Element Web  |  7081 = Element Call  |  7880 = LiveKit API
# 8008 = Synapse API  |  8448 = Federation    |  8090 = Synapse Admin
EXPOSE 7080 7081 7880 8448 8090

# ── Healthcheck ─────────────────────────────────────────────────────────────
# Prüft Synapses eigenen /health-Endpoint statt nur "Prozess läuft" zu
# vertrauen. start-period=90s, weil beim ersten Start Postgres-Init +
# Signing-Key-Generierung + ggf. Webapp-Downloads laufen, bevor Synapse
# überhaupt hochkommt.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -sf http://127.0.0.1:8008/health || exit 1
