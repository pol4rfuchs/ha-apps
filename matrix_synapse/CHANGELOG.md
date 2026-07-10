# Changelog — Matrix Server Addon (ESS CE Style)

All notable changes to this project will be documented in this file.
Alle wesentlichen Änderungen an diesem Projekt werden hier dokumentiert.

---

## [1.3.11](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.10...matrix_synapse-v1.3.11) (2026-07-10)


### Bug Fixes

* **matrix_synapse:** use legacy-cont-init instead of legacy-services for startup ordering ([fc9453b](https://github.com/pol4rfuchs/ha-apps/commit/fc9453b70419216271e61ca3e386fb6ace2ce3fa))

## [1.3.10](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.9...matrix_synapse-v1.3.10) (2026-07-10)


### Bug Fixes

* **matrix_synapse:** wait for legacy-cont-init before starting services ([f1aa910](https://github.com/pol4rfuchs/ha-apps/commit/f1aa910cc76bf4e996c3018c508064d98a437698))

## [1.3.9](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.8...matrix_synapse-v1.3.9) (2026-07-08)


### Bug Fixes

* **matrix_synapse:** stop logging registration_shared_secret in plaintext ([8f463e8](https://github.com/pol4rfuchs/ha-apps/commit/8f463e88d2ea3f6c72edafa4cbb5053d63996720))

## [1.3.8](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.7...matrix_synapse-v1.3.8) (2026-07-06)


### Bug Fixes

* **matrix_synapse:** expose LiveKit TURN relay range, shrink from 10000 to 21 ports ([a0f5022](https://github.com/pol4rfuchs/ha-apps/commit/a0f50223650e27685992ba468f03c65f105954dc))
* **version-sync:** repair matrix_synapse entry, add Synapse badge tracking ([a0f5022](https://github.com/pol4rfuchs/ha-apps/commit/a0f50223650e27685992ba468f03c65f105954dc))

## [1.3.7](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.6...matrix_synapse-v1.3.7) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** detect real LAN IP via Supervisor Network API + document secure-context limitation ([5e0638f](https://github.com/pol4rfuchs/ha-apps/commit/5e0638f830058465f85ac8794e11cb0f4bcd449a))

## [1.3.6](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.5...matrix_synapse-v1.3.6) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** fix Element Web/Call base_url pointing to wrong port ([8c71c7e](https://github.com/pol4rfuchs/ha-apps/commit/8c71c7e27f339b695a8ceecebe1fb808fdbfc5b6))

## [1.3.5](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.4...matrix_synapse-v1.3.5) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** fix synapse-admin/element-web/element-call services waiting on removed marker files ([f585627](https://github.com/pol4rfuchs/ha-apps/commit/f5856275fa8ae1ac24696f5d9cf16829d27c38c4))

## [1.3.4](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.3...matrix_synapse-v1.3.4) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** set LIVEKIT_FULL_ACCESS_HOMESERVERS for lk-jwt-service ([80d1ff5](https://github.com/pol4rfuchs/ha-apps/commit/80d1ff5cf569df320b2e3e1374b7178b8616c439))

## [1.3.3](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.2...matrix_synapse-v1.3.3) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** pin pyOpenSSL to fix Synapse startup crash ([f060cb3](https://github.com/pol4rfuchs/ha-apps/commit/f060cb37b6bcb0e0b7a3da59652adafec7c33faa))

## [1.3.2](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.1...matrix_synapse-v1.3.2) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** fix Ketesa extraction crashing the container ([c2142b6](https://github.com/pol4rfuchs/ha-apps/commit/c2142b686a3309e64d53b9edc9474926bdf5cd9e))

## [1.3.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.0...matrix_synapse-v1.3.1) (2026-07-04)


### Bug Fixes

* **matrix_synapse:** version-aware auto-update for LiveKit binaries ([9f03c50](https://github.com/pol4rfuchs/ha-apps/commit/9f03c505272f9654a60b6b31556e1e6edebf68d3))

## [1.3.0](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.2.11...matrix_synapse-v1.3.0) (2026-07-04)


### Features

* **matrix_synapse:** version-aware auto-update for embedded webapps ([dc2d191](https://github.com/pol4rfuchs/ha-apps/commit/dc2d19189dd00984d401e85fc4eeec10c982b79b))

## [1.2.11] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.10] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.9] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.8] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.7] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.6] — 2026-05-xx

### Changed / Geändert
- <!-- Eintrag fehlt – bitte nachtragen -->

---

## [1.2.5] — 2026-03-20

### Fixed / Behoben
- DE: `push: include_content: true` wird jetzt bedingungslos in homeserver.yaml geschrieben (vorher nur wenn `ntfy_url` gesetzt) — gilt für alle Push-Methoden
- EN: `push: include_content: true` is now written unconditionally to homeserver.yaml (previously only when `ntfy_url` was set) — applies to all push methods
- DE: `ntfy_url` wird nicht mehr nur geloggt und verworfen, sondern für einen echten Erreichbarkeitscheck des Matrix Push Gateways verwendet
- EN: `ntfy_url` is no longer just logged and discarded — it's now used for a real connectivity check of the Matrix Push Gateway
- DE: Startet bei erreichbarem Gateway eine Schritt-für-Schritt Anleitung im Log
- EN: On reachable gateway, prints step-by-step UnifiedPush setup instructions in the log

### Added / Hinzugefügt
- DE: `translations/en.yaml` mit korrekten Feldbeschreibungen für alle Config-Optionen
- EN: `translations/en.yaml` with correct field descriptions for all config options
