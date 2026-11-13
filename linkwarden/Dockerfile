# Upstream version is kept as its own ARG so the update workflow (07-update-upstream-candidate) can detect it.
ARG LINKWARDEN_VERSION=2.17.0
ARG BUILD_ARCH
# Official multi-arch manifest (aarch64 + amd64), so no ${BUILD_ARCH} is needed in the tag (§16.1).
# It must be the same Debian release as the upstream image (bookworm, glibc 2.36): the Node.js and monolith
# binaries are copied over and have to run here (§4, upstream binary check).
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:bookworm
ARG LINKWARDEN_IMAGE=ghcr.io/linkwarden/linkwarden:v${LINKWARDEN_VERSION}

FROM ${LINKWARDEN_IMAGE} AS linkwarden

FROM ${BUILD_FROM}

# BUILD_ARCH and BUILD_VERSION come from build-app.yaml (version = version from config.yaml)
ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
  io.hass.name="Linkwarden" \
  io.hass.description="Linkwarden bookmark manager with built-in PostgreSQL" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.title="Linkwarden" \
  org.opencontainers.image.description="Linkwarden as a Home Assistant app" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.licenses="AGPL-3.0"

# Node.js, monolith, the Playwright browser and the application come from the upstream image.
# The application is moved from /data to /opt/linkwarden: /data is the persistent volume of the Supervisor
# and would hide everything that the image keeps there.
COPY --from=linkwarden /usr/local/bin/node /usr/local/bin/node
COPY --from=linkwarden /usr/local/bin/monolith /usr/local/bin/monolith
COPY --from=linkwarden /ms-playwright /ms-playwright
COPY --from=linkwarden /data /opt/linkwarden

# The "linkwarden" user runs the web and worker processes (privilege drop with gosu).
# create_main_cluster=false: the package must not create a default cluster, the data directory is created in
# /data at the first start. policy-rc.d keeps the package scripts from starting daemons.
RUN groupadd --system --gid 1001 linkwarden \
    && useradd --system --uid 1001 --gid 1001 --home-dir /opt/linkwarden --no-create-home \
        --shell /usr/sbin/nologin linkwarden \
    && mkdir -p /etc/postgresql-common \
    && echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.conf \
    && printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 755 /usr/sbin/policy-rc.d \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update -qq \
    && apt-get install --yes -qq --no-install-recommends \
        ca-certificates \
        curl \
        gosu \
        jq \
        openssl \
        postgresql \
    && node /opt/linkwarden/node_modules/playwright-core/cli.js install-deps chromium-headless-shell \
    && rm -f /usr/sbin/policy-rc.d \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /

# Only the Next.js cache needs to be writable for the unprivileged user (upstream makes it world-writable).
RUN chown -R linkwarden:linkwarden /opt/linkwarden/apps/web/.next/cache \
    && chmod 755 /opt/linkwarden/apps/web/.next/cache \
    && chmod a+x \
      /etc/cont-init.d/10-linkwarden-init.sh \
      /etc/s6-overlay/s6-rc.d/postgresql/run \
      /etc/s6-overlay/s6-rc.d/postgresql/finish \
      /etc/s6-overlay/s6-rc.d/web/run \
      /etc/s6-overlay/s6-rc.d/web/finish \
      /etc/s6-overlay/s6-rc.d/worker/run \
      /etc/s6-overlay/s6-rc.d/worker/finish

# Smoke test: the copied binaries run on this base image, the application tools are in place, PostgreSQL is
# installed and the browser starts (all shared libraries are present).
RUN node --version \
    && monolith --version \
    && /opt/linkwarden/node_modules/.bin/tsx --version \
    && /opt/linkwarden/node_modules/.bin/next --version \
    && /opt/linkwarden/node_modules/.bin/prisma --version \
    && ( set -- /usr/lib/postgresql/*/bin/postgres && "$1" --version ) \
    && ( set -- /ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux*/chrome-headless-shell && "$1" --version )

ENV LANG=C.utf8

# Health check from inside the container. The web service only starts after the database migrations, so the long
# start period covers a first start.
HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
  CMD [ "/bin/sh", "-c", "curl --ipv4 -fsS -o /dev/null http://localhost:3200/" ]
