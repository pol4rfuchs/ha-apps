# CortenDesk als Home-Assistant-App: duenner Wrapper um das Upstream-Image.
# Upstream: github.com/marcpope/cortendesk (AGPL-3.0-only)
#
# BUILD_FROM zeigt auf ein echtes Multi-Arch-Manifest (linux/amd64 + linux/arm64,
# geprueft am 17.10.2026), daher kein ${BUILD_ARCH} im Namen noetig.
# Index-Digest von 1.14.0 am 17.10.2026 (Upstream-Tags sind nicht unveraenderlich):
#   sha256:3305ea4bca8814e71f6c0dcf49df449cf44f82be4023a0c98e15fdc2ef919545
# Die Upstream-Version steht als eigenes ARG, damit 07-update-upstream-candidate sie patchen kann.

ARG BUILD_ARCH
ARG CORTENDESK_VERSION=1.14.0
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

# Basis ist php:8.4-fpm-alpine (kein bash, kein bashio): jq liest /data/options.json.
RUN apk add --no-cache jq

# Wrapper-Entrypoint: options.json -> ENV, dann Upstream-/entrypoint.sh.
COPY run.sh /run.sh
RUN chmod 755 /run.sh

ENTRYPOINT [ "/run.sh" ]
