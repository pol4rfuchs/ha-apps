# syntax=docker/dockerfile:1
# ── Stage 1: compile intiface-engine natively ──────────────────────────────
# cargo install = always the correct version, native for the build architecture,
# no box64 needed. Build time: ~15 min on a Pi4 (cached afterwards).
FROM rust:slim-bookworm AS engine-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
      pkg-config \
      libdbus-1-dev \
      libudev-dev \
      libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*
ARG ENGINE_VERSION=4.0.2
RUN cargo install intiface-engine --version "${ENGINE_VERSION}" \
    && strip /usr/local/cargo/bin/intiface-engine
# ── Stage 2: Runtime-Image ───────────────────────────────────────────────────
FROM node:22-bookworm-slim
ARG BUILD_ARCH
ARG BUILD_VERSION
LABEL \
  io.hass.name="Intiface Central" \
  io.hass.description="Buttplug/Intiface Central with web GUI, MQTT bridge and Home Assistant entities" \
  io.hass.type="app" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.version="${BUILD_VERSION}"
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      dbus dbus-user-session \
      bluez \
      libdbus-1-3 \
      libudev1 \
      libusb-1.0-0 \
      tini \
    && rm -rf /var/lib/apt/lists/*
COPY --from=engine-builder /usr/local/cargo/bin/intiface-engine /usr/local/bin/intiface-engine
WORKDIR /opt/intiface-addon
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.js ./
COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]