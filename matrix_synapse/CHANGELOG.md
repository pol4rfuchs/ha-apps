# Changelog — Matrix Server Addon (ESS CE Style)

All notable changes to this project will be documented in this file.
Alle wesentlichen Änderungen an diesem Projekt werden hier dokumentiert.

---

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
