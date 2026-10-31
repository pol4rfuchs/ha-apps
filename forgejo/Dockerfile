# ==============================================================================
# Forgejo – Home Assistant add-on Dockerfile
#
# Strategy (derived from the GitLab repo, cleanest method):
#   Stage 1: official Forgejo image as the source for binary + tools
#   Stage 2: official HA base image (has s6-overlay, bashio, with-contenv)
#
# Only 4 files are taken from the Forgejo image:
#   - /app/gitea/gitea            → Forgejo binary
#   - /usr/local/bin/environment-to-ini → env vars → app.ini
#   - /etc/templates/app.ini      → base template for app.ini
#
# The HA base image brings s6-overlay, bashio and with-contenv.
# No need to install these tools manually.
# ==============================================================================
# BUILD_FROM must be declared before the first FROM (Docker multi-stage rule)
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.7
ARG BUILD_VERSION
ARG FORGEJO_IMAGE_VERSION=17.0.1

FROM codeberg.org/forgejo/forgejo:${FORGEJO_IMAGE_VERSION}-rootless AS forgejo

FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION
# FORGEJO_VERSION as major tracking removed – FORGEJO_IMAGE_VERSION takes over

# OCI Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="app" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="pol4rfuchs" \
    org.opencontainers.image.licenses="GPL-3.0-or-later" \
    org.opencontainers.image.url="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"
# Runtime dependencies (Alpine):
# - gosu: safe privilege dropping (git user for the Forgejo process)
# - git: for Git operations
# - openssh-keygen: generate persistent SSH host keys
# - gettext-envsubst: app.ini is created from the template via envsubst on first start
# - curl/jq: general helper tools, often already in the HA base
RUN apk add --no-cache \
        gosu \
        git \
        openssh \
        gettext-envsubst \
        curl \
        jq
# Copy the Forgejo binary + tools from stage 1
# Paths apply to the rootless image (stable since v9)
COPY --from=forgejo /app/gitea/gitea                    /app/gitea/gitea
COPY --from=forgejo /usr/local/bin/environment-to-ini   /usr/local/bin/environment-to-ini
COPY --from=forgejo /etc/templates/app.ini              /etc/templates/app.ini
# Create the git user (uid/gid 1000, identical to the Forgejo default)
RUN addgroup -S -g 1000 git \
    && adduser -S -H -D \
        -h /var/lib/gitea/git \
        -s /bin/bash \
        -u 1000 \
        -G git \
        git
# Forgejo directories (work dir, not the persistent data)
RUN mkdir -p /var/lib/gitea /tmp/gitea \
    && chown -R git:git /var/lib/gitea /tmp/gitea
# Environment variables for Forgejo
# GITEA_CUSTOM=/config → addon_config mount (app.ini, repos, data)
# GITEA_WORK_DIR=/var/lib/gitea → internal work directory
ENV \
    GITEA_CUSTOM="/config" \
    GITEA_WORK_DIR="/var/lib/gitea" \
    GITEA_TEMP="/tmp/gitea" \
    GITEA_APP_INI="/config/conf/app.ini" \
    HOME="/var/lib/gitea/git" \
    USER="git"
# s6-Overlay Service-Skripte aus rootfs kopieren
COPY rootfs /
# Make executable
RUN chmod a+x \
    /etc/s6-overlay/s6-rc.d/forgejo/setup \
    /etc/s6-overlay/s6-rc.d/forgejo/run \
    /etc/s6-overlay/s6-rc.d/forgejo/finish
EXPOSE 3000 22
# s6-overlay init als Entrypoint (vom HA-Base-Image bereitgestellt)
ENTRYPOINT ["/init"]
