FROM searxng/searxng:latest

ARG BUILD_VERSION

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT ["/run.sh"]

LABEL \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}"
