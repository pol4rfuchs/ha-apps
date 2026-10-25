ARG BUILD_ARCH
ARG SEARXNG_VERSION=2026.10.24-ef0ec03da
FROM searxng/searxng:${SEARXNG_VERSION}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG SEARXNG_VERSION

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
