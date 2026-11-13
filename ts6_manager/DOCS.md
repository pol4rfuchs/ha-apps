# TS6 Manager — Home Assistant App

Web-based management interface for TeamSpeak 6 servers.  
Wraps [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) as a single-image HA app.

## Features

- Dashboard with live stats, bandwidth graph, channel tree
- Client management (kick, ban, move, poke)
- Permissions, groups, ban list, token management
- Music bots (radio, YouTube via yt-dlp, local library)
- Bot flow engine (visual node editor for automations)
- Embeddable server widgets (SVG/PNG/JSON)
- Own web interface on port 8066 (no ingress), with its own login

## Requirements

- TeamSpeak 6 server with the **WebQuery HTTP API** enabled
- WebQuery API key (via `apikeyadd` or the TS admin tools)
- Optional: SSH access to the TS server (for bot flow event triggers)

## Installation

1. Add the repository to the app store:  
   **Settings → Apps → App Store → ⋮ → Repositories**  
   URL: `https://github.com/pol4rfuchs/ha-apps`

2. Install "TS6 Manager"

3. Start the app

4. Open the web interface (`http://<ha-host>:8066`, "Open Web UI" button) → `/setup` → create the admin account

5. Under **Settings → Connections** enter the TS6 server  
   (host, WebQuery port, API key)

## Persistent data (`/data`)

| Path | Content |
|------|--------|
| `/data/ts6webui.db` | SQLite database |
| `/data/secrets.env` | JWT_SECRET + ENCRYPTION_KEY (auto-generated) |
| `/data/music/` | Downloaded music (yt-dlp) |

The secrets are generated automatically on the first start.  
**Do not delete them** — otherwise all stored credentials become invalid.

## Architecture in the container

```
nginx :8066  (host port, no ingress)
  ├── /          → React SPA (static from /var/www/html)
  ├── /api/      → Node.js Backend :3001
  ├── /socket.io → WebSocket Backend :3001
  └── /widget/   → Public Widgets Backend :3001

s6-overlay Services:
  ts6-init    (oneshot) → generate secrets + Prisma migrate
  ts6-backend (longrun) → Node.js Express API
  ts6-nginx   (longrun) → nginx, starts after ts6-backend
```

## Configuration

| Option | Default | Description |
|--------|----------|--------------|
| `video_streaming` | `false` | Enables the WebRTC media sidecar for streaming video into TeamSpeak channels. Off: the sidecar idles and needs hardly any RAM/CPU. |
| `log_level` | `info` | Log level of the backend (trace/debug/info/notice/warning/error/fatal). The backend logs via `console.*`, and the levels are filtered there (`log`/`info` = info, `warn` = warning, `error` = error). nginx and the video sidecar are not affected. |

## Flood protection of TeamSpeak 6

**Cause.** TeamSpeak 6 locks out a query client that sends more than 10 commands within 3 seconds (instance settings `serverinstance_serverquery_flood_commands=10`, `flood_time=3`) for 10 minutes (`ban_time=600`); a WebQuery request with a virtual server id counts as two commands. TS6 Manager is a foreign client for the server, so several quick page loads (Dashboard, Channels, Clients, Server groups, Tokens) can trigger the lock.

**Symptom.** The pages show HTTP 502 or empty lists. The log of this app has `TSApiError: client is flooding`, then `socket hang up` and `Transport reset ... after a stale-socket error`. The lock outlasts a restart of this app and ends after the ban time or when the TeamSpeak 6 app is restarted.

**Remedy.** The manager now keeps itself below the limit (from the source version that contains pull request 3 of its repository): it spaces its requests (at most 8 commands per 3 seconds, so a page that asks for many lists can take a few seconds longer), shares identical read requests that run at the same time (and reuses the answer for one second), and after a "client is flooding" answer sends nothing for 30 seconds, doubling up to 5 minutes. While it waits, the page shows a message that names `query_ip_allowlist`. Tested against a real TeamSpeak 6 server without the allowlist: the previous client failed 27 of 32 quick requests, this one 0 of 32. On top of that, use the **TeamSpeak 6 app of this repository** and its option `query_ip_allowlist`. Its default is the Home Assistant app network `172.30.32.0/23`, which contains this app; then TeamSpeak does not lock it out. Tested with the original TS6 Manager client: 32 quick requests (a page load, four times in a row) all succeeded against a server with the sender in the allowlist, while without it 27 of 32 failed. Another TeamSpeak server needs the address of this app in its `query_ip_allowlist.txt`.

## Server logs page

The "Logs" page asks TeamSpeak for the log of the virtual server. TeamSpeak creates that file with the first log line of the virtual server after a start; until then it answers error 2052 (`file input/output error`), which used to show as an empty page and an HTTP 502. The manager now shows the instance log in that case, with a note on top. The TeamSpeak 6 app of this repository keeps its logs across restarts, so the file normally exists (see its documentation).

## Local and external access

**Local (LAN):** open `http://<ha-host>:8066`. There is no Ingress; the panel is protected by its own login only, not by Home Assistant authentication.

**External (internet):** recommendation **VPN or trusted access only** (a reverse proxy with TLS plus an access layer such as VPN or Cloudflare Access). Never expose the WebQuery port `10080`. The public server widgets under `/widget/` are intentionally unauthenticated status views; they are the only part meant to be public.
