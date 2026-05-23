# Changelog

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
