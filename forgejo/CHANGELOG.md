# Changelog

## [16.0.11](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.10...forgejo-v16.0.11) (2026-08-01)


### Bug Fixes

* **forgejo:** update upstream to 16.0.2 ([#254](https://github.com/pol4rfuchs/ha-apps/issues/254)) ([68da4a4](https://github.com/pol4rfuchs/ha-apps/commit/68da4a4b81eca1764416cc6c1872951f05079190))

## [16.0.10](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.9...forgejo-v16.0.10) (2026-07-25)


### Bug Fixes

* **forgejo:** update upstream to 16.0.1 ([#227](https://github.com/pol4rfuchs/ha-apps/issues/227)) ([c92aa96](https://github.com/pol4rfuchs/ha-apps/commit/c92aa96297c08f0807c045a6a981ff00325913b4))

## [16.0.9](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.8...forgejo-v16.0.9) (2026-07-23)


### Bug Fixes

* **forgejo:** correct swapped en/de translations, add DOCS.md, --- header, drop -ha-app suffix, fix stale build.yaml reference in README ([c8dece9](https://github.com/pol4rfuchs/ha-apps/commit/c8dece97f0881af934af01d938814cb67cf2c3de))

## [16.0.8](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.7...forgejo-v16.0.8) (2026-07-21)


### Bug Fixes

* **forgejo:** update upstream to 16.0.0 ([#193](https://github.com/pol4rfuchs/ha-apps/issues/193)) ([202a50a](https://github.com/pol4rfuchs/ha-apps/commit/202a50af6e96f7c89cb9ad494b49b8f013f1faba))

## [16.0.7](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.6...forgejo-v16.0.7) (2026-07-19)


### Bug Fixes

* **forgejo:** add missing s6-overlay baseline paths to apparmor profile and re-enable apparmor ([45a39f9](https://github.com/pol4rfuchs/ha-apps/commit/45a39f9bdbd5cbef89725c67eb92e276445754fc))

## [16.0.6](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.5...forgejo-v16.0.6) (2026-07-13)


### Bug Fixes

* **forgejo:** update upstream to 15.0.4 ([#169](https://github.com/pol4rfuchs/ha-apps/issues/169)) ([29c83e4](https://github.com/pol4rfuchs/ha-apps/commit/29c83e4a49da0ef2852ab9a362b0e45a42c62e88))

## [16.0.5](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.4...forgejo-v16.0.5) (2026-06-20)


### Bug Fixes

* **forgejo:** sync version field to 16.0.4 ([7ebc916](https://github.com/pol4rfuchs/ha-apps/commit/7ebc91611cdb009641909a0e87b4dbd4090a911e))

## [16.0.4](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.3...forgejo-v16.0.4) (2026-06-20)


### Bug Fixes

* **forgejo:** disable apparmor to fix /init permission denied ([6c55409](https://github.com/pol4rfuchs/ha-apps/commit/6c55409ebedaa4a5f69c1b94b8333f13bbfb7213))

## [16.0.3](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.2...forgejo-v16.0.3) (2026-06-16)


### Bug Fixes

* **forgejo:** remove deprecated and invalid config fields ([0c15c83](https://github.com/pol4rfuchs/ha-apps/commit/0c15c839b3b5507fc57e876c07306fe6b854431f))
* **forgejo:** update upstream to 15.0.3 ([56a191c](https://github.com/pol4rfuchs/ha-apps/commit/56a191c3cc6908d96bd12921764b69e121eba7f6))
* **forgejo:** update upstream to 15.0.3 ([edc5066](https://github.com/pol4rfuchs/ha-apps/commit/edc50660ac6d1e9939cab5846ad382b6e6be286d))

## [16.0.2](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-vv16.0.1...forgejo-vv16.0.2) (2026-06-15)


### Bug Fixes

* **forgejo:** remove deprecated and invalid config fields ([0c15c83](https://github.com/pol4rfuchs/ha-apps/commit/0c15c839b3b5507fc57e876c07306fe6b854431f))

## [16.0.1](https://github.com/pol4rfuchs/ha-apps/compare/forgejo-v16.0.0...forgejo-vv16.0.1) (2026-06-15)


### Bug Fixes

* **forgejo:** update upstream to 15.0.3 ([56a191c](https://github.com/pol4rfuchs/ha-apps/commit/56a191c3cc6908d96bd12921764b69e121eba7f6))
* **forgejo:** update upstream to 15.0.3 ([edc5066](https://github.com/pol4rfuchs/ha-apps/commit/edc50660ac6d1e9939cab5846ad382b6e6be286d))

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
