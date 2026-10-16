#!/bin/bash
# ha-init.sh — Home Assistant ↔ Nextcloud bridge
# Runs before the official nextcloud /entrypoint.sh.
# Reads /data/options.json, configures NC env vars and PHP settings,
# sets up persistent data layout, then execs the upstream entrypoint.
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
OPTIONS=/data/options.json

opt_str() {
    local key="$1" default="${2:-}"
    python3 -c "import json,sys; d=json.load(open('${OPTIONS}')); print(d.get('${key}','${default}'))" 2>/dev/null || echo "${default}"
}

opt_int() {
    local key="$1" default="${2:-0}"
    python3 -c "import json,sys; d=json.load(open('${OPTIONS}')); print(int(d.get('${key}',${default})))" 2>/dev/null || echo "${default}"
}

log() { echo "[ha-init] $*"; }

# ── Read HA options ───────────────────────────────────────────────────────────
ADMIN_USER=$(opt_str admin_user "admin")
ADMIN_PASS=$(opt_str admin_password "")
TRUSTED_DOMAINS=$(opt_str trusted_domains "")
DB_TYPE=$(opt_str db_type "mysql")
DB_HOST=$(opt_str db_host "core-mariadb")
DB_PORT=$(opt_int db_port 3306)
DB_NAME=$(opt_str db_name "nextcloud")
DB_USER=$(opt_str db_user "nextcloud")
DB_PASS=$(opt_str db_password "")
PHP_MEM=$(opt_str php_memory_limit "512M")
MAX_UPLOAD=$(opt_str max_upload_size "16G")
MAX_EXEC=$(opt_int max_execution_time 3600)
LOG_LEVEL=$(opt_str log_level "info")

# Nextcloud's config.php only knows a numeric loglevel (0=Debug .. 4=Fatal).
# Map the HA-side list(debug|info|warning|error|fatal) option onto it; the
# actual value is applied via occ in the docker-entrypoint-hooks.d scripts
# below, since config.php doesn't exist yet on first boot at this point.
case "${LOG_LEVEL}" in
  debug)   NC_LOG_LEVEL_NUM=0 ;;
  info)    NC_LOG_LEVEL_NUM=1 ;;
  warning) NC_LOG_LEVEL_NUM=2 ;;
  error)   NC_LOG_LEVEL_NUM=3 ;;
  fatal)   NC_LOG_LEVEL_NUM=4 ;;
  *)       NC_LOG_LEVEL_NUM=1 ;;
esac
export NC_LOG_LEVEL_NUM
log "Log level: ${LOG_LEVEL} (Nextcloud loglevel=${NC_LOG_LEVEL_NUM})"

# ── Persistent data layout ────────────────────────────────────────────────────
# HA mounts /data (add-on persistent storage). Layout:
#   /data/nextcloud/data         → NC user files (NEXTCLOUD_DATA_DIR)
#   /data/nextcloud/config       → config.php (linked into /var/www/html)
#   /data/nextcloud/custom_apps  → apps installed from the app store
#   /data/nextcloud/themes       → themes
#   /data/nextcloud/version.php  → version of the installed code
#
# /var/www/html is a VOLUME in the official image: it cannot be replaced by a
# symlink, and the Supervisor creates a new container (= new, empty volume) on
# every start. So the code only lives there for the lifetime of the container.
# The official entrypoint's rsync --delete would also remove symlinks for the
# persistent directories, so it must not run on an existing installation:
#   * first start : the entrypoint installs normally; the before-starting hook
#                   (20-persist-and-upgrade.sh) then moves config, custom_apps
#                   and themes to /data/nextcloud and links them back.
#   * later starts: this script restores the code and the links and presents
#                   the image's version.php, so the entrypoint skips its
#                   install/upgrade step; the hook runs `occ upgrade` itself
#                   when the image is newer than the saved version.
NC_BASE=/data/nextcloud
NC_HTML=/var/www/html
NC_SRC=/usr/src/nextcloud
mkdir -p "${NC_BASE}/data"

# Ownership: user data is only chowned once (it can be huge); the small
# directories on every start.
chown www-data:www-data "${NC_BASE}"
for d in config custom_apps themes; do
    [[ -d "${NC_BASE}/${d}" ]] && chown -R www-data:www-data "${NC_BASE}/${d}"
done
if [[ "$(stat -c %U "${NC_BASE}/data")" != "www-data" ]]; then
    log "Setting ownership of ${NC_BASE}/data (first start)…"
    chown -R www-data:www-data "${NC_BASE}/data"
fi

if [[ -f "${NC_BASE}/config/config.php" ]]; then
    log "Existing installation found, restoring code from the image…"
    rsync -rlDog --chown=www-data:www-data --exclude-from=/upgrade.exclude "${NC_SRC}/" "${NC_HTML}/"
    for d in config custom_apps themes; do
        mkdir -p "${NC_BASE}/${d}"
        chown www-data:www-data "${NC_BASE}/${d}"
        rm -rf "${NC_HTML:?}/${d}"
        ln -s "${NC_BASE}/${d}" "${NC_HTML}/${d}"
        # /var/www/html is sticky (1777): the kernel (protected_symlinks) only lets
        # www-data follow links that www-data owns.
        chown -h www-data:www-data "${NC_HTML}/${d}"
    done
    cp "${NC_SRC}/version.php" "${NC_HTML}/version.php"
    chown www-data:www-data "${NC_HTML}/version.php"
fi

# ── Admin password: no default, required for the first install ────────────────
# Nextcloud does not enforce a password change, so the add-on ships no default.
# The password is only used by the initial install; once config.php exists it
# is ignored.
if [[ ! -f "${NC_BASE}/config/config.php" ]]; then
    if [[ -z "${ADMIN_PASS}" || "${ADMIN_PASS}" == "changeme" ]]; then
        log "ERROR: admin_password is empty (or 'changeme'). Set a strong admin password in the add-on options before the first start."
        exit 1
    fi
fi

# ── Export Nextcloud env vars (used by official /entrypoint.sh) ───────────────
export NEXTCLOUD_ADMIN_USER="${ADMIN_USER}"
export NEXTCLOUD_ADMIN_PASSWORD="${ADMIN_PASS}"
export NEXTCLOUD_DATA_DIR="${NC_BASE}/data"

# Trusted domains: space-separated string → NC env var
# The official NC entrypoint splits on spaces for NEXTCLOUD_TRUSTED_DOMAINS.
if [[ -n "${TRUSTED_DOMAINS}" ]]; then
    export NEXTCLOUD_TRUSTED_DOMAINS="${TRUSTED_DOMAINS}"
    log "Trusted domains (applied on first install): ${TRUSTED_DOMAINS}"
else
    log "WARNING: trusted_domains is empty - Nextcloud will only accept 'localhost'. Add the hostname/IP you open it with (applies on first install; later use occ, see DOCS)."
fi

# ── Database ──────────────────────────────────────────────────────────────────
case "${DB_TYPE}" in
  mysql)
    log "DB: MariaDB @ ${DB_HOST}:${DB_PORT} / ${DB_NAME}"
    export MYSQL_HOST="${DB_HOST}:${DB_PORT}"
    export MYSQL_DATABASE="${DB_NAME}"
    export MYSQL_USER="${DB_USER}"
    export MYSQL_PASSWORD="${DB_PASS}"
    ;;
  pgsql)
    log "DB: PostgreSQL @ ${DB_HOST}:${DB_PORT} / ${DB_NAME}"
    export POSTGRES_HOST="${DB_HOST}"
    export POSTGRES_PORT="${DB_PORT}"
    export POSTGRES_DB="${DB_NAME}"
    export POSTGRES_USER="${DB_USER}"
    export POSTGRES_PASSWORD="${DB_PASS}"
    ;;
  sqlite)
    log "DB: SQLite (not recommended for production)"
    # The official entrypoint only installs unattended when this is set.
    export SQLITE_DATABASE="nextcloud"
    ;;
  *)
    log "Unknown db_type '${DB_TYPE}', falling back to sqlite"
    export SQLITE_DATABASE="nextcloud"
    ;;
esac

# ── PHP runtime overrides ─────────────────────────────────────────────────────
PHP_INI=/usr/local/etc/php/conf.d/ha-nextcloud.ini
log "Writing PHP config: memory=${PHP_MEM}, upload=${MAX_UPLOAD}, exec=${MAX_EXEC}s"
cat > "${PHP_INI}" << EOF
; Generated by ha-init.sh — do not edit manually
memory_limit = ${PHP_MEM}
upload_max_filesize = ${MAX_UPLOAD}
post_max_size = ${MAX_UPLOAD}
max_execution_time = ${MAX_EXEC}
max_input_time = ${MAX_EXEC}
output_buffering = Off
EOF

# ── Redis socket (optional — enable if redis addon is running) ────────────────
# Uncomment if you add a redis option to config.yaml:
# export REDIS_HOST=/var/run/redis/redis.sock

log "Handing off to official Nextcloud entrypoint…"
exec /entrypoint.sh "$@"
