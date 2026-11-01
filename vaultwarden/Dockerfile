# Upstream version kept separate so the update workflow (07-update-upstream-candidate) can detect it
ARG VAULTWARDEN_VERSION=1.37.4
ARG BUILD_ARCH
# Official multi-arch manifest (aarch64 + amd64), so no ${BUILD_ARCH} is needed in the tag (§16)
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.8

FROM ghcr.io/dani-garcia/vaultwarden:${VAULTWARDEN_VERSION}-alpine AS vaultwarden

FROM ${BUILD_FROM}

# BUILD_ARCH and BUILD_VERSION come from build-app.yaml (version = version from config.yaml)
ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
  io.hass.name="Vaultwarden" \
  io.hass.description="Bitwarden-compatible password manager server" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.title="Vaultwarden" \
  org.opencontainers.image.description="Vaultwarden as a Home Assistant app" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.licenses="AGPL-3.0-only"

RUN apk add --no-cache ca-certificates \
    && addgroup -S vaultwarden \
    && adduser -S -D -H -G vaultwarden -s /sbin/nologin vaultwarden

COPY --from=vaultwarden /vaultwarden /usr/local/bin/vaultwarden
COPY --from=vaultwarden /web-vault /opt/vaultwarden/web-vault

ENV WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault

COPY rootfs /

# Smoke check: the binary runs on the base image (statically linked / libs present)
RUN chmod a+x \
      /etc/s6-overlay/s6-rc.d/vaultwarden/run \
      /etc/s6-overlay/s6-rc.d/vaultwarden/finish \
    && /usr/local/bin/vaultwarden --version
