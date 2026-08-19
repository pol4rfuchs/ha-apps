# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add build.yaml here.
#
# 3-Stage-Build, analog zum offiziellen github.com/mautrix/signal/Dockerfile:
# Signal braucht Rust (libsignal_ffi.a) UND Go (Bridge-Binary, linkt gegen
# das Rust-Artefakt via CGO/LIBRARY_PATH). Deshalb komplexer als WhatsApp.
ARG SIGNAL_VERSION=v0.2608.0
ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.0

# ---- Stage 1: libsignal (Rust) ----
FROM rust:1-alpine AS rust-builder

RUN apk add --no-cache git make cmake protoc musl-dev g++ clang-dev protobuf-dev

WORKDIR /build
ARG SIGNAL_VERSION
RUN git clone --depth 1 --branch "${SIGNAL_VERSION}" \
      https://github.com/mautrix/signal.git .

RUN ./build-rust.sh

# ---- Stage 2: mautrix-signal (Go) ----
FROM golang:1-alpine3.24 AS go-builder

RUN apk add --no-cache git ca-certificates build-base olm-dev zlib-dev

WORKDIR /build
ARG SIGNAL_VERSION
RUN git clone --depth 1 --branch "${SIGNAL_VERSION}" \
      https://github.com/mautrix/signal.git . \
    && git rev-parse HEAD > /build/COMMIT_SHA

ENV LIBRARY_PATH=.
COPY --from=rust-builder /build/pkg/libsignalgo/libsignal/target/*/libsignal_ffi.a ./

RUN ./build-go.sh

# ---- Runtime Stage (HA base image, multi-arch) ----
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION=dev
ARG SIGNAL_VERSION

LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.name="matrix_signal_bridge" \
  io.hass.arch="${BUILD_ARCH}" \
  org.opencontainers.image.title="Signal Bridge (mautrix) HA Add-on" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:21.0.0" \
  org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
  org.opencontainers.image.description="mautrix-signal ${SIGNAL_VERSION} als Application-Service Bridge für Matrix Synapse"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# ffmpeg: Sprachnachrichten/GIF-Konvertierung (siehe docs.mau.fi Bridge-Setup)
RUN apk add --no-cache ffmpeg olm ca-certificates yq

COPY --from=go-builder /build/mautrix-signal /usr/bin/mautrix-signal
COPY --from=go-builder /build/pkg/connector/example-config.yaml /opt/mautrix-signal/example-config.yaml
COPY --from=go-builder /build/COMMIT_SHA /opt/mautrix-signal/COMMIT_SHA

COPY rootfs /

RUN chmod a+x /usr/bin/mautrix-signal \
    && chmod a+x /etc/cont-init.d/10-signal-bridge-init.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/signal_bridge/run \
    && chmod a+x /etc/s6-overlay/s6-rc.d/signal_bridge/finish

WORKDIR /data
