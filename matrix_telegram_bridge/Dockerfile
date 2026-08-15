# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add build.yaml here.
#
# HINWEIS: mautrix-telegram wurde im April 2026 von Python (Telethon) auf
# Go (bridgev2-Framework, gotd-Library) umgeschrieben. Ab v0.2604.0 ist die
# alte Python-Codebase vollständig ersetzt. Go 1.25+ ist laut offizieller
# Doku (go.mod) Pflicht - daher hier ein neuerer Go-Builder als bei
# WhatsApp/Signal (die kommen mit 1.23/1 aus).
ARG TELEGRAM_VERSION=v0.2607.0
ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.0

# ---- Builder Stage (Go source build, SHA/Tag-pinned) ----
FROM golang:1.25-alpine3.24 AS builder

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
  io.hass.type="addon" \
  io.hass.name="matrix_telegram_bridge" \
  io.hass.arch="${BUILD_ARCH}" \
  org.opencontainers.image.title="Telegram Bridge (mautrix) HA Add-on" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:21.0.0" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.description="mautrix-telegram ${TELEGRAM_VERSION} als Application-Service Bridge für Matrix Synapse"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# ffmpeg: Sticker/Video-Konvertierung. LottieConverter (fuer animierte Sticker)
# bewusst NICHT installiert - Ressourcenschonung (§12), optionales Feature.
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
