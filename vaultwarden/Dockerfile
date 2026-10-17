# Upstream-Version separat, damit der Update-Workflow (07-update-upstream-candidate) sie erkennt
ARG VAULTWARDEN_VERSION=1.37.4
ARG BUILD_ARCH
# Offizielles Multi-Arch-Manifest (aarch64 + amd64), daher kein ${BUILD_ARCH} im Tag nötig (§16)
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.8

FROM ghcr.io/dani-garcia/vaultwarden:${VAULTWARDEN_VERSION}-alpine AS vaultwarden

FROM ${BUILD_FROM}

# BUILD_ARCH und BUILD_VERSION kommen aus build-app.yaml (Version = version aus config.yaml)
ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
  io.hass.name="Vaultwarden" \
  io.hass.description="Bitwarden-kompatibler Passwortmanager-Server" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.title="Vaultwarden" \
  org.opencontainers.image.description="Vaultwarden als Home-Assistant-App" \
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

# Smoke-Check: Binary läuft auf dem Basis-Image (statisch gelinkt / Libs vorhanden)
RUN chmod a+x \
      /etc/s6-overlay/s6-rc.d/vaultwarden/run \
      /etc/s6-overlay/s6-rc.d/vaultwarden/finish \
    && /usr/local/bin/vaultwarden --version
