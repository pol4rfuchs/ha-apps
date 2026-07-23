# Changelog

## [2.1.5](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.4...nginx_proxy_manager-v2.1.5) (2026-07-23)


### Bug Fixes

* **nginx_proxy_manager:** add de.yaml, draft apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix ([d14559f](https://github.com/pol4rfuchs/ha-apps/commit/d14559f2c8cc5da7b343ca2a7c8a4a371df42ba7))

## [2.1.4](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.3...nginx_proxy_manager-v2.1.4) (2026-06-27)


### Bug Fixes

* **nginx_proxy_manager:** self-heal missing SSL cert files to prevent nginx crash-loop ([1ab86a8](https://github.com/pol4rfuchs/ha-apps/commit/1ab86a86a815c77935db20902127996e0901f1c6))

## [2.1.0] - 2026-03-15

### Neu
- Secrets-Support: `npm_mariadb_password` + `npm_jwt_secret` aus `secrets.yaml`
- AppArmor-Profil reaktiviert mit vollständigem s6-overlay v3 Regelwerk
- panel_iframe Package für direkten Seitenleisten-Zugang (npm_panel.yaml)
- Version bump config.yaml auf 2.1.0

### Geändert
- `mariadb_password` + `npm_jwt_secret` aus options/schema entfernt (jetzt secrets)
- apparmor: false → apparmor: true

## [2.0.1] - 2026-03-14

### Fix
- Image-Tag gepinnt: latest → 2.14.0
- Zertifikate persistent: Hintergrund-Sync /etc/letsencrypt → /data/npm/letsencrypt
- rsync installiert für zuverlässigen Cert-Sync

## [2.0.0] - 2026-03-07

### Neu
- Erstveröffentlichung
- Offizielles jc21/nginx-proxy-manager Image als Basis
- HA Wrapper-Entrypoint
- S6_BASEDIR=/tmp/s6 (noexec /run/ Fix)
- Alle Ports mit Beschreibungen: 80, 81, 443
- SQLite + MariaDB Support
- Multi-Arch: amd64 + aarch64
