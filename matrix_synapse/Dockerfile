ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.7.1
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
    io.hass.name="Matrix Server (ESS CE)" \
    io.hass.description="Matrix Homeserver (Synapse) + Element Web + Element Call (Voice/Video) — ESS Community Edition Style" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="app" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.title="Matrix Server (ESS CE)" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# ── System Pakete + Synapse via pip ─────────────────────────────────────────
# Ein RUN, damit Compiler, -dev-Pakete und pip-Cache nach dem Build wieder aus
# dem Image verschwinden (in einer späteren Schicht gelöscht, blieben sie im
# Image und belegten weiter Speicher). Die Laufzeit-Bibliotheken werden vor
# dem Aufräumen als "manuell" markiert, damit autoremove sie nicht mitnimmt.
# Am Ende prüft Synapse seine eigenen Abhängigkeiten (Kern, postgres,
# url-preview); psycopg2 wird importiert, weil es gegen libpq5 gelinkt ist.
# libjemalloc2: Allocator für Synapse (siehe synapse/run), von der Synapse-Doku
# empfohlen; mit glibc-malloc fragmentiert Python stark und der RAM wächst.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    libffi8 libssl3 libjpeg62-turbo libwebp7 libwebpmux3 libwebpdemux2 \
    libxml2 libxslt1.1 libpq5 \
    libjemalloc2 \
    postgresql-15 postgresql-client-15 \
    curl wget ca-certificates jq gettext-base \
    gosu \
    python3-dev libffi-dev libssl-dev libjpeg-dev libwebp-dev \
    libxml2-dev libxslt1-dev libpq-dev gcc g++ make \
    && python3 -m venv /opt/synapse \
    && /opt/synapse/bin/pip install --no-cache-dir --upgrade pip wheel \
    && /opt/synapse/bin/pip install --no-cache-dir \
        "matrix-synapse[all]>=1.163.0" \
        "psycopg2-binary" \
        "pyOpenSSL>=24.0.0" \
    && apt-get purge -y python3-dev libffi-dev libssl-dev libjpeg-dev libwebp-dev \
        libxml2-dev libxslt1-dev libpq-dev gcc g++ make \
    && apt-get autoremove -y --purge \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(find /usr/lib -name libjemalloc.so.2 | head -n 1)" /usr/local/lib/libjemalloc.so.2 \
    && test -e /usr/local/lib/libjemalloc.so.2 \
    && /opt/synapse/bin/python -c "import psycopg2, PIL, synapse; from synapse.util.check_dependencies import check_requirements as c; c(); c('postgres'); c('url-preview'); print('synapse', synapse.__version__, 'dependencies OK')"

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
    chmod +x /etc/s6-overlay/s6-rc.d/postgres-backup/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/element-web/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/livekit/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/livekit-jwt/finish && \
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
