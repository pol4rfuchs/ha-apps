# syntax=docker/dockerfile:1

# ── Stage 1: intiface-engine nativ kompilieren ──────────────────────────────
# cargo install = immer korrekte Version, nativ für die Build-Architektur,
# kein box64 nötig. Build-Zeit: ~15 Min auf Pi4 (danach gecacht).
FROM rust:slim-bookworm AS engine-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
      pkg-config \
      libdbus-1-dev \
      libudev-dev \
      libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*

ARG ENGINE_VERSION=4.0.0
RUN cargo install intiface-engine --version "${ENGINE_VERSION}" \
    && strip /usr/local/cargo/bin/intiface-engine

# ── Stage 2: Runtime-Image ───────────────────────────────────────────────────
FROM node:20-bookworm-slim

LABEL \
  io.hass.type="addon" \
  io.hass.arch="amd64 aarch64" \
  io.hass.version="1.0.0"

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
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY server.js ./
COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
