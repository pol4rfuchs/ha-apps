#!/bin/sh
set -e

# ── 1. Secrets (via Node.js crypto) ──────────────────────────────────────
if [ ! -f /data/secrets.env ]; then
    echo "[ts6-init] Generating secrets ..."
    JWT_SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('base64url'))")"
    ENCRYPTION_KEY="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('base64url'))")"
    SIDECAR_TOKEN="$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64url'))")"
    printf 'JWT_SECRET=%s\nENCRYPTION_KEY=%s\nSIDECAR_TOKEN=%s\n' \
        "${JWT_SECRET}" "${ENCRYPTION_KEY}" "${SIDECAR_TOKEN}" > /data/secrets.env
    echo "[ts6-init] Secrets written to /data/secrets.env"
fi

# Upgrade path: existing installs from before the sidecar was added won't
# have SIDECAR_TOKEN in their secrets.env yet. Append it once, in place,
# rather than requiring a fresh install.
if ! grep -q '^SIDECAR_TOKEN=' /data/secrets.env; then
    echo "[ts6-init] Adding SIDECAR_TOKEN to existing secrets.env ..."
    SIDECAR_TOKEN="$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64url'))")"
    printf 'SIDECAR_TOKEN=%s\n' "${SIDECAR_TOKEN}" >> /data/secrets.env
fi

# ── 2. Data directories ───────────────────────────────────────────────────
mkdir -p /data/music

# ── 3. Database: copy pre-migrated template if no DB exists yet ───────────
if [ ! -f /data/ts6webui.db ]; then
    echo "[ts6-init] Initialising database from template ..."
    cp /app/ts6webui-template.db /data/ts6webui.db
    echo "[ts6-init] Database ready"
fi

# ── 4. Schema sync for existing installs (upgrade path) ───────────────────
# Neither upstream repo ships a prisma/migrations history (both build via
# `prisma db push`, see the fork comparison) — so there is no `migrate
# deploy` to run. Instead we run the same `db push` against the *persisted*
# /data DB on every start, without --accept-data-loss: additive schema
# changes (new nullable columns, new tables — everything seen in the coom
# fork's schema diff) apply automatically; anything that would actually
# lose data makes this step fail loudly instead of silently dropping data.
# If this ever fails: back up /data/ts6webui.db, check the release notes,
# and resolve manually before retrying.
echo "[ts6-init] Syncing database schema (prisma db push) ..."
cd /app
if ! DATABASE_URL="file:/data/ts6webui.db" npx --no-install prisma db push --skip-generate --schema=prisma/schema.prisma; then
    echo "[ts6-init] ERROR: schema sync failed or was refused (likely a destructive change)." >&2
    echo "[ts6-init] Back up /data/ts6webui.db, check the release notes, then retry." >&2
    exit 1
fi

echo "[ts6-init] Done"
