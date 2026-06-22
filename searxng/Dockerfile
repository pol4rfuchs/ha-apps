ARG SEARXNG_VERSION=2026.6.22-aeced6724
FROM searxng/searxng:2026.6.22-aeced6724

ARG BUILD_VERSION
ARG SEARXNG_VERSION=2026.6.22-aeced6724

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT ["/run.sh"]

LABEL \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.base.name="searxng/searxng:${SEARXNG_VERSION}"
