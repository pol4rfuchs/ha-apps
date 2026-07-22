# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add teamspeak6/build.yaml.
ARG TEAMSPEAK_VERSION=6.0.0-beta11
FROM teamspeaksystems/teamspeak6-server:${TEAMSPEAK_VERSION}

ARG BUILD_VERSION=dev
ARG BUILD_ARCH
ARG TEAMSPEAK_VERSION=6.0.0-beta11

# DL3002: root required — TS6 server process needs root for initial setup
# hadolint ignore=DL3002
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl jq ca-certificates sqlite3 \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /
RUN chmod +x /run.sh

LABEL \
    io.hass.name="TeamSpeak 6 Server" \
    io.hass.description="TeamSpeak 6 Voice Server — ARM64 & amd64" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.base.name="teamspeaksystems/teamspeak6-server:${TEAMSPEAK_VERSION}"

ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
