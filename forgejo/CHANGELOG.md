# Changelog

## [16.0.0] – 2026-05-14

### Features
- Initiale Veröffentlichung – Forgejo v16 (aktuellste Version)
- Plattformen: amd64 + aarch64 (Raspberry Pi 4 & 5)
- HA Ingress-Integration mit dynamischer URL-Erkennung via Supervisor API
- Multi-Stage Dockerfile (HA-Base + Forgejo Binary)
- SSH Git-Zugriff mit persistenten Host-Keys
- SSL/TLS Unterstützung
- AppArmor Sicherheitsprofil
- s6-overlay Service-Architektur (korrekte HA-Integration)
- Konfiguration via FORGEJO__-Umgebungsvariablen + environment-to-ini
- Persistente Daten in addon_config (/config)
- GitHub Actions CI/CD: Codeberg → GitHub → GHCR Pipeline
