ARG BUILD_VERSION
FROM jc21/nginx-proxy-manager:2.15.0

# ── jq für Supervisor API ─────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Permissions + NPM mountpoint-Check + Directories ─────────────────────────
# DL3059: consolidated chmod, find-patch, and mkdir into one RUN
# SC2038+DL4006: replaced pipe chain with -print0/-0 xargs; || true swallows
#                expected failures on images without letsencrypt references.
# hadolint ignore=DL4006
RUN chmod -R 755 /package/ 2>/dev/null || true \
    && chmod 755 /init 2>/dev/null || true \
    && find /etc/s6-overlay /etc/cont-init.d -type f -print0 2>/dev/null \
       | xargs -0 grep -l "letsencrypt is not mounted" 2>/dev/null \
       | xargs -0 sed -i \
           's|mountpoint -q /etc/letsencrypt|[ -d /etc/letsencrypt ]|g' \
       2>/dev/null || true \
    && mkdir -p /etc/letsencrypt \
    && mkdir -p /data/npm/data /data/npm/letsencrypt /data/npm/logs

# ── HA Wrapper Entrypoint ─────────────────────────────────────────────────────
COPY run.sh /usr/local/bin/ha-entrypoint.sh
RUN chmod 755 /usr/local/bin/ha-entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/ha-entrypoint.sh"]
