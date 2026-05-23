# Changelog — Matrix Server Addon (ESS CE Style)

All notable changes to this project will be documented in this file.
Alle wesentlichen Änderungen an diesem Projekt werden hier dokumentiert.

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
- Unified Push 
- DE: UnifiedPush Sektion in README.md
- EN: UnifiedPush section in README.md

---

## [1.2.4] — 2026-03-19

### Fixed / Behoben
- EN: Added missing port 8089 (lk-jwt-service) to addon network config
- DE: Fehlenden Port 8089 (lk-jwt-service) zur Addon-Netzwerkkonfiguration hinzugefügt
- EN: NPM_SETUP.md and CHANGELOG.md rewritten in dual language (EN/DE)
- DE: NPM_SETUP.md und CHANGELOG.md auf Dual-Language (EN/DE) umgestellt

---

## [1.2.3] — 2026-03-19

### Fixed / Behoben
- EN: Binary download script (`03-download-binaries.sh`) no longer crashes the container on failure — exits cleanly with warning instead of `exit 1`
- DE: Binary-Download-Script stürzt bei Fehler nicht mehr den Container ab — sauberer Exit mit Warning statt `exit 1`
- EN: When `enable_voice_calls: false`, binary download is skipped entirely (no network requests, no errors)
- DE: Bei `enable_voice_calls: false` wird der Binary-Download vollständig übersprungen
- EN: LiveKit download URL is now read directly from GitHub API asset list instead of being manually constructed
- DE: LiveKit Download-URL wird jetzt direkt aus der GitHub API Asset-Liste gelesen statt manuell konstruiert

---

## [1.2.2] — 2026-03-19

### Fixed / Behoben
- EN: Moved LiveKit server and lk-jwt-service binary downloads from Dockerfile to runtime (`cont-init.d/03-download-binaries.sh`) — GitHub is blocked in the HA build network
- DE: LiveKit Server und lk-jwt-service Binary-Downloads aus dem Dockerfile in die Laufzeit verschoben (`cont-init.d/03-download-binaries.sh`) — GitHub ist im HA Build-Netzwerk geblockt

---

## [1.2.1] — 2026-03-19

### Changed / Geändert
- EN: Replaced UDP port range 50000–60000 with LiveKit built-in TURN (UDP 3478 + TCP 5349) — reduces open ports from 10,000 to 2
- DE: UDP Port-Range 50000–60000 durch LiveKit Built-in TURN (UDP 3478 + TCP 5349) ersetzt — reduziert offene Ports von 10.000 auf 2
- EN: LiveKit config generation updated accordingly in `10-matrix-init.sh`
- DE: LiveKit Config-Generierung in `10-matrix-init.sh` entsprechend aktualisiert

---

## [1.2.0] — 2026-03-19

### Added / Hinzugefügt
- EN: Voice/Video calling via Element Call + LiveKit SFU (MSC3401)
- DE: Voice/Video-Calls via Element Call + LiveKit SFU (MSC3401)
- EN: New config options: `enable_voice_calls`, `livekit_secret`, `element_call_url`, `livekit_url`, `livekit_jwt_url`
- DE: Neue Config-Optionen: `enable_voice_calls`, `livekit_secret`, `element_call_url`, `livekit_url`, `livekit_jwt_url`
- EN: Three new s6 services: `livekit`, `livekit-jwt`, `element-call` — all idle when voice is disabled
- DE: Drei neue s6-Services: `livekit`, `livekit-jwt`, `element-call` — alle inaktiv wenn Voice deaktiviert
- EN: Element Call WebApp downloaded at first start via `05-download-webapps.sh`
- DE: Element Call WebApp wird beim ersten Start via `05-download-webapps.sh` heruntergeladen
- EN: Auto-generated `livekit_secret` persisted in `/data/matrix/.livekit_secret`
- DE: Automatisch generiertes `livekit_secret` wird in `/data/matrix/.livekit_secret` persistent gespeichert
- EN: Synapse homeserver.yaml extended with MSC3266, MSC3401, MSC2285 experimental features
- DE: Synapse homeserver.yaml um MSC3266, MSC3401, MSC2285 Experimental-Features erweitert
- EN: Element Web `config.json` extended with `element_call` section when voice is enabled
- DE: Element Web `config.json` um `element_call`-Sektion erweitert wenn Voice aktiviert

---

## [1.1.0] — 2026-03-10

### Changed / Geändert
- EN: Improved LAN IP detection via `/proc/net/fib_trie`
- DE: Verbesserte LAN-IP-Erkennung via `/proc/net/fib_trie`
- EN: Element Web generates domain-specific `config.*.json` files for correct homeserver routing
- DE: Element Web generiert domain-spezifische `config.*.json` Dateien für korrektes Homeserver-Routing

---

## [1.0.0] — 2026-03-07

### Initial Release / Erstveröffentlichung
- EN: Synapse homeserver with PostgreSQL 15, Element Web, Synapse Admin UI
- DE: Synapse Homeserver mit PostgreSQL 15, Element Web, Synapse Admin UI
- EN: All components self-hosted within a single HA addon
- DE: Alle Komponenten self-hosted in einem einzigen HA Addon
- EN: s6-overlay service management for PostgreSQL, Synapse, Element Web, Synapse Admin
- DE: s6-overlay Service-Management für PostgreSQL, Synapse, Element Web, Synapse Admin
- EN: Optional ntfy UnifiedPush integration
- DE: Optionale ntfy UnifiedPush Integration
- EN: NPM reverse proxy setup documentation included
- DE: NPM Reverse-Proxy Setup-Dokumentation enthalten
