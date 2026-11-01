ARG BUILD_ARCH
ARG SEARXNG_VERSION=2026.10.30-ffa88e3ba
FROM searxng/searxng:${SEARXNG_VERSION}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG SEARXNG_VERSION

# Tor is only started when the option `enable_tor` is on (needed by the ahmia and torch engines).
RUN cat /etc/os-release; id; uname -m; ls -d /sbin/apk /usr/bin/apk /usr/bin/apt /usr/bin/apt-get /usr/bin/dpkg /usr/bin/microdnf /usr/bin/dnf /usr/bin/tdnf /usr/bin/pip /usr/bin/uv /usr/local/bin/uv 2>&1; ls /usr/bin | head -80; ls /lib/apk /var/lib/dpkg /var/lib/apk 2>&1 | head; echo PROBE; false

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
