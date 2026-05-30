# Build parameters are intentionally kept in this Dockerfile.
# Home Assistant build.yaml is deprecated; do not re-add ntfy/build.yaml.
ARG NTFY_VERSION=2.23.0

# Stage 1: ntfy binary from the official multi-arch image
FROM binwiederhier/ntfy:v${NTFY_VERSION} AS ntfy-source

# Stage 2: Home Assistant base image (multi-arch: amd64 + arm64)
FROM ghcr.io/hassio-addons/base:16.3.2

ARG BUILD_VERSION=dev
ARG NTFY_VERSION=2.23.0

LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.name="ntfy" \
    org.opencontainers.image.title="ntfy Home Assistant Add-on" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.base.name="ghcr.io/hassio-addons/base:16.3.2" \
    org.opencontainers.image.source="https://github.com/binwiederhier/ntfy" \
    org.opencontainers.image.description="ntfy ${NTFY_VERSION} packaged as a Home Assistant add-on"

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

COPY --from=ntfy-source /usr/bin/ntfy /usr/local/bin/ntfy

ENV NTFY_AUTH_FILE=/data/ntfy/user.db

RUN apk add --no-cache python3 \
    && chmod +x /usr/local/bin/ntfy \
    && mkdir -p \
        /data/ntfy/cache \
        /data/ntfy/attachments \
        /etc/ntfy \
        /opt/ntfy-admin \
        /etc/profile.d \
    && printf '# ntfy CLI environment — auto-configured by HA add-on\n\
export NTFY_AUTH_FILE=/data/ntfy/user.db\n\
\n\
ntfy_adduser() {\n\
    local user="$1" pass="$2" role="${3:-user}"\n\
    NTFY_PASSWORD="$pass" ntfy user add --role="$role" "$user"\n\
}\n\
\n\
ntfy_passwd() {\n\
    NTFY_PASSWORD="$2" ntfy user change-pass "$1"\n\
}\n\
\n\
ntfy_token() {\n\
    ntfy token add --label="${2:-manual}" "$1"\n\
}\n\
' > /etc/profile.d/ntfy.sh \
    && chmod +x /etc/profile.d/ntfy.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4280/v1/health || exit 1

COPY admin/index.html /opt/ntfy-admin/index.html
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
