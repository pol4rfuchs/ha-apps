# Ketesa version kept as its own ARG so Renovate can bump it
ARG KETESA_VERSION=v1.5.1
ARG BUILD_ARCH
# Multi-arch manifest (aarch64 + amd64), so no ${BUILD_ARCH} is needed in the tag (§16)
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.8

FROM ${BUILD_FROM}

# BUILD_ARCH and BUILD_VERSION come from build-app.yaml (version = version from config.yaml)
ARG BUILD_ARCH
ARG BUILD_VERSION
ARG KETESA_VERSION

LABEL \
  io.hass.name="Matrix Ketesa (Admin UI)" \
  io.hass.description="Ketesa (formerly Synapse Admin), the admin web UI for Matrix Synapse, behind a login" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.title="Matrix Ketesa (Admin UI)" \
  org.opencontainers.image.description="Ketesa ${KETESA_VERSION} as a Home Assistant app" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.version="${BUILD_VERSION}"

RUN apk add --no-cache ca-certificates python3 \
    && addgroup -S ketesa \
    && adduser -S -D -H -G ketesa -s /sbin/nologin ketesa

# Ketesa is a static single-page app: fetch the pinned release at build time, so the
# running app needs no internet access. The tarball is taken over TLS from the pinned
# tag; no upstream checksum is verified (open point, see DOCS.md).
RUN mkdir -p /opt/ketesa /tmp/ketesa \
    && wget -q -O /tmp/ketesa.tar.gz "https://github.com/etkecc/ketesa/releases/download/${KETESA_VERSION}/ketesa.tar.gz" \
    && tar -xzf /tmp/ketesa.tar.gz -C /tmp/ketesa \
    && src=/tmp/ketesa \
    && if [ ! -f "${src}/index.html" ]; then src="$(find /tmp/ketesa -maxdepth 2 -name index.html -exec dirname {} \;)"; fi \
    && test -n "${src}" \
    && cp -r "${src}/." /opt/ketesa/ \
    && rm -rf /tmp/ketesa /tmp/ketesa.tar.gz

COPY rootfs /

# Smoke check: the UI is in place and the server script runs on the base image
RUN chmod a+x \
      /etc/s6-overlay/s6-rc.d/ketesa/run \
      /etc/s6-overlay/s6-rc.d/ketesa/finish \
      /usr/local/bin/ketesa-auth-server.py \
    && test -f /opt/ketesa/index.html \
    && python3 -m py_compile /usr/local/bin/ketesa-auth-server.py
