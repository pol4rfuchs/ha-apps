#!/bin/sh
set -e

# ── 1. Secrets (via Node.js crypto) ──────────────────────────────────────
if [ ! -f /data/secrets.env ]; then
    echo "[ts6-init] Generating secrets ..."
    JWT_SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('base64url'))")"
    ENCRYPTION_KEY="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('base64url'))")"
    printf 'JWT_SECRET=%s\nENCRYPTION_KEY=%s\n' \
        "${JWT_SECRET}" "${ENCRYPTION_KEY}" > /data/secrets.env
    echo "[ts6-init] Secrets written to /data/secrets.env"
fi

# ── 2. Data directories ───────────────────────────────────────────────────
mkdir -p /data/music

# ── 3. Database: copy pre-migrated template if no DB exists yet ───────────
if [ ! -f /data/ts6webui.db ]; then
    echo "[ts6-init] Initialising database from template ..."
    cp /app/ts6webui-template.db /data/ts6webui.db
    echo "[ts6-init] Database ready"
fi

echo "[ts6-init] Done"
