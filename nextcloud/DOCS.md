# Nextcloud — Advanced Documentation

This document covers secrets, backup, and internals beyond the
installation/quickstart steps in the README.

## Secrets

- **`admin_password`** defaults to `changeme` — **change this before the
  very first start**. It's only applied during the initial Nextcloud
  install; changing it afterwards in the add-on options does **not**
  change the actual account password (use the Nextcloud UI or `occ user:resetpassword`
  for that once it's running).
- **`db_password`** is the database user's password — must match whatever
  you configured on the MariaDB/Postgres side.

Both are declared as `password` schema types, so the Supervisor UI masks
them.

## Backup

All persistent state lives under `/data/nextcloud/` in the add-on's own
data volume:

```
/data/nextcloud/
├── html/       # Nextcloud app code + config.php
└── data/       # User files (NEXTCLOUD_DATA_DIR)
```

A Home Assistant full backup (which includes add-on data by default)
already covers this. If you back up manually, back up the entire
`/data/nextcloud/` folder as a unit — `config.php` and the user data
directory reference each other and should be restored together.

## Log Level

The `log_level` option maps onto Nextcloud's own numeric `loglevel` setting
in `config.php` (0=Debug .. 4=Fatal). Since `occ` — the only supported way
to change this — isn't usable until Nextcloud is installed, it's applied
via the official image's `docker-entrypoint-hooks.d` mechanism:

- `docker-entrypoint-hooks.d/post-installation/10-set-loglevel.sh` — runs
  once, right after the very first install
- `docker-entrypoint-hooks.d/before-starting/10-set-loglevel.sh` — runs on
  **every** start, so changing the option later takes effect on the next
  restart

## Shell / occ Access

For anything not exposed in the HA options UI, use the add-on's own shell
(Settings → Add-ons → Nextcloud → three-dot menu, or the Terminal & SSH
add-on's `docker exec`) and run `occ` directly:

```bash
php /var/www/html/occ config:system:set trusted_domains 1 --value="nextcloud.example.com"
php /var/www/html/occ config:system:set overwriteprotocol --value="https"
```

## AppArmor

`apparmor.txt` is included but **intentionally not yet enforced**
(`apparmor: false`) — this add-on runs on the official Nextcloud/Apache
vendor image rather than the HA base image, and the profile's exact paths
weren't verified against the real filesystem. See the profile's own header
comment for the manual test steps to run before flipping it to `true`.
