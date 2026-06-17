# Changelog

## [33.0.11](https://github.com/pol4rfuchs/ha-apps/compare/nextcloud-v33.0.10...nextcloud-v33.0.11) (2026-06-17)


### Bug Fixes

* **nextcloud:** update upstream to 34.0.0-apach ([0012865](https://github.com/pol4rfuchs/ha-apps/commit/001286539355baaa7ebf0d40a66d2712f6bce4ae))
* **nextcloud:** update upstream to 34.0.0-apach ([fb20f67](https://github.com/pol4rfuchs/ha-apps/commit/fb20f67271b8a15be190a2861b8035287e4189c2))

## [33.0.10](https://github.com/pol4rfuchs/ha-apps/compare/nextcloud-v33.0.9...nextcloud-v33.0.10) (2026-06-17)


### Bug Fixes

* **nextcloud:** update upstream to 34.0.0-apach ([0012865](https://github.com/pol4rfuchs/ha-apps/commit/001286539355baaa7ebf0d40a66d2712f6bce4ae))
* **nextcloud:** update upstream to 34.0.0-apach ([fb20f67](https://github.com/pol4rfuchs/ha-apps/commit/fb20f67271b8a15be190a2861b8035287e4189c2))

## [33.0.8](https://github.com/pol4rfuchs/ha-apps/compare/nextcloud-vv33.0.7...nextcloud-vv33.0.8) (2026-06-15)


### Bug Fixes

* **nextcloud:** update upstream to 34.0.0-apach ([0012865](https://github.com/pol4rfuchs/ha-apps/commit/001286539355baaa7ebf0d40a66d2712f6bce4ae))
* **nextcloud:** update upstream to 34.0.0-apach ([fb20f67](https://github.com/pol4rfuchs/ha-apps/commit/fb20f67271b8a15be190a2861b8035287e4189c2))

## 33.0.5 (2026-06-04)

### Initial release
- Based on official `nextcloud:33.0.5-apache` Docker image (Debian + Apache + PHP)
- Full `apps.nextcloud.com` support — no PHP extension or permission restrictions
- aarch64 and amd64 via native multi-arch CI/CD (no QEMU)
- MariaDB, PostgreSQL, and SQLite backend options
- Configurable trusted domains, PHP memory limit, max upload size, max execution time
- Persistent data layout: `/data/nextcloud/html` (app) + `/data/nextcloud/data` (user files)
- ffmpeg included for preview generation
