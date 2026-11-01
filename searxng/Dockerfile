ARG BUILD_ARCH
ARG SEARXNG_VERSION=2026.10.30-ffa88e3ba
FROM searxng/searxng:${SEARXNG_VERSION}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG SEARXNG_VERSION

# Tor is only started when the option `enable_tor` is on (needed by the ahmia and torch engines).
RUN ls -d /usr/bin/xbps-install /usr/bin/xbps-query 2>&1; xbps-install -Sy tor 2>&1 | tail -15; command -v tor; tor --version | head -2

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT ["/run.sh"]

LABEL \
    io.hass.name="SearXNG" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.base.name="searxng/searxng:${SEARXNG_VERSION}"
