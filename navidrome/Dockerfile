# Navidrome Home Assistant Add-on
# Basis: offizielles deluan/navidrome Image (Alpine)
# Ergänzt: bash, jq, bashio für HA-Supervisor-Integration

ARG BUILD_VERSION

FROM deluan/navidrome:0.60.3

LABEL \
  io.hass.name="Navidrome" \
  io.hass.description="Modern Music Server and Streamer compatible with Subsonic/Airsonic" \
  io.hass.type="addon" \
  io.hass.version="${BUILD_VERSION}" \
  maintainer="Pol4rFuchs (https://codeberg.org/Pol4rFuchs)"

USER root

# curl TLS-Quirk in Alpine vermeiden
RUN echo insecure >> ~/.curlrc

# --- Pakete ---
# bash, curl, ca-certificates : bashio-Voraussetzung
# jq                           : options.json parsen
# nginx                        : HA Ingress Reverse Proxy (sub_filter)
# shadow                       : usermod/groupmod für PUID/PGID
# procps                       : ps, kill (nützlich für Debugging)
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

# --- bashio ---
ENV BASHIO_VERSION="0.16.2"
RUN mkdir -p /tmp/bashio \
  && curl -fsSL "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
  | tar -xzf - --strip 1 -C /tmp/bashio \
  && mv /tmp/bashio/lib /usr/lib/bashio \
  && ln -sf /usr/lib/bashio/bashio /usr/bin/bashio \
  && rm -rf /tmp/bashio

# --- rootfs overlay ---
COPY rootfs/ /

RUN chmod -R 755 /etc/cont-init.d \
  && chmod +x /usr/bin/navidrome-run.sh

# --- Entrypoint ---
COPY scripts/ha_entrypoint.sh /ha_entrypoint.sh
RUN chmod 0755 /ha_entrypoint.sh
ENTRYPOINT ["/bin/bash", "/ha_entrypoint.sh"]

# --- Healthcheck ---
# Direkt gegen Navidrome Port 4533 — unabhängig von nginx
HEALTHCHECK \
  --interval=15s \
  --retries=5 \
  --start-period=30s \
  --timeout=10s \
  CMD wget -q --spider --proxy off "http://localhost:4533/ping" || exit 1

# --- Build Labels ---
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
  org.opencontainers.image.source="https://codeberg.org/Pol4rFuchs/ha-addons" \
  org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.revision="${BUILD_REF}" \
  org.opencontainers.image.version="${BUILD_VERSION}"
