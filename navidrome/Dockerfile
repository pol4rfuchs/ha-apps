# Navidrome Home Assistant Add-on
# Basis: offizielles deluan/navidrome Image (Alpine)
# Ergänzt: bash, jq, bashio für HA-Supervisor-Integration

ARG BUILD_VERSION

FROM deluan/navidrome:0.62.0
ARG BUILD_VERSION

LABEL \
  io.hass.name="Navidrome" \
  io.hass.description="Modern Music Server and Streamer compatible with Subsonic/Airsonic" \
  io.hass.type="addon" \
  io.hass.version="${BUILD_VERSION}" \
  maintainer="Pol4rFuchs (https://github.com/pol4rfuchs)"

# DL3002: root required — HA add-on runs as root, Navidrome drops privileges internally
# hadolint ignore=DL3002
USER root

# curl TLS-Quirk in Alpine vermeiden
RUN echo insecure >> ~/.curlrc

RUN apk add --no-cache \
  bash \
  curl \
  ca-certificates \
  jq \
  nginx \
  shadow \
  procps \
  && mkdir -p /etc/cont-init.d \
  && chmod -R 755 /etc/cont-init.d

ENV BASHIO_VERSION="0.16.2"

# DL4006: pipe replaced with explicit download + extract to avoid pipefail requirement
RUN mkdir -p /tmp/bashio \
  && curl -fsSL "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
       -o /tmp/bashio.tgz \
  && tar -xzf /tmp/bashio.tgz --strip 1 -C /tmp/bashio \
  && mv /tmp/bashio/lib /usr/lib/bashio \
  && ln -sf /usr/lib/bashio/bashio /usr/bin/bashio \
  && rm -rf /tmp/bashio /tmp/bashio.tgz

COPY rootfs/ /

RUN chmod -R 755 /etc/cont-init.d \
  && chmod +x /usr/bin/navidrome-run.sh

COPY scripts/ha_entrypoint.sh /ha_entrypoint.sh
RUN chmod 0755 /ha_entrypoint.sh
ENTRYPOINT ["/bin/bash", "/ha_entrypoint.sh"]

HEALTHCHECK \
  --interval=15s \
  --retries=5 \
  --start-period=30s \
  --timeout=10s \
  CMD wget -q --spider --proxy off "http://localhost:4533/ping" || exit 1

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
LABEL \
  io.hass.arch="${BUILD_ARCH}" \
  org.opencontainers.image.title="${BUILD_NAME}" \
  org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
  org.opencontainers.image.vendor="Home Assistant Add-ons" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.revision="${BUILD_REF}" \
  org.opencontainers.image.version="${BUILD_VERSION}"
