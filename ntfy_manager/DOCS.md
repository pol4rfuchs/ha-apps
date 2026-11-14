# ntfy HAOS Admin Panel — Documentation

## Quick start

1. Install app, leave defaults.
2. If you already have an admin user on your ntfy app, fill `ntfy_username` and `ntfy_password` here.
3. Start.
4. Open the sidebar panel → you're in. (The configured credentials are used through the sidebar/Ingress only; the optional direct port `8099` always shows the login screen.)

If you don't fill credentials, you'll see a login screen — type any ntfy user there.

## App options

### ntfy_base_url
URL of your ntfy app, as reachable from this app's container. Defaults to `http://9bf6aa7c-ntfy:4280`: the internal Docker name of the ntfy app from this repository (`<repository id>-ntfy`) and its port `4280`.

Why not `http://homeassistant.local:4280`: that name is resolved by your network. With more than one Home Assistant system in the network it can point to another system, and the panel would then send the ntfy credentials there. The internal name is only known inside this Home Assistant.

When to use another address instead:
- The `9bf6aa7c` part is the id Home Assistant derives from the repository address. If you added the repository under a different address, the id is different. Open the ntfy app in Home Assistant: the **Info** tab shows its hostname; use `http://<that hostname>:4280`.
- Your ntfy runs on another machine, or is not the ntfy app from this repository: use its IP address or a name you control, for example `http://192.0.2.10:4280` or `https://ntfy.example.org`.
- Existing installations keep the value that is already saved in their configuration. If it still says `http://homeassistant.local:4280` and you have several Home Assistant systems, change it.

Both apps must be running for the internal name to work.

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
If `true`, users can log in with different credentials via the panel UI. Set to `false` for kiosk-mode setups where only the configured account should be used. With `false` the panel is only usable through the sidebar (Ingress), because the direct port `8099` never uses the configured credentials and its login is then disabled.

## How auth works

The panel never asks Home Assistant who you are. It uses ntfy for that.

When you log in (or, through the sidebar/Ingress only, when defaults from this app's config are picked up), the backend builds an `Authorization` header (`Basic …` or `Bearer …`), validates it against `GET /v1/account`, and if ntfy says it's good, encrypts those credentials into an httpOnly cookie. The cookie lives 12 hours.

Every API call you make from the panel hits this app's Express backend, which decrypts the cookie, attaches the header, and forwards to ntfy.

The ntfy `user.db` is the only source of truth. There's no second user store.

## Page reference

### Overview
Live snapshot: server health, version, lifetime message count, user count. Auto-refreshes uptime every second; refetches data when you hit the **Refresh** button in the top bar.

### Send
Compose a notification. Topic + Title + Priority (1–5) + Tags + Click-URL. The right-hand preview updates as you type.

The publish endpoint of the backend (`POST /api/ntfy/publish`) accepts `tags` as a comma separated string or as a JSON array. Title, tags and click URL must not contain control characters (line breaks): such a request is refused with `400`. Umlauts and emoji are allowed; the backend sends them RFC 2047 encoded.

### Users
Lists all ntfy users. Create new ones (PUT `/v1/users`), change passwords of regular users (PUT same endpoint with new password), delete regular users (DELETE `/v1/users`).

New users are always created as regular users: the panel does not send a role to ntfy, because ntfy 2.37 refuses any request that carries a `role` (see *Known Limitations*). Choosing `admin` in the dialog creates a regular user; promote it afterwards with the ntfy command line.

Admin users can't be changed or deleted from the panel (the panel hides those buttons) — they're managed through the ntfy command line or your ntfy app configuration.

### Tokens
Create new API tokens. ntfy's REST API doesn't expose existing tokens server-wide, so the listing has to happen in ntfy's own web UI. We show a clear notice and link there. Newly created tokens are displayed once with a copy button. When the panel reads the account from ntfy (`GET /api/ntfy/account`), the backend shortens every access token in the answer to its first characters, because the panel never needs them.

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
**SSE Monitor** — opens a server-sent-events stream against ntfy `/sse`, proxied through this app's backend so credentials never leave the cookie. Auto-reconnects on disconnect.

**Audit Log** — in-memory ring buffer (max 500 entries). Logs API actions like user created, ACL changed, reservation removed. Cleared on app restart; mirrored to Supervisor log via console.

## Known Limitations

These are ntfy API limitations, not bugs in this panel — they applied to the old built-in ntfy admin panel too and will apply to any UI built on top of the same API.

- **Token listing** — ntfy's REST API has no endpoint to list a user's existing tokens. Create new ones here; view/revoke existing ones in the ntfy Web UI → Account → Access Tokens.
- **Admin socket (ntfy 2.37)** — ntfy 2.37 only accepts some user operations over its *local admin socket* (a file inside the ntfy container, not reachable from this app): any create request that sets a `role`, and changing the password of or deleting an admin-role account. Over the normal API ntfy answers `403 forbidden: this operation is only allowed over the local admin socket`. The panel shows this as a readable message instead of a raw error. Tested against ntfy `2.37.2`: creating a user without a role, changing the password of a regular user and deleting a regular user work; the three cases above return 403.
- **Role changes** — the panel cannot change a user's role. To promote someone to admin, run `ntfy user change-role <username> admin` in the ntfy app, or set them as `admin_username` in the ntfy app's own config.
- **Admin accounts** — manage admin accounts through the ntfy command line or the ntfy app's configuration; the panel cannot change or delete them.
- **ntfy's own Web UI and HA Ingress** — opening the "Open ntfy web UI" link takes you to ntfy's own interface (port `4280` directly, not through Ingress). ntfy's SPA uses absolute asset paths and shows a white screen if loaded through the HA sidebar/Ingress — this is unrelated to this app.

## Troubleshooting

**Copy button doesn't seem to do anything**
`navigator.clipboard` requires a secure context (HTTPS or `localhost`). Most HAOS installs are plain HTTP on the LAN, where the browser API is simply unavailable. The Copy buttons fall back to a legacy copy method automatically; if both fail, select the text manually and copy it.

**Login says "ntfy unreachable"**
The backend tried `GET /v1/account` against `ntfy_base_url` and got a network error. Check that the URL is correct and reachable from this app's container — if the internal name does not resolve, check the hostname on the ntfy app's **Info** tab (see `ntfy_base_url`) or use the IP address of the Home Assistant host.

**"Wrong credentials" but they work in the ntfy web UI**
Make sure you picked the correct `ntfy_auth_type`. Some ntfy servers block `none` even when defaults look open.

**SSE stream disconnects every minute**
nginx is set to `proxy_read_timeout 24h`. If you're behind a reverse proxy, check that proxy's read timeout — many CDNs cap at 60s.

**Reservation API returns 404**
You're using a ntfy server too old to support reservations. Reservations are a paid-tier / self-host-with-payments feature.

## AppArmor

The app runs with an AppArmor profile (`apparmor.txt`, `apparmor: true`). The Supervisor loads it when the app is installed and reloads it when the app is updated. What the profile allows:

- **Write access** only to `/data`, `/tmp`, `/run` and the app's own folders (the nginx folders `/var/log/nginx`, `/var/lib/nginx`, `/var/cache/nginx`). Other files are read-only or not accessible (apart from the usual device files such as `/dev/null`).
- **Programs and scripts** run only from the system folders of the image and the app's own program folders.
- **Capabilities:** the standard Docker set without `net_raw`.
- **Network:** TCP, UDP, IPv4/IPv6, Unix sockets and netlink; no raw or packet sockets.
- **Mount:** denied.

Tested by the maintainer on a Raspberry Pi 4 with HAOS 18.5, AppArmor enforcing: login, sending a message and creating a user, and a restart of the whole system. Not tested: the other pages of the panel (only the listed actions were run), and updating an app while its profile is loaded.

**If an extension of your own reports "Permission denied":** the profile blocked an access. Write to `/data` instead, or to `/tmp` for temporary files. The kernel log of the host shows `apparmor="DENIED"` lines with the blocked path (visible on the HAOS console or through the developer SSH access). If the app itself needs the path, open an issue in the repository with that line; the profile is changed in `apparmor.txt` and arrives with an app update.

## Local and external access

**Local (LAN):** open the panel from the Home Assistant sidebar (Ingress, protected by your HA login) or, optionally, directly on `http://<ha-host>:8099`. The direct port is optional; clear it in the app's Network tab if you only want Ingress. The credentials from the app configuration are only used for requests coming through Ingress; on the direct port the panel always asks for an ntfy login. The session cookie is encrypted.

**External (internet):** recommendation **not recommended, VPN only.** The panel manages ntfy users, tokens and ACLs. If you must publish it, use a reverse proxy with TLS plus an additional access layer. The session cookie is not flagged `Secure` (the panel assumes plain HTTP behind Ingress).
