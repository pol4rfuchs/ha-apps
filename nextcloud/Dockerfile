ARG BUILD_ARCH
ARG BUILD_VERSION
# Bumped automatically by 06-update-upstream-candidate.yml (dockerhub_arg_tag mode)
ARG NEXTCLOUD_TAG=33.0.5-apache

# ── Base: official Nextcloud image (multi-arch: amd64 + arm64v8) ──────────────
# No HA base image — we use the official PHP/Apache image directly so that
# the full Nextcloud app ecosystem (apps.nextcloud.com) works without
# restrictions imposed by linuxserver.io or other wrappers.
FROM nextcloud:${NEXTCLOUD_TAG}

LABEL \
    io.hass.name="Nextcloud" \
    io.hass.description="A safe home for all your data" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.url="https://github.com/pol4rfuchs/ha-apps/tree/main/nextcloud" \
    maintainer="pol4rfuchs"

# ── System packages ───────────────────────────────────────────────────────────
# - jq     : read /data/options.json in ha-init.sh
# - ffmpeg : Nextcloud preview generation (optional but common)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        jq \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ── Copy HA wrapper ───────────────────────────────────────────────────────────
COPY rootfs /

RUN chmod +x /ha-init.sh

# ── Entrypoint: run HA init, then hand off to official NC entrypoint ──────────
ENTRYPOINT ["/ha-init.sh"]
CMD ["apache2-foreground"]
