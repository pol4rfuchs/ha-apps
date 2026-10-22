ARG BUILD_ARCH
ARG BUILD_VERSION
# Bumped automatically by 07-update-upstream-candidate.yml and 23-fast-image-watch.yml
# (dockerhub_arg_tag mode), restricted to the current major version.
ARG NEXTCLOUD_TAG=35.0.2-apache

# ── Base: official Nextcloud image (multi-arch: amd64 + arm64v8) ──────────────
# No HA base image — we use the official PHP/Apache image directly so that
# the full Nextcloud app ecosystem (apps.nextcloud.com) works without
# restrictions imposed by linuxserver.io or other wrappers.
FROM nextcloud:${NEXTCLOUD_TAG}

# Build args declared before FROM are not visible after it.
ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
    io.hass.name="Nextcloud" \
    io.hass.description="A safe home for all your data" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="app" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.url="https://github.com/pol4rfuchs/ha-apps/tree/main/nextcloud" \
    maintainer="pol4rfuchs"

# ── PHP security floor ────────────────────────────────────────────────────────
# CVE-2026-109618 / CVE-2026-109619 (RCE, fixed in PHP 8.2.35, 8.3.36, 8.4.27,
# 8.5.12): fail the build if the base image still ships an older PHP.
RUN php -r '$min = ["8.2" => "8.2.35", "8.3" => "8.3.36", "8.4" => "8.4.27", "8.5" => "8.5.12"]; \
    $line = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION; \
    if (!isset($min[$line]) || version_compare(PHP_VERSION, $min[$line], "<")) { \
        fwrite(STDERR, "PHP " . PHP_VERSION . " is not a patched release\n"); exit(1); \
    }'

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

RUN chmod +x /ha-init.sh \
    && chmod +x /docker-entrypoint-hooks.d/post-installation/*.sh \
    && chmod +x /docker-entrypoint-hooks.d/before-starting/*.sh

# ── Entrypoint: run HA init, then hand off to official NC entrypoint ──────────
ENTRYPOINT ["/ha-init.sh"]
CMD ["apache2-foreground"]
