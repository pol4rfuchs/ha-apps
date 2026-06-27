# ntfy HAOS Admin Panel — Documentation

## Quick start

1. Install add-on, leave defaults.
2. If you already have an admin user on your ntfy add-on, fill `ntfy_username` and `ntfy_password` here.
3. Start.
4. Open the sidebar panel → you're in.

If you don't fill credentials, you'll see a login screen — type any ntfy user there.

## Add-on options

### ntfy_base_url
URL of your ntfy add-on, as reachable from this add-on's container. Defaults to `http://homeassistant.local:4280`.

If both add-ons run on the same Supervisor, the Docker-internal hostname `http://a0d7b954-ntfy:80` may be faster, but the default works fine.

### ntfy_auth_type
- `none` — anonymous, only works if your ntfy server allows anonymous read.
- `basic` — username + password (recommended).
- `bearer` — for token-based auth.

### Credentials
- For `basic`: fill `ntfy_username` + `ntfy_password`.
- For `bearer`: fill `ntfy_bearer_token`.

### default_topics
List of topics shown by default in the Message Browser and the SSE Monitor. The user can override these in the panel; changes persist in the browser's localStorage.

### allow_login_override
If `true`, users can log in with different credentials via the panel UI. Set to `false` for kiosk-mode setups where only the configured account should be used.

## How auth works

The panel never asks Home Assistant who you are. It uses ntfy for that.

When you log in (or when defaults from this add-on's config are picked up), the backend builds an `Authorization` header (`Basic …` or `Bearer …`), validates it against `GET /v1/account`, and if ntfy says it's good, encrypts those credentials into an httpOnly cookie. The cookie lives 12 hours.

Every API call you make from the panel hits this add-on's Express backend, which decrypts the cookie, attaches the header, and forwards to ntfy.

The ntfy `user.db` is the only source of truth. There's no second user store.

## Page reference

### Overview
Live snapshot: server health, version, lifetime message count, user count. Auto-refreshes uptime every second; refetches data when you hit the **Refresh** button in the top bar.

### Send
Compose a notification. Topic + Title + Priority (1–5) + Tags + Click-URL. The right-hand preview updates as you type.

### Users
Lists all ntfy users. Create new ones (PUT `/v1/users`), change passwords (PUT same endpoint with new password), delete non-admin users (DELETE `/v1/users`).

Admin users can't be deleted from the panel — they're managed via your ntfy server config.

### Tokens
Create new API tokens. ntfy's REST API doesn't expose existing tokens server-wide, so the listing has to happen in ntfy's own web UI. We show a clear notice and link there. Newly created tokens are displayed once with a copy button.

### Access Control
Lists ACL grants per user/topic. Add new rules with the right-hand form. Topics support the `*` wildcard anywhere in the pattern (e.g. `ha-*` matches all topics starting with `ha-`), same as ntfy's own `ntfy access` CLI command.

### Reservations
Topic reservations for the current account. Reserved topics can be configured to allow or deny access for everyone else.

> **Note:** ntfy expects the body shape `{topic, everyone}` for `POST /v1/account/reservation` — putting the topic in the URL path returns 404. The panel uses the correct shape.

### Server
Static info + a generator for a `rest_command` YAML snippet you can paste into Home Assistant's `configuration.yaml`.

### Messages
Polls multiple topics' message caches in parallel. Stats: total / topics / high-prio / latest-time. Filter via the search bar at the top.

The "Topics" button opens a modal where you can edit the comma-separated topic list — saved per-browser via localStorage.

### Debug
**SSE Monitor** — opens a server-sent-events stream against ntfy `/sse`, proxied through this add-on's backend so credentials never leave the cookie. Auto-reconnects on disconnect.

**Audit Log** — in-memory ring buffer (max 500 entries). Logs API actions like user created, ACL changed, reservation removed. Cleared on add-on restart; mirrored to Supervisor log via console.

## Known Limitations

These are ntfy API limitations, not bugs in this panel — they applied to the old built-in ntfy admin panel too and will apply to any UI built on top of the same API.

- **Token listing** — ntfy's REST API has no endpoint to list a user's existing tokens. Create new ones here; view/revoke existing ones in the ntfy Web UI → Account → Access Tokens.
- **Role changes** — ntfy's API has no endpoint to change an existing user's role. To promote someone to admin, recreate them with `role: admin`, or set them as `admin_username` in the ntfy add-on's own config.
- **Admin accounts** — ntfy returns 401 on delete/modify for admin-role accounts via the API. Manage admin accounts through the ntfy add-on's configuration instead.
- **ntfy's own Web UI and HA Ingress** — opening the "Open ntfy web UI" link takes you to ntfy's own interface (port `4280` directly, not through Ingress). ntfy's SPA uses absolute asset paths and shows a white screen if loaded through the HA sidebar/Ingress — this is unrelated to this add-on.

## Troubleshooting

**Copy button doesn't seem to do anything**
`navigator.clipboard` requires a secure context (HTTPS or `localhost`). Most HAOS installs are plain HTTP on the LAN, where the browser API is simply unavailable. The Copy buttons fall back to a legacy copy method automatically; if both fail, select the text manually and copy it.

**Login says "ntfy unreachable"**
The backend tried `GET /v1/account` against `ntfy_base_url` and got a network error. Check that the URL is correct and reachable from this add-on's container — try `http://<addon-slug>` if hostname resolution fails.

**"Wrong credentials" but they work in the ntfy web UI**
Make sure you picked the correct `ntfy_auth_type`. Some ntfy servers block `none` even when defaults look open.

**SSE stream disconnects every minute**
nginx is set to `proxy_read_timeout 24h`. If you're behind a reverse proxy, check that proxy's read timeout — many CDNs cap at 60s.

**Reservation API returns 404**
You're using a ntfy server too old to support reservations. Reservations are a paid-tier / self-host-with-payments feature.
