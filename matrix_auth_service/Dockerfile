# ARGs used in a FROM instruction must be declared before the *first* FROM
# in the whole file, or buildx silently fails to resolve them later
# (moby/moby#38379).
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.7.1
ARG MAS_VERSION=1.23.0

# ---------------------------------------------------------------------------
# Stage 1: pull the official MAS binary + static assets.
#
# MAS is a Rust binary — element-hq publishes a ready-built multi-arch image
# on GHCR. Same rationale as picking prebuilt binaries over Rust-from-source:
# no toolchain, no build time, and the binary is already checksummed/signed
# by upstream's own release pipeline. We only extract binary + share/ assets,
# nothing else from their image ends up in ours.
# ---------------------------------------------------------------------------
FROM ghcr.io/element-hq/matrix-authentication-service:${MAS_VERSION} AS mas-src

# ---------------------------------------------------------------------------
# Stage 2: runtime — same hassio debian-base as the Synapse add-on, so
# Postgres client tooling / bashio / gosu behave identically across both.
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG MAS_VERSION

LABEL \
    io.hass.name="Matrix Auth Service (MAS)" \
    io.hass.description="Matrix Authentication Service — next-gen OIDC-Auth für Matrix Synapse" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.title="Matrix Auth Service (MAS)" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# ── System Pakete ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-15 postgresql-client-15 \
    curl ca-certificates jq gosu \
    && rm -rf /var/lib/apt/lists/*

# ── MAS Binary + Assets aus Stage 1 ─────────────────────────────────────────
COPY --from=mas-src /usr/local/bin/mas-cli /usr/local/bin/mas-cli
COPY --from=mas-src /usr/local/share/mas-cli /usr/local/share/mas-cli

RUN mkdir -p /var/lib/postgresql && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chmod +x /usr/local/bin/mas-cli

# ── S6-Overlay Configs kopieren ─────────────────────────────────────────────
COPY rootfs/ /

RUN chmod +x /etc/cont-init.d/*.sh && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgresql/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgresql/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/mas/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/mas/finish && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgres-backup/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/postgres-backup/finish

EXPOSE 8082 8083

# ── Healthcheck ─────────────────────────────────────────────────────────────
# MAS' eigener Health-Endpoint läuft auf dem internen Port 8083.
# start-period=60s: Postgres-Init + DB-Migration + Config-Sync brauchen beim
# ersten Start etwas, bevor mas-cli server überhaupt lauscht.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -sf http://127.0.0.1:8083/health || exit 1
