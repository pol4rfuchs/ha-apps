# ==============================================================================
# Forgejo – Home Assistant Add-on Dockerfile
#
# Strategie (von GitLab-Repo abgeleitet, sauberste Methode):
#   Stage 1: Offizielles Forgejo-Image als Quelle für Binary + Tools
#   Stage 2: Offizielles HA-Base-Image (hat s6-overlay, bashio, with-contenv)
#
# Nur 4 Dateien aus dem Forgejo-Image werden übernommen:
#   - /app/gitea/gitea            → Forgejo-Binary
#   - /usr/local/bin/environment-to-ini → env vars → app.ini
#   - /etc/templates/app.ini      → Basis-Template für app.ini
#
# Das HA-Base-Image bringt s6-overlay, bashio und with-contenv mit.
# Kein manuelles Nachinstallieren dieser Tools nötig.
# ==============================================================================
# BUILD_FROM muss vor dem ersten FROM deklariert werden (Docker Multi-Stage Regel)
ARG BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0
ARG BUILD_VERSION
ARG FORGEJO_IMAGE_VERSION=15.0.3

FROM codeberg.org/forgejo/forgejo:${FORGEJO_IMAGE_VERSION}-rootless AS forgejo

FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION
# FORGEJO_VERSION als Major-Tracking entfernt – FORGEJO_IMAGE_VERSION übernimmt

# OCI Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="pol4rfuchs" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"
# Laufzeit-Abhängigkeiten (Alpine):
# - gosu: sicheres Privilege-Dropping (git-User für Forgejo-Prozess)
# - git: für Git-Operationen
# - openssh-keygen: persistente SSH-Host-Keys generieren
# - curl/jq: HA Supervisor API (Ingress-URL lesen) — oft schon in HA-Base
RUN apk add --no-cache \
        gosu \
        git \
        openssh \
        curl \
        jq
# Forgejo Binary + Tools aus Stage 1 kopieren
# Pfade gelten für das rootless-Image (stabil seit v9)
COPY --from=forgejo /app/gitea/gitea                    /app/gitea/gitea
COPY --from=forgejo /usr/local/bin/environment-to-ini   /usr/local/bin/environment-to-ini
COPY --from=forgejo /etc/templates/app.ini              /etc/templates/app.ini
# git-User anlegen (uid/gid 1000, identisch mit Forgejo-Standard)
RUN addgroup -S -g 1000 git \
    && adduser -S -H -D \
        -h /var/lib/gitea/git \
        -s /bin/bash \
        -u 1000 \
        -G git \
        git
# Forgejo-Verzeichnisse (Work-Dir, nicht die persistenten Daten)
RUN mkdir -p /var/lib/gitea /tmp/gitea \
    && chown -R git:git /var/lib/gitea /tmp/gitea
# Umgebungsvariablen für Forgejo
# GITEA_CUSTOM=/config → addon_config Mount (app.ini, Repos, Daten)
# GITEA_WORK_DIR=/var/lib/gitea → internes Work-Directory
ENV \
    GITEA_CUSTOM="/config" \
    GITEA_WORK_DIR="/var/lib/gitea" \
    GITEA_TEMP="/tmp/gitea" \
    GITEA_APP_INI="/config/conf/app.ini" \
    HOME="/var/lib/gitea/git" \
    USER="git"
# s6-Overlay Service-Skripte aus rootfs kopieren
COPY rootfs /
# Ausführbar machen
RUN chmod a+x \
    /etc/s6-overlay/s6-rc.d/forgejo/setup \
    /etc/s6-overlay/s6-rc.d/forgejo/run \
    /etc/s6-overlay/s6-rc.d/forgejo/finish
EXPOSE 3000 22
# s6-overlay init als Entrypoint (vom HA-Base-Image bereitgestellt)
ENTRYPOINT ["/init"]