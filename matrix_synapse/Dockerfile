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

# ── System packages + Synapse via pip ─────────────────────────────────────────
# A single RUN, so the compiler, -dev packages and the pip cache disappear from
# the image again after the build (if deleted in a later layer, they would stay
# in the image and keep taking up space). The runtime libraries are marked as
# "manual" before the cleanup so autoremove does not take them along.
# At the end Synapse checks its own dependencies (core, postgres,
# url-preview); psycopg2 is imported because it is linked against libpq5.
# libjemalloc2: allocator for Synapse (see synapse/run), recommended by the
# Synapse docs; with glibc malloc Python fragments heavily and RAM keeps growing.
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

# LiveKit + lk-jwt-service are downloaded at RUNTIME (not during the build)
# Reason: GitHub is blocked in the HA build network
# → 03-download-binaries.sh in cont-init.d does this on the first start

# ── Prepare directories ────────────────────────────────────────────────
RUN mkdir -p /opt/element-web /opt/synapse-admin /opt/element-call \
             /var/lib/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql

# ── Copy the s6 overlay configs ─────────────────────────────────────────────
COPY rootfs/ /

# ── Permissions ──────────────────────────────────────────────────────────
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
# Note: the livekit-server + lk-jwt-service binaries are downloaded to
# /data/matrix/bin/ by 03-download-binaries.sh on the first start

# ── Ports ───────────────────────────────────────────────────────────────────
# 7080 = Element Web  |  7081 = Element Call  |  7880 = LiveKit API
# 8008 = Synapse API  |  8448 = Federation    |  8090 = Synapse Admin
EXPOSE 7080 7081 7880 8448 8090

# ── Healthcheck ─────────────────────────────────────────────────────────────
# Checks Synapse's own /health endpoint instead of just trusting
# "process is running". start-period=90s, because on the first start Postgres
# init + signing key generation + possibly web app downloads run before
# Synapse even comes up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -sf http://127.0.0.1:8008/health || exit 1
