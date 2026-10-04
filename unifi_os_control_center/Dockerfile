# syntax=docker/dockerfile:1.7
ARG BUILD_FROM=ghcr.io/home-assistant/base-python:3.13-alpine3.22
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL io.hass.arch="${BUILD_ARCH}" \
      io.hass.type="app" \
      io.hass.version="${BUILD_VERSION}" \
      org.opencontainers.image.title="UniFi OS Control Center" \
      org.opencontainers.image.description="Local-first UniFi OS control plane for Home Assistant" \
      org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps"

COPY requirements.txt /tmp/requirements.txt

RUN apk add --no-cache ca-certificates curl && \
    python3 -m pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

COPY backend /app/backend
COPY frontend/dist /app/frontend
COPY rootfs /

RUN chmod +x \
      /etc/s6-overlay/s6-rc.d/unifi-control/run \
      /etc/s6-overlay/s6-rc.d/unifi-control/finish

WORKDIR /app
EXPOSE 8599

# Exec form (no shell); a failed request raises and exits 1 = unhealthy.
# Loopback is allowed by the app's Ingress peer guard.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8599/api/health', timeout=4)"]
