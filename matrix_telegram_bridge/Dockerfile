# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add build.yaml here.
#
# NOTE: mautrix-telegram was rewritten from Python (Telethon) to Go
# (bridgev2 framework, gotd library) in April 2026. From v0.2604.0 the
# old Python codebase is fully replaced. According to go.mod, Go 1.26+ is required
# (since v0.2609.0) - hence a newer Go builder here than for
# WhatsApp/Signal (which get by with 1.23/1).
ARG TELEGRAM_VERSION=v0.2610.0
ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.7

# ---- Builder Stage (Go source build, SHA/Tag-pinned) ----
FROM golang:1.26-alpine3.24 AS builder

ARG TELEGRAM_VERSION
ARG TARGETARCH

RUN apk add --no-cache git build-base olm-dev

WORKDIR /build
RUN git clone --depth 1 --branch "${TELEGRAM_VERSION}" \
      https://github.com/mautrix/telegram.git . \
    && git rev-parse HEAD > /build/COMMIT_SHA

RUN CGO_ENABLED=1 GOOS=linux GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w" -o mautrix-telegram ./cmd/mautrix-telegram

# ---- Runtime Stage (HA base image, multi-arch) ----
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG TELEGRAM_VERSION

LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="app" \
  io.hass.name="matrix_telegram_bridge" \
  io.hass.arch="${BUILD_ARCH}" \
  org.opencontainers.image.title="Telegram Bridge (mautrix) HA Add-on" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:21.0.7" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.description="mautrix-telegram ${TELEGRAM_VERSION} as an application service bridge for Matrix Synapse"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# ffmpeg: sticker/video conversion. LottieConverter (for animated stickers)
# deliberately NOT installed - saves resources (§12), optional feature.
RUN apk add --no-cache ffmpeg olm ca-certificates yq

COPY --from=builder /build/mautrix-telegram /usr/bin/mautrix-telegram
COPY --from=builder /build/pkg/connector/example-config.yaml /opt/mautrix-telegram/example-config.yaml
COPY --from=builder /build/COMMIT_SHA /opt/mautrix-telegram/COMMIT_SHA

COPY rootfs /

RUN chmod a+x /usr/bin/mautrix-telegram \
    && chmod a+x /etc/cont-init.d/10-telegram-bridge-init.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/telegram_bridge/run \
    && chmod a+x /etc/s6-overlay/s6-rc.d/telegram_bridge/finish

WORKDIR /data
