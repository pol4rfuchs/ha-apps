# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add build.yaml here.
ARG WHATSAPP_VERSION=v0.2607.0
ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.0

# ---- Builder Stage (Go source build, SHA/Tag-pinned) ----
FROM golang:1-alpine3.24 AS builder

ARG WHATSAPP_VERSION
ARG TARGETARCH

RUN apk add --no-cache git build-base olm-dev

WORKDIR /build
RUN git clone --depth 1 --branch "${WHATSAPP_VERSION}" \
      https://github.com/mautrix/whatsapp.git . \
    && git rev-parse HEAD > /build/COMMIT_SHA

RUN CGO_ENABLED=1 GOOS=linux GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w" -o mautrix-whatsapp ./cmd/mautrix-whatsapp

# ---- Runtime Stage (HA base image, multi-arch) ----
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG WHATSAPP_VERSION

LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.name="matrix_whatsapp_bridge" \
  io.hass.arch="${BUILD_ARCH}" \
  org.opencontainers.image.title="WhatsApp Bridge (mautrix) HA Add-on" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:21.0.0" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.description="mautrix-whatsapp ${WHATSAPP_VERSION} als Application-Service Bridge für Matrix Synapse"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN apk add --no-cache olm ca-certificates yq

COPY --from=builder /build/mautrix-whatsapp /usr/bin/mautrix-whatsapp
COPY --from=builder /build/pkg/connector/example-config.yaml /opt/mautrix-whatsapp/example-config.yaml
COPY --from=builder /build/COMMIT_SHA /opt/mautrix-whatsapp/COMMIT_SHA

COPY rootfs /

RUN chmod a+x /usr/bin/mautrix-whatsapp \
    && chmod a+x /etc/cont-init.d/10-whatsapp-bridge-init.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/whatsapp_bridge/run \
    && chmod a+x /etc/s6-overlay/s6-rc.d/whatsapp_bridge/finish

WORKDIR /data
