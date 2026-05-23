# Changelog

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
