# CortenDesk as a Home Assistant app: thin wrapper around the upstream image.
# Upstream: github.com/marcpope/cortendesk (AGPL-3.0-only)
#
# BUILD_FROM points to a real multi-arch manifest (linux/amd64 + linux/arm64,
# checked on 2026-10-17), so no ${BUILD_ARCH} is needed in the name.
# Index digest of 1.14.0 on 2026-10-17 (upstream tags are not immutable):
#   sha256:3305ea4bca8814e71f6c0dcf49df449cf44f82be4023a0c98e15fdc2ef919545
# The upstream version is its own ARG so that 07-update-upstream-candidate can patch it.

ARG BUILD_ARCH
ARG CORTENDESK_VERSION=1.15.0
ARG BUILD_FROM=ghcr.io/marcpope/cortendesk:${CORTENDESK_VERSION}
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG CORTENDESK_VERSION

LABEL \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.licenses="AGPL-3.0-only" \
  org.opencontainers.image.base.name="ghcr.io/marcpope/cortendesk:${CORTENDESK_VERSION}"

# The base is php:8.4-fpm-alpine (no bash, no bashio): jq reads /data/options.json.
RUN apk add --no-cache jq

# Wrapper entrypoint: options.json -> ENV, then the upstream /entrypoint.sh.
COPY run.sh /run.sh
RUN chmod 755 /run.sh

ENTRYPOINT [ "/run.sh" ]
