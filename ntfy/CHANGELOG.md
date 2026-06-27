## 1.1.6.6 — 2026-04-25 (ntfy 2.22.0)

- Candidate update to ntfy `2.22.0`.
- Upstream release: [v2.22.0](https://github.com/binwiederhier/ntfy/releases/tag/v2.22.0)
- Safety: this version is generated on branch `auto/ntfy-v2.22.0` first. Home Assistant does not see it until merged into `main`.

# Changelog

---

## [1.1.9](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.1.8...ntfy-v1.1.9) (2026-06-27)


### Bug Fixes

* **ntfy:** update upstream to 2.25.0 ([#78](https://github.com/pol4rfuchs/ha-apps/issues/78)) ([7b45c30](https://github.com/pol4rfuchs/ha-apps/commit/7b45c3081dd92ad06d7449b5cff1dfe09f32db49))

## 1.1.6.4 > 1.1.6.5 — 2026-03-20

- matrix integration for unified push


## 1.1.5 > 1.1.6.4 — 2026-03-07

**Reservation (Root Cause):**
- `loadReservations()` — `GET /v1/account/reservation` → `GET /v1/account`, data read from `data.reservations`
- `fetchTopicsFromServer()` — same fix applied, stale 404 guard removed
- `PUT` and `DELETE` with topic path were already correct per ntfy source

**Entity Rendering (3 locations):**
- `toast()` — `textContent` → `innerHTML` so HTML entities render correctly
- `toggleDbgBody()` — `textContent` → `innerHTML` so ▶/▼ arrows render correctly
- `renderDebugStats()` — `'&#8212;'` → `'\u2014'` since `textContent` does not parse HTML entities
- try to fix topic reservation & run.sh reservation fixes true cause = GET /v1/account/reservation in ntfy's API

## 1.1.3 > 1.1.4 — 2026-03-06

### Hotfixes admin panel & run.sh
- "cloud-only" — wrong term > correct Config-Flag
- fetchTopicsFromServer() has no 404-Check
- run.sh fixes
  
## 1.0.1.6 > 1.1.2 — 2026-03-04 Huge Update

### Admin Panel — New Views
- **Access Control (ACL)** — view, create and delete per-user per-topic access rules via `POST/DELETE /v1/access`. Wildcard topics supported (`ha-*`, `*`). Color-coded permission badges. User dropdown auto-populated from live user list, resets on logout.
- **Topic Reservations** — reserve topics to your admin account via `PUT/DELETE /v1/account/reservation`. Prevents unauthorized clients from publishing to HA notification topics.
- **Message Browser** — polls `GET /{topic}/json?poll=1` in parallel for all configured topics. Filter by time range (1h / 6h / 24h / all) and limit (25 / 50 / 100 / 250). Stats bar: total / topics hit / high-priority / last seen. Message cards with priority badge, tags, click URL. Per-topic errors shown separately.
- **Topic Settings** — `⚙ Topic Settings` in sidebar. Topics stored in `localStorage` under `ntfy_topics`. On first login: auto-fetches from `GET /v1/account/reservation` — if reservations found, modal opens pre-filled with toast "Found X reserved topic(s)"; if none, modal opens empty for manual entry. From second login onwards: modal skipped, topics applied silently.
- **Debug — SSE Connection Monitor** — live Server-Sent Events stream to any topics. Connection state, reconnect counter, connects / disconnects / messages seen counters, live event log.
- **Debug — API Call Log** — records every admin panel API call with method, URL, HTTP status and response body. "Run diagnostics" probes all main endpoints at once.
  
### Admin Panel — Improvements
- Live search bar filters across Users, ACL, Reservations, Messages and Debug log simultaneously — cleared automatically on view switch
- Send tab: live preview updates in real time as you type
- Send tab: Policy & Routing card loads live server connection info after login
- Server tab: auto-generated `rest_command` YAML uses actual connected server URL
- Sidebar: direct ntfy link + white-screen warning shown after login
- Tokens tab: CORS limitation explained clearly with direct "Open ntfy UI" link; token clipboard copy shows explicit confirmation toast with fallback if clipboard unavailable
- All static placeholder data removed — every view is fully live from the ntfy API
- All remaining German UI text translated to English
- Default SSE/Message Browser topics pre-filled: `ha-alerts, ha-info, ha-notify, ha-system, ha-planty`
- Small bugfixes for the admin panel applied

### Backend — Token Auto-Provisioning
- On first startup, an API token is automatically created for the admin user with label `"Home Assistant"`
- Token saved to `/data/ntfy/ha_token.txt` (chmod 600, included in HA backups)
- Token printed clearly in the add-on log on first start
- Subsequent restarts detect the existing file and skip creation — no duplicate tokens
- Delete `ha_token.txt` and restart to regenerate

### Backend — CLI Environment
- `ENV NTFY_AUTH_FILE=/data/ntfy/user.db` set at image level — applies to all processes including manual `docker exec` sessions
- `/etc/profile.d/ntfy.sh` added — every interactive shell gets `NTFY_AUTH_FILE` automatically plus three non-interactive wrapper functions:
  - `ntfy_adduser <user> <pass> [role]` — create user without password prompt
  - `ntfy_passwd <user> <pass>` — change password without password prompt
  - `ntfy_token <user> [label]` — create token

### Documentation
- `DOCS.md` fully rewritten to reflect current feature set
- Added: Token Auto-Provisioning, CLI Access, ACL, Reservations, Message Browser, Debug tabs
- Added: `ha_token.txt` to backup table
- Removed: outdated workarounds and CLI limitation notes (now fixed)

---

## 1.0.1.6 — Admin Dashboard

### Fixed
- Auth DB fixes for admin user detection
- `GET /v1/account/token` returning HTTP 404 in debug panel — documented as expected (admin-wide token listing not available via REST API)
- Default SSE topics set to `ha-alerts, ha-info, ha-notify, ha-system, ha-planty`

---

## 1.0.1.5 — Admin Dashboard

### Fixed
- Several dashboard issues fixed

---

## 1.0.1.4 — Admin Dashboard

### Fixed
- Dashboard issues with buttons and placeholder data removed

---

## 1.0.1.3 — Admin Panel Redesign

### Changed
- Admin panel completely redesigned — enterprise green color scheme with DevOps/terminal aesthetic
- All font sizes increased for better readability
- Improved layout consistency across all sections

### Fixed
- Stat values on dashboard now correctly reflect server state colors

### Notes
- ⚠️ Do not use the HA sidebar link — use the direct URL: `http://<host>:4280`

---

## 1.0.1.2 — Admin Panel Fixes

### Fixed
- Admin panel fixes and readability improvements

---

## 1.0.1.1 — Admin Panel Frontend Overhaul

### Changed
- Admin panel frontend reworked
- Improved form layout and button styles

---

## 1.0.0 — Initial Release

### Features
- ntfy v2.17.0 — self-hosted pub-sub notification service
- Multi-architecture support: `amd64`, `aarch64`
- Automatic admin account creation on startup via `admin_username` / `admin_password` config
- Admin Panel (port `4281`) with user management UI — create/delete users, change passwords, create tokens, send test messages, `rest_command` example generator
- CORS support for admin panel ↔ ntfy API communication
- HA backup integration — all data stored in `/data/ntfy/`
- GitHub Actions workflow for automatic ntfy version updates

### Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `log_level` | `INFO` | `TRACE` / `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `base_url` | — | External URL for attachments and iOS push |
| `behind_proxy` | `false` | X-Forwarded-For support |
| `auth_default_access` | `deny-all` | `deny-all` / `read-only` / `write-only` / `read-write` |
| `enable_signup` | `true` | Allow self-registration |
| `enable_login` | `true` | Allow login |
| `enable_reservations` | `false` | Allow topic reservations |
| `cache_duration` | `12h` | Message cache lifetime |
| `upstream_base_url` | — | iOS push via ntfy.sh |
| `admin_panel` | `false` | Enable/disable admin panel |
| `admin_username` | — | Bootstrap admin username |
| `admin_password` | — | Bootstrap admin password |

### Known Limitations
- ntfy Web UI not compatible with HA Ingress — use direct URL on port `:4280`
- Token list not available in admin panel due to browser CORS restriction (port `4281` → `4280`)
- Role changes for existing users not supported by ntfy v2 API
- Admin accounts cannot be deleted or modified via API — manage via add-on config only
- `NTFY_AUTH_FILE` must be set manually in `docker exec` sessions — *(fixed in 1.1)*
- Token auto-provisioning not available — *(fixed in 1.1)*
- ACL management CLI-only — *(fixed in 1.1)*
