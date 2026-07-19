# Changelog

## [0.2.12](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.11...ntfy_manager-v0.2.12) (2026-07-19)


### Bug Fixes

* **ntfy_manager:** add BUILD_FROM/BUILD_ARCH indirection and mandatory io.hass labels ([0654c81](https://github.com/pol4rfuchs/ha-apps/commit/0654c8112db8cf138178d90d4f80cbf3e4acc937))
* **ntfy_manager:** move BUILD_FROM/BUILD_ARCH args before first FROM to fix multi-stage scope ([7e30544](https://github.com/pol4rfuchs/ha-apps/commit/7e305447c4bd0235ef5f60c6118b188b3f98a035))
* **ntfy_manager:** restore swapped Dockerfiles to correct add-on directorie ([418f1a8](https://github.com/pol4rfuchs/ha-apps/commit/418f1a8a6a7062ad59b29a76ab6c145282ac44a0))

## [0.2.11](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.10...ntfy_manager-v0.2.11) (2026-06-29)


### Bug Fixes

* **ntfy_manager:** real logout, clearer admin-role limit, request timeout ([222a9e8](https://github.com/pol4rfuchs/ha-apps/commit/222a9e811089a170a06c925a973067cb4b613c2c))

## [0.2.10](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.9...ntfy_manager-v0.2.10) (2026-06-27)


### Bug Fixes

* **ntfy_manager:** migrate to Tailwind v4 (Vite plugin, CSS-first [@theme](https://github.com/theme)) ([60725a8](https://github.com/pol4rfuchs/ha-apps/commit/60725a85d8a4af454103244a00cdda452a0d319d))

## [0.2.9](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.8...ntfy_manager-v0.2.9) (2026-06-27)


### Bug Fixes

* **ntfy_manager:** update react monorepo to v19 ([#87](https://github.com/pol4rfuchs/ha-apps/issues/87)) ([271b200](https://github.com/pol4rfuchs/ha-apps/commit/271b2002e8d3d88312f5b58e9b297393c1cee293))

## [0.2.8](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.7...ntfy_manager-v0.2.8) (2026-06-27)


### Bug Fixes

* **ntfy_manager:** add missing vite-env.d.ts for TS6 compatibility, bump typescript to v6 ([3b7957d](https://github.com/pol4rfuchs/ha-apps/commit/3b7957de33a2442a118cdffdbfed057dd6b03d7a))
* **ntfy_manager:** align vite to v8 for @vitejs/plugin-react v6 peer dep ([3b7957d](https://github.com/pol4rfuchs/ha-apps/commit/3b7957de33a2442a118cdffdbfed057dd6b03d7a))

## [0.2.7](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.6...ntfy_manager-v0.2.7) (2026-06-27)


### Bug Fixes

* **ntfy_manager:** allow * wildcard in ACL topic patterns ([56516c3](https://github.com/pol4rfuchs/ha-apps/commit/56516c30966c20d608d95221f8ab177edd0f1b38))
* **ntfy_manager:** clipboard fallback for insecure (HTTP) contexts ([56516c3](https://github.com/pol4rfuchs/ha-apps/commit/56516c30966c20d608d95221f8ab177edd0f1b38))

## [0.2.6](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.5...ntfy_manager-v0.2.6) (2026-06-26)


### Bug Fixes

* **ntfy_manager:** update dependency lucide-react to v1 ([#74](https://github.com/pol4rfuchs/ha-apps/issues/74)) ([93c0cd4](https://github.com/pol4rfuchs/ha-apps/commit/93c0cd4530bb56cb41d3abc20cb1120f92379dda))

## [0.2.5](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.4...ntfy_manager-v0.2.5) (2026-06-26)


### Bug Fixes

* **ntfy_manager:** update dependency zod to v4 ([#73](https://github.com/pol4rfuchs/ha-apps/issues/73)) ([772c677](https://github.com/pol4rfuchs/ha-apps/commit/772c6772f4a597544da6bdf752d6b697573200f5))

## [0.2.4](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.3...ntfy_manager-v0.2.4) (2026-06-26)


### Bug Fixes

* **ntfy_manager:** update dependency express to v5 ([#29](https://github.com/pol4rfuchs/ha-apps/issues/29)) ([c7a3150](https://github.com/pol4rfuchs/ha-apps/commit/c7a3150a83a9b1107698bd961fd80552e353735f))

## [0.2.3](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.2...ntfy_manager-v0.2.3) (2026-06-26)


### Bug Fixes

* **ntfy_manager:** update dependency express-rate-limit to v8 ([#67](https://github.com/pol4rfuchs/ha-apps/issues/67)) ([d887628](https://github.com/pol4rfuchs/ha-apps/commit/d887628689f207bfa797af9de39ecb9fa1004dea))

## [0.2.2](https://github.com/pol4rfuchs/ha-apps/compare/ntfy_manager-v0.2.1...ntfy_manager-v0.2.2) (2026-06-26)


### Bug Fixes

* **ntfy_manager:** add rate limiting and CSP configuration ([0b0c4b8](https://github.com/pol4rfuchs/ha-apps/commit/0b0c4b82d7a6d251a29bcedf2df18b59be6dca86))

## 0.2.1 — Bugfixes

### Fixed
- **ESM crash on startup**: multi-stage Docker build copied `apps/api/dist/` into Stage 2
  but omitted `apps/api/package.json`. Node.js could not detect `"type": "module"`
  and crashed with `SyntaxError: Cannot use import statement outside a module`.
  Fixed by adding `COPY --from=builder /opt/ntfy-admin/apps/api/package.json ./apps/api/package.json`
  in Stage 2.
- **openssl version conflict**: `apk add openssl` conflicted with the version already
  present in `ghcr.io/hassio-addons/base:16.3.2` (`libcrypto3`/`libssl3` mismatch).
  Removed `openssl` from explicit `apk add` — it is provided by the base image.
- **AppArmor profile name mismatch**: profile declared as `ntfy_haos_admin_panel` but
  HA Supervisor expects the `local_` prefix for local add-ons (`local_ntfy_haos_admin_panel`).
  Resolved by setting `apparmor: false` in `config.yaml` and removing `apparmor.txt`.

## 0.2.0 — Full rewrite

This is effectively a rewrite. The 0.1.x skeleton was a generic Express+Prisma+SQLite app with no actual ntfy integration. 0.2.0 is a real ntfy admin panel with the same feature surface as the original single-file HTML console.

### Added
- Express backend with typed proxy routes for every ntfy admin endpoint:
  `/v1/health`, `/v1/version`, `/v1/stats`, `/v1/users` (GET/PUT/DELETE),
  `/v1/access` (POST/DELETE), `/v1/account`, `/v1/account/reservation`
  (POST/DELETE — with the correct `{topic, everyone}` body), `/v1/account/token`,
  publish on `/<topic>`.
- React/Tailwind SPA with 9 pages: Overview, Send, Users, Tokens, ACL,
  Reservations, Server, Messages, Debug.
- SSE bridge: browser opens an EventSource on the panel, backend pipes ntfy `/sse` through
  with credentials attached server-side.
- Audit log in-memory ring buffer (no DB).
- AES-256-GCM cookie sessions — ntfy credentials never hit the browser as plaintext.
- Add-on options for ntfy connection: base URL, auth type (none/basic/bearer),
  username/password/bearer token, default topics, override toggle.
- HA `rest_command` YAML snippet generator on the Server page.
- Live message preview on the Send page.
- localStorage-backed topic preferences synced between Messages and Debug pages.

### Changed
- Base image: `ghcr.io/home-assistant/*-base-debian` → `ghcr.io/hassio-addons/base`
  (Alpine + s6-overlay + bashio), matching the rest of the homelab pattern.
- Removed `armv7` from architectures — `aarch64` and `amd64` only.

### Removed
- Prisma + SQLite (`/data/app.db`).
- Local user store (`OWNER/ADMIN/OPERATOR/VIEWER` roles).
- Setup wizard, setup token, owner account creation.
- bcrypt-hashed local passwords.
- Hardcoded `/api/modules` placeholder route.
- Generic `dashboard` route returning `process.uptime()`.

### Fixed
- Topic reservation POST now uses the correct ntfy body shape (the bug from
  the old HTML panel).
