ARG BUILD_VERSION
FROM jc21/nginx-proxy-manager:2.14.0

# ── jq für Supervisor API ─────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── s6-overlay Permissions ────────────────────────────────────────────────────
RUN chmod -R 755 /package/ 2>/dev/null || true \
    && chmod 755 /init 2>/dev/null || true

# ── NPM mountpoint-Check patchen ─────────────────────────────────────────────
# NPM prüft ob /etc/letsencrypt ein echter mountpoint ist → für HA ersetzen
# wir durch eine einfache Verzeichnisprüfung
RUN find /etc/s6-overlay /etc/cont-init.d -type f 2>/dev/null \
    | xargs grep -l "letsencrypt is not mounted" 2>/dev/null \
    | xargs sed -i \
        's|mountpoint -q /etc/letsencrypt|[ -d /etc/letsencrypt ]|g' \
    2>/dev/null || true

# ── /etc/letsencrypt als echtes Verzeichnis anlegen ───────────────────────────
RUN mkdir -p /etc/letsencrypt

# ── Data Directories ──────────────────────────────────────────────────────────
RUN mkdir -p /data/npm/data /data/npm/letsencrypt /data/npm/logs

# ── HA Wrapper Entrypoint ─────────────────────────────────────────────────────
COPY run.sh /usr/local/bin/ha-entrypoint.sh
RUN chmod 755 /usr/local/bin/ha-entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/ha-entrypoint.sh"]
