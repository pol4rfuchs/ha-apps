# Changelog — Matrix Server Addon (ESS CE Style)

All notable changes to this project will be documented in this file.
Alle wesentlichen Änderungen an diesem Projekt werden hier dokumentiert.

---

## [1.7.4](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.7.3...matrix_synapse-v1.7.4) (2026-09-06)


### Bug Fixes

* **matrix_synapse:** update dependency matrix-synapse to v1.160.0 ([#355](https://github.com/pol4rfuchs/ha-apps/issues/355)) ([7ac680d](https://github.com/pol4rfuchs/ha-apps/commit/7ac680dd5a33ca0446447b9bbd2ce001f3c64a8f))

## [1.7.3](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.7.2...matrix_synapse-v1.7.3) (2026-09-04)


### Bug Fixes

* **matrix_synapse:** add livekit_turn_enabled toggle, default direct SFU UDP path ([8a74461](https://github.com/pol4rfuchs/ha-apps/commit/8a744615cc7b65164fd5150c06d475c1e96f130e))

## [1.7.2](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.7.1...matrix_synapse-v1.7.2) (2026-08-23)


### Bug Fixes

* **matrix_synapse:** update dependency matrix-synapse to v1.159.0 ([#327](https://github.com/pol4rfuchs/ha-apps/issues/327)) ([2cbeb9d](https://github.com/pol4rfuchs/ha-apps/commit/2cbeb9d89ed5e0be75e718d79057620a840ca5b7))

## [1.7.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.7.0...matrix_synapse-v1.7.1) (2026-08-15)


### Bug Fixes

* **matrix_synapse:** add signal_bridge_enabled and telegram_bridge_enabled toggles ([28ef47f](https://github.com/pol4rfuchs/ha-apps/commit/28ef47fde75a46449f9557655d3d602c9757e592))

## [1.7.0](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.6.1...matrix_synapse-v1.7.0) (2026-08-15)


### Features

* **matrix_synapse:** add whatsapp_bridge_enabled toggle ([468a481](https://github.com/pol4rfuchs/ha-apps/commit/468a4811034cf584ad9b3344ab0210a2cbfcd627))

## [1.6.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.6.0...matrix_synapse-v1.6.1) (2026-08-09)


### Bug Fixes

* **matrix-synapse:** distinguish signal-based shutdown from real crashes in finish scripts ([71485f9](https://github.com/pol4rfuchs/ha-apps/commit/71485f9fdacce2f6b84db9d91fd891bfcb366d44))

## [1.6.0](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.7...matrix_synapse-v1.6.0) (2026-08-09)


### Features

* **matrix-synapse:** add MAS delegation support (mas_enabled/mas_endpoint/mas_secret) ([d883524](https://github.com/pol4rfuchs/ha-apps/commit/d88352426686d5f200e086ced784a5a3ca8d318f))

## [1.5.7](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.6...matrix_synapse-v1.5.7) (2026-08-08)


### Bug Fixes

* **matrix-synapse:** correct backup_exclude path and add postgres-backup finish script ([696e698](https://github.com/pol4rfuchs/ha-apps/commit/696e698818e6f3121c2c6a71b4aae0cd27af5ab7))

## [1.5.6](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.5...matrix_synapse-v1.5.6) (2026-08-08)


### Bug Fixes

* **matrix-synapse:** honor enable_synapse_admin toggle ([5bc74b7](https://github.com/pol4rfuchs/ha-apps/commit/5bc74b701fc9aa1f858cb054732129743f324cad))

## [1.5.5](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.4...matrix_synapse-v1.5.5) (2026-08-05)


### Bug Fixes

* **matrix_synapse:** update dependency matrix-synapse to v1.158.0 ([#278](https://github.com/pol4rfuchs/ha-apps/issues/278)) ([bce78e2](https://github.com/pol4rfuchs/ha-apps/commit/bce78e251dac0be849ac01029e204ae1313f8943))

## [1.5.4](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.3...matrix_synapse-v1.5.4) (2026-07-31)


### Bug Fixes

* **matrix_synapse:** update dependency matrix-synapse to v1.157.2 ([#243](https://github.com/pol4rfuchs/ha-apps/issues/243)) ([d092b75](https://github.com/pol4rfuchs/ha-apps/commit/d092b7549204f35851a3cd572b22d4f91c525b53))

## [1.5.3](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.2...matrix_synapse-v1.5.3) (2026-07-23)


### Bug Fixes

* **matrix_synapse:** update dependency matrix-synapse to v1.157.1 ([#204](https://github.com/pol4rfuchs/ha-apps/issues/204)) ([7dc6b31](https://github.com/pol4rfuchs/ha-apps/commit/7dc6b31ef8b90a301e2ee1c94dd8ffd5932cf388))

## [1.5.2](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.1...matrix_synapse-v1.5.2) (2026-07-23)


### Bug Fixes

* **matrix_synapse:** add de.yaml, draft apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix and deprecated hassio_api field ([c2f9bc1](https://github.com/pol4rfuchs/ha-apps/commit/c2f9bc1389d715c3c7202a4c93650655d6e02708))

## [1.5.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.5.0...matrix_synapse-v1.5.1) (2026-07-19)


### Bug Fixes

* **matrix_synapse:** add BUILD_FROM/BUILD_ARCH indirection and mandatory io.hass labels ([b7a9e3e](https://github.com/pol4rfuchs/ha-apps/commit/b7a9e3e9f8ce4cbb380749608f0cd5808fa81c93))

## [1.5.0](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.4.4...matrix_synapse-v1.5.0) (2026-07-18)


### Features

* **matrix_synapse:** admin UI auth, media retention, backups, rate limiting ([9cede50](https://github.com/pol4rfuchs/ha-apps/commit/9cede508966baedf87637a838aa04f50bfbfd93c))

## [1.4.4](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.4.3...matrix_synapse-v1.4.4) (2026-07-16)


### Bug Fixes

* **matrix_synapse:** use public LiveKit URL for lk-jwt-service client config ([cd2ca53](https://github.com/pol4rfuchs/ha-apps/commit/cd2ca53465223ebdac4db3f0caf98ffcdca47464))

## [1.4.3](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.4.2...matrix_synapse-v1.4.3) (2026-07-14)


### Bug Fixes

* **matrix_synapse:** rtc_foci discovery + ntfy pusher IP whitelist ([965c0c9](https://github.com/pol4rfuchs/ha-apps/commit/965c0c95cf3e58365ea280c122754a6cd4d55c87))

## [1.4.2](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.4.1...matrix_synapse-v1.4.2) (2026-07-14)


### Bug Fixes

* **matrix_synapse:** rtc_foci discovery + ntfy pusher IP whitelist ([21f5a0e](https://github.com/pol4rfuchs/ha-apps/commit/21f5a0e13aa06c0c4b8fcd1067c8311a81c5237e))

## [1.4.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.4.0...matrix_synapse-v1.4.1) (2026-07-11)


### Reverts

* **matrix_synapse:** remove msc4108_enabled, breaks Synapse startup ([594f3f0](https://github.com/pol4rfuchs/ha-apps/commit/594f3f012f7d2673ff31597c41a9d4428a313a0a))

## [1.4.0](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.12...matrix_synapse-v1.4.0) (2026-07-11)


### Features

* **matrix_synapse:** enable QR code login (MSC4108) ([361e515](https://github.com/pol4rfuchs/ha-apps/commit/361e51576f902206ba9aa85086d510016d102713))

## [1.3.12](https://github.com/pol4rfuchs/ha-apps/compare/matrix_synapse-v1.3.11...matrix_synapse-v1.3.12) (2026-07-10)


### Bug Fixes

* **matrix_synapse:** fix Supervisor Network API LAN-IP detection ([d4a56e9](https://github.com/pol4rfuchs/ha-apps/commit/d4a56e9fff7235c42bb90a3edcc06274fed3fa3b))

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

## [1.2.11] — 2026-05-30

### Fixed / Behoben
- DE: `config.yaml` `map:`-Schema auf die von HA Supervisor geforderte Extended-Object-Form umgestellt (`config:rw`/`media:rw`/`data:rw` → `type: homeassistant_config`/`type: media` mit `read_only: false`); `data:rw` komplett entfernt, da `/data` jedem Add-on ohnehin automatisch zur Verfügung steht
- EN: `config.yaml` `map:` schema migrated to the extended-object form required by HA Supervisor (`config:rw`/`media:rw`/`data:rw` → `type: homeassistant_config`/`type: media` with `read_only: false`); `data:rw` removed entirely since `/data` is always available to every add-on
- DE: Default-Werte-Felder aus `config.yaml` entfernt (`homeassistant_api`, `hassio_role`, `boot`) — Linter-Regel: Felder, die bereits dem Supervisor-Default entsprechen, sollen nicht explizit gesetzt werden
- EN: Removed default-value fields from `config.yaml` (`homeassistant_api`, `hassio_role`, `boot`) — linter rule: fields matching the Supervisor default should not be set explicitly
- DE: `ingress: true` → `ingress: false` + `webui: http://[HOST]:[PORT:7080]` — Element Web ist eine SPA mit absoluten Asset-Pfaden; HA Ingress hängt einen Pfad-Präfix an, der sämtliches JS/CSS-Laden bricht (weißer Bildschirm in der Sidebar)
- EN: `ingress: true` → `ingress: false` + `webui: http://[HOST]:[PORT:7080]` — Element Web is an SPA with absolute asset paths; HA Ingress adds a path prefix that breaks all JS/CSS asset loading (white screen in sidebar)

---

## [1.2.10] — 2026-03-xx

### Fixed / Behoben
- DE: `LK_DOMAIN: unbound variable` behoben — Variable wurde erst im LiveKit-Config-Block gesetzt, aber vom TURN-Block in der Synapse-Config schon früher gebraucht. Wird jetzt direkt nach den Config-Variablen abgeleitet, bevor irgendein Block darauf zugreift
- EN: Fixed `LK_DOMAIN: unbound variable` — the variable was only set in the LiveKit config block, but needed earlier by the Synapse TURN block. Now derived immediately after the config variables, before any block accesses it

---

## [1.2.9] — 2026-03-xx

### Fixed / Behoben
- DE: lk-jwt-service Port-Bindung repariert — `PORT=8089` (falsche Env-Var) → `LIVEKIT_JWT_BIND=":8089"` (die tatsächlich erwartete Variable). Service lauschte vorher auf dem falschen Port
- EN: Fixed lk-jwt-service port binding — `PORT=8089` (wrong env var) → `LIVEKIT_JWT_BIND=":8089"` (the actually expected variable). Service was previously listening on the wrong port
- DE: Legacy Call Dialog ("falsch konfigurierter Server") in Element Web behoben — Synapse bekommt jetzt einen `turn_uris`-Block mit dem LiveKit-TURN-Secret
- EN: Fixed legacy call dialog ("improperly configured server") in Element Web — Synapse now gets a `turn_uris` block with the LiveKit TURN secret
- DE: LiveKit Crash-Loop behoben — `livekit/run` wartet jetzt explizit, bis `livekit.yaml` frisch durch cont-init geschrieben wurde (+ 3s Puffer), statt eine evtl. veraltete Config zu lesen
- EN: Fixed LiveKit crash loop — `livekit/run` now explicitly waits until `livekit.yaml` has been freshly written by cont-init (+ 3s buffer), instead of potentially reading a stale config

---

## [1.2.8] — 2026-03-xx

### Fixed / Behoben
- DE: LiveKit startete nicht ohne TLS-Zertifikat — `tls_port`/`cert_file`/`key_file` aus der generierten `livekit.yaml` entfernt, läuft jetzt nur mit TURN UDP 3478
- EN: LiveKit failed to start without a TLS certificate — removed `tls_port`/`cert_file`/`key_file` from the generated `livekit.yaml`, now runs with TURN UDP 3478 only
- DE: lk-jwt-service startete nicht — falsche Env-Var-Namen (`LIVEKIT_API_KEY`/`LIVEKIT_API_SECRET` → `LIVEKIT_KEY`/`LIVEKIT_SECRET`, die tatsächlich von lk-jwt-service erwarteten Namen)
- EN: lk-jwt-service failed to start — wrong env var names (`LIVEKIT_API_KEY`/`LIVEKIT_API_SECRET` → `LIVEKIT_KEY`/`LIVEKIT_SECRET`, the names actually expected by lk-jwt-service)

---

## [1.2.7] — 2026-03-xx

### Fixed / Behoben
- DE: LiveKit Binary-Download schlug fehl — falscher GitHub-Repo-Name in der Download-URL (`livekit/livekit-server` → `livekit/livekit`)
- EN: LiveKit binary download failed — wrong GitHub repo name in the download URL (`livekit/livekit-server` → `livekit/livekit`)

---

## [1.2.6] — 2026-03-xx

### Fixed / Behoben
- DE: LiveKit-Download-Script auf direkte URL-Konstruktion umgestellt (`livekit_VERSION_linux_ARCH.tar.gz`) statt fragilem Asset-Parsing per `jq` — behebt Null-Ergebnisse bei API-Strukturänderungen. GitHub API wird nur noch für die Versionsnummer befragt, mit Fallback auf eine feste Version bei Nichterreichbarkeit
- EN: LiveKit download script switched to direct URL construction (`livekit_VERSION_linux_ARCH.tar.gz`) instead of fragile `jq`-based asset parsing — fixes null results on API structure changes. GitHub API is now only queried for the version number, with a fallback to a fixed version if unreachable
- DE: `livekit/run` und `livekit-jwt/run` warten jetzt aktiv, bis die jeweilige Binary existiert und ausführbar ist, bevor gestartet wird — behebt Crash-Loop bei langsamem/fehlgeschlagenem Download
- EN: `livekit/run` and `livekit-jwt/run` now actively wait until their respective binary exists and is executable before starting — fixes crash loop on slow/failed downloads

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
