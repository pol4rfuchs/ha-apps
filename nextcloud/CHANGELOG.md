# Changelog

## 33.0.5 (2026-06-04)

### Initial release
- Based on official `nextcloud:33.0.5-apache` Docker image (Debian + Apache + PHP)
- Full `apps.nextcloud.com` support — no PHP extension or permission restrictions
- aarch64 and amd64 via native multi-arch CI/CD (no QEMU)
- MariaDB, PostgreSQL, and SQLite backend options
- Configurable trusted domains, PHP memory limit, max upload size, max execution time
- Persistent data layout: `/data/nextcloud/html` (app) + `/data/nextcloud/data` (user files)
- ffmpeg included for preview generation
