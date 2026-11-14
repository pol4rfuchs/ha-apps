# Changelog

## [2.1.8](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.7...nginx_proxy_manager-v2.1.8) (2026-11-13)


### Bug Fixes

* **nginx_proxy_manager:** update upstream to 2.17.0 (changelog: https://github.com/NginxProxyManager/nginx-proxy-manager/releases) ([#897](https://github.com/pol4rfuchs/ha-apps/issues/897)) ([7c03567](https://github.com/pol4rfuchs/ha-apps/commit/7c03567dd3cc9a4aa643fa7adcd7065ef6ea9d5a))

## [2.1.7](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.6...nginx_proxy_manager-v2.1.7) (2026-10-16)


### Bug Fixes

* **nginx_proxy_manager:** add mariadb_password option, drop non-functional secrets/JWT/port options ([#547](https://github.com/pol4rfuchs/ha-apps/issues/547)) ([b3d7425](https://github.com/pol4rfuchs/ha-apps/commit/b3d742516efd8eb75628361515710cb805066a0e))

## [2.1.6](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.5...nginx_proxy_manager-v2.1.6) (2026-09-24)


### Bug Fixes

* **nginx_proxy_manager:** update upstream to 2.16.0 (changelog: https://github.com/NginxProxyManager/nginx-proxy-manager/releases) ([#424](https://github.com/pol4rfuchs/ha-apps/issues/424)) ([887fccb](https://github.com/pol4rfuchs/ha-apps/commit/887fccb696e7508c7252376bbed18cbfba81fc9b))

## [2.1.5](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.4...nginx_proxy_manager-v2.1.5) (2026-07-23)


### Bug Fixes

* **nginx_proxy_manager:** add de.yaml, draft apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix ([d14559f](https://github.com/pol4rfuchs/ha-apps/commit/d14559f2c8cc5da7b343ca2a7c8a4a371df42ba7))

## [2.1.4](https://github.com/pol4rfuchs/ha-apps/compare/nginx_proxy_manager-v2.1.3...nginx_proxy_manager-v2.1.4) (2026-06-27)


### Bug Fixes

* **nginx_proxy_manager:** self-heal missing SSL cert files to prevent nginx crash-loop ([1ab86a8](https://github.com/pol4rfuchs/ha-apps/commit/1ab86a86a815c77935db20902127996e0901f1c6))

## [2.1.0] - 2026-03-15

### New
- Secrets support: `npm_mariadb_password` + `npm_jwt_secret` from `secrets.yaml`
- AppArmor profile re-enabled with a complete s6-overlay v3 rule set
- panel_iframe package for direct sidebar access (npm_panel.yaml)
- Version bump of config.yaml to 2.1.0

### Changed
- Removed `mariadb_password` + `npm_jwt_secret` from options/schema (now secrets)
- apparmor: false → apparmor: true

## [2.0.1] - 2026-03-14

### Fix
- Image tag pinned: latest → 2.14.0
- Certificates persistent: background sync /etc/letsencrypt → /data/npm/letsencrypt
- Installed rsync for reliable cert sync

## [2.0.0] - 2026-03-07

### New
- Initial release
- Official jc21/nginx-proxy-manager image as base
- HA wrapper entrypoint
- S6_BASEDIR=/tmp/s6 (noexec /run/ fix)
- All ports with descriptions: 80, 81, 443
- SQLite + MariaDB support
- Multi-Arch: amd64 + aarch64
