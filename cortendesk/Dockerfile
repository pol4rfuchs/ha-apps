# CortenDesk als Home-Assistant-App: duenner Wrapper um das Upstream-Image.
# Regeln: appbuildrules.md §0, §4, §16. Upstream: github.com/marcpope/cortendesk (AGPL-3.0-only)
#
# BUILD_FROM zeigt auf ein echtes Multi-Arch-Manifest (linux/amd64 + linux/arm64,
# per Registry-API geprueft am 01.10.2026), daher kein ${BUILD_ARCH} im Namen noetig (§4/§16).
# Index-Digest zur Kontrolle fuer 1.12.0:
#   sha256:01a00b37f2473c7342471be111ace55f4bc26f0d16476c703dac6493e86fe9e2
# Die Upstream-Version steht als eigenes ARG, damit 07-update-upstream-candidate sie patchen kann.

ARG BUILD_ARCH
ARG CORTENDESK_VERSION=1.12.0
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
