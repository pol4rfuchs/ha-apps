ARG BUILD_ARCH
ARG SEARXNG_VERSION=2026.10.30-ffa88e3ba
FROM searxng/searxng:${SEARXNG_VERSION}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG SEARXNG_VERSION

# Tor is only started when the option `enable_tor` is on (needed by the ahmia and torch engines).
RUN (cat /etc/os-release; id; uname -m; echo LIBC; ls /lib/ld-musl* /lib64/ld-linux* /lib/ld-linux* /lib/*-linux-gnu/ld-linux* 2>&1; echo PM; ls -d /sbin/apk /usr/bin/apk /usr/bin/apt /usr/bin/dpkg /usr/bin/microdnf /usr/bin/dnf /usr/bin/tdnf /usr/local/bin/uv /usr/bin/uv 2>&1; echo PY; ls /usr/local/searxng/.venv/bin | head -5; ls -l /usr/local/searxng/.venv/bin/python3; echo LAYOUT; ls /; ls /var/lib | head; echo PROBE) 2>&1 | head -60; false

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
