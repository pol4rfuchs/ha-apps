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

RUN apk add --no-cache ca-certificates curl && \
    python3 -m pip install --no-cache-dir \
      fastapi==0.116.1 \
      uvicorn==0.35.0 \
      httpx==0.28.1 \
      pydantic==2.11.7

COPY backend /app/backend
COPY frontend/dist /app/frontend
COPY rootfs /

RUN chmod +x \
      /etc/services.d/unifi-control/run \
      /etc/services.d/unifi-control/finish

WORKDIR /app
EXPOSE 8599
