# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add restic_backup/build.yaml.
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.0

FROM ${BUILD_FROM}

ARG BUILD_VERSION=dev

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.name="restic_backup" \
    org.opencontainers.image.title="Restic Backup Home Assistant Add-on" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:21.0.0" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.description="Scheduled restic backups with ntfy alerting, packaged as a Home Assistant add-on"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# restic:   the actual backup engine
# dcron:    lightweight cron daemon to run backups on a schedule
# curl:     ntfy notifications
# jq:       parsing restic's JSON output for the ntfy summary
# tzdata:   correct cron timing under the HA-configured timezone
RUN apk add --no-cache \
        restic \
        dcron \
        curl \
        jq \
        tzdata \
    && mkdir -p /etc/crontabs

COPY run.sh /run.sh
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /run.sh /usr/local/bin/backup.sh

CMD ["/run.sh"]
