# Changelog — Matrix Server Addon (ESS CE Style)

All notable changes to this project will be documented in this file.
Alle wesentlichen Änderungen an diesem Projekt werden hier dokumentiert.

---

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
