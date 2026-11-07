# Upstream versions are kept as separate ARGs so the update workflow (07-update-upstream-candidate) can detect them.
# NETBOX_DOCKER_VERSION is the release of netbox-community/netbox-docker that builds the image (tag: v<netbox>-<docker>).
ARG NETBOX_VERSION=4.7.4
ARG NETBOX_DOCKER_VERSION=5.1.1
ARG BUILD_ARCH
# Official multi-arch manifest (aarch64 + amd64), so no ${BUILD_ARCH} is needed in the tag (§16.1).
# It must be the same Ubuntu release as the NetBox image: the Python venv is copied over and links to /usr/bin/python3.
ARG BUILD_FROM=ghcr.io/home-assistant/base-ubuntu:26.04
ARG NETBOX_IMAGE=ghcr.io/netbox-community/netbox:v${NETBOX_VERSION}-${NETBOX_DOCKER_VERSION}

FROM ${NETBOX_IMAGE} AS netbox

FROM ${BUILD_FROM}

# BUILD_ARCH and BUILD_VERSION come from build-app.yaml (version = version from config.yaml)
ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
  io.hass.name="NetBox" \
  io.hass.description="NetBox IPAM and DCIM with built-in PostgreSQL and Valkey" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.title="NetBox" \
  org.opencontainers.image.description="NetBox as a Home Assistant app" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.licenses="Apache-2.0"

# The "netbox" user is created first with the same uid/gid as in the upstream image (999:0), so the
# system users that the postgresql and valkey packages create cannot take uid 999.
# create_main_cluster=false: the package must not create a default cluster, the data directory is
# created in /data at the first start. policy-rc.d keeps the package scripts from starting daemons.
# The runtime libraries are the ones the upstream image installs (netbox-docker, Dockerfile, stage "main").
RUN useradd --system --uid 999 --gid 0 --home-dir /opt/netbox --no-create-home --shell /usr/sbin/nologin netbox \
    && mkdir -p /etc/postgresql-common \
    && echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.conf \
    && printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 755 /usr/sbin/policy-rc.d \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update -qq \
    && apt-get install --yes -qq --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        gosu \
        libldap-common \
        libpq5 \
        libxmlsec1-openssl1 \
        openssh-client \
        openssl \
        postgresql \
        python3 \
        tzdata \
        valkey-server \
    && rm -f /usr/sbin/policy-rc.d \
    && rm -rf /var/lib/apt/lists/*

# NetBox as built by netbox-docker: venv, source, collected static files, uv (for plugins) and the
# configuration loader (/etc/netbox/config/*.py).
COPY --from=netbox /opt/netbox /opt/netbox
COPY --from=netbox /etc/netbox /etc/netbox
COPY --from=netbox /usr/local/bin/uv /usr/local/bin/uv

COPY rootfs /

# The bundled documentation (served under /static/docs/) loads fonts from Google Fonts. Remove those
# links so no page of the app contacts a third party (§9); the docs then use the system fonts.
# The last grep fails the build if one is left (e.g. after an upstream change).
RUN find /opt/netbox/netbox/static/docs -name '*.html' -exec sed -i \
        -e '/fonts\.googleapis\.com/d' -e '/fonts\.gstatic\.com/d' {} + \
    && ! grep -rIq -e 'fonts\.googleapis\.com' -e 'fonts\.gstatic\.com' /opt/netbox/netbox/static/docs

# Smoke test: the copied venv runs on this base image and the daemons are installed.
RUN /opt/netbox/venv/bin/python -c "import django, granian, psycopg, redis; print('django', django.get_version())" \
    && /opt/netbox/venv/bin/granian --version \
    && valkey-server --version \
    && ( set -- /usr/lib/postgresql/*/bin/postgres && "$1" --version )

RUN chmod a+x \
      /etc/cont-init.d/10-netbox-init.sh \
      /etc/s6-overlay/s6-rc.d/postgresql/run \
      /etc/s6-overlay/s6-rc.d/postgresql/finish \
      /etc/s6-overlay/s6-rc.d/valkey/run \
      /etc/s6-overlay/s6-rc.d/valkey/finish \
      /etc/s6-overlay/s6-rc.d/netbox/run \
      /etc/s6-overlay/s6-rc.d/netbox/finish

ENV UV_NO_CACHE=1 LANG=C.utf8

# Health check from inside the container. It asks for "localhost", which NetBox always accepts as a host
# name (the upstream configuration adds it to ALLOWED_HOSTS), even when allowed_hosts is narrowed down.
# While the database is migrated (run script of the netbox service) the marker file keeps the app "healthy".
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD [ "/bin/sh", "-c", "curl --ipv4 -fsS -o /dev/null http://localhost:8001/login/ || test -e /tmp/netbox-migrating" ]
