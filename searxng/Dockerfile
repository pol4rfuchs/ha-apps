ARG BUILD_ARCH
ARG SEARXNG_VERSION=2026.10.30-ffa88e3ba

# Tor is not in the SearXNG image (it is a stripped Void Linux without a package manager), so take
# it from a Void Linux image together with the shared libraries it needs. The final stage runs
# `tor --version`, so the build fails if the libraries do not fit the SearXNG image.
# hadolint ignore=DL3007
FROM ghcr.io/void-linux/void-glibc:latest AS tor-build
# hadolint ignore=DL4006
RUN xbps-install -Sy xbps \
    && xbps-install -Syu \
    && xbps-install -y tor \
    && mkdir -p /out \
    && cp /usr/bin/tor /out/tor \
    && LD_TRACE_LOADED_OBJECTS=1 /usr/bin/tor \
        | awk '/=> \//{print $3}' \
        | grep -Ev '/(libc|libm|libdl|libpthread|librt|libresolv|libnss_[a-z]+|libutil|ld-linux[^/]*)\.so' \
        > /tmp/libs \
    && while read -r lib; do cp -L "$lib" /out/; done < /tmp/libs

FROM searxng/searxng:${SEARXNG_VERSION}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG SEARXNG_VERSION

# Tor (only started when the option `enable_tor` is on; needed by the ahmia and torch engines).
COPY --from=tor-build /out/ /usr/local/lib/tor/
RUN echo "_tor:x:978:978::/tmp/tor:/bin/false" >> /etc/passwd \
    && echo "_tor:x:978:" >> /etc/group \
    && LD_LIBRARY_PATH=/usr/local/lib/tor /usr/local/lib/tor/tor --version

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
