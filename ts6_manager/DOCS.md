# TS6 Manager — Home Assistant Add-on

Web-based management interface for TeamSpeak 6 servers.  
Wraps [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) as a single-image HA add-on.

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

1. Add the repository to the add-on store:  
   **Settings → Add-ons → Add-on Store → ⋮ → Repositories**  
   URL: `https://github.com/pol4rfuchs/ha-apps`

2. Install "TS6 Manager"

3. Start the add-on

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

## Local and external access

**Local (LAN):** open `http://<ha-host>:8066`. There is no Ingress; the panel is protected by its own login only, not by Home Assistant authentication.

**External (internet):** recommendation **VPN or trusted access only** (a reverse proxy with TLS plus an access layer such as VPN or Cloudflare Access). Never expose the WebQuery port `10080`. The public server widgets under `/widget/` are intentionally unauthenticated status views; they are the only part meant to be public.
