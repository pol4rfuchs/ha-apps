# TS6 Manager — Home Assistant App

Web-based management interface for TeamSpeak 6 servers.  
Wraps [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) as a single-image HA app.

## Features

- Dashboard with live stats, bandwidth graph, channel tree
- Client management (kick, ban, move, poke)
- Permissions, groups, ban list, token management
- Music bots (radio, YouTube via yt-dlp, local library, Navidrome)
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

## Things to know

- **Empty lists.** Lists without entries (bans, complaints, offline messages) show as empty. Older versions answered HTTP 502 with TeamSpeak error 1281 "database empty result set" for them.
- **Wrong ids in music bot requests.** A missing or non-numeric `songId` (queue and play) or `stationId` (play-radio) in the request body is answered with HTTP 400 `... must be an integer`. Older versions answered HTTP 500.
- **Creating a music bot takes a while.** When a music bot is created, the manager computes a TeamSpeak identity for it at security level 23. On a Raspberry Pi 4 this took 138 seconds in a test (the earlier estimate of 30 seconds was too low), uses one CPU core while it runs, and the interface shows no progress. Plan for 30 seconds up to several minutes, depending on the device, and wait for it to finish. The level is hard-coded in the manager (`generateIdentityAsync(23)`); this app has no option for it, because the manager offers no setting that could be passed through.
- **The footer shows "TS6 WEBUI v1.0.0".** That text is fixed in the manager's login and setup pages and is not the version of this app. The version of this app is shown in Home Assistant.
- **Public widgets name the TeamSpeak host.** The public widget data (`/api/widget/<token>/data`) contains `serverHost`, the host name that is set for the TeamSpeak server in the manager (inside Home Assistant this is the internal app host name). Anyone who knows the widget token can read it. The manager has no switch to leave it out, and this app cannot switch it off. Do not share the widget URL with people who should not see the host name.

## Flood protection of TeamSpeak 6

**Cause.** TeamSpeak 6 locks out a query client that sends more than 10 commands within 3 seconds (instance settings `serverinstance_serverquery_flood_commands=10`, `flood_time=3`) for 10 minutes (`ban_time=600`); a WebQuery request with a virtual server id counts as two commands. TS6 Manager is a foreign client for the server, so several quick page loads (Dashboard, Channels, Clients, Server groups, Tokens) can trigger the lock.

**Symptom.** The pages show HTTP 502 or empty lists. The log of this app has `TSApiError: client is flooding`, then `socket hang up` and `Transport reset ... after a stale-socket error`. The lock outlasts a restart of this app and ends after the ban time or when the TeamSpeak 6 app is restarted.

**Remedy.** The manager now keeps itself below the limit (from the source version that contains pull request 3 of its repository): it spaces its requests (at most 8 commands per 3 seconds, so a page that asks for many lists can take a few seconds longer), shares identical read requests that run at the same time (and reuses the answer for one second), and after a "client is flooding" answer sends nothing for 30 seconds, doubling up to 5 minutes. While it waits, the page shows a message that names `query_ip_allowlist`. Tested against a real TeamSpeak 6 server without the allowlist: the previous client failed 27 of 32 quick requests, this one 0 of 32. On top of that, use the **TeamSpeak 6 app of this repository** and its option `query_ip_allowlist`. Its default is the Home Assistant app network `172.30.32.0/23`, which contains this app; then TeamSpeak does not lock it out. Tested with the original TS6 Manager client: 32 quick requests (a page load, four times in a row) all succeeded against a server with the sender in the allowlist, while without it 27 of 32 failed. Another TeamSpeak server needs the address of this app in its `query_ip_allowlist.txt`.

## Roles and server access

There are two roles. Both can sign in; what they may do differs.

| | `admin` | `viewer` |
|---|---|---|
| Users, TeamSpeak connections, bots, bans, logs, tokens page, all changes (create channel, snapshot, ...) | yes | no (HTTP 403) |
| Read channels, clients and the server list | yes | yes, but only on servers that were granted to the user; without a grant HTTP 403 |

Tested with a real manager and a TeamSpeak 6 server: a `viewer` without a grant got 403 on the server, its channel list and its bans; after a row was added to the manager's per-user table `UserServerAccess` it got 200 on channels and clients, and still 403 on bans, logs, bots and every write. The manager has neither a page nor an API route that creates such a row, so with an unmodified manager a `viewer` can read nothing on a server. Use `admin` for people who need to see anything. This is a gap of the manager, not of this app; see `docs/ts6-manager-upstream-issues.md`.

## Bot flows

Bot flows (page "Bots") are normally built in the editor. They can also be created through the API: `PUT /api/bots/<id>` with `{name, flowData: {nodes, edges}}`, then `POST /api/bots/<id>/enable`. Each node has a `type` and a `config` object; edges connect node ids. Example that sends a private message to one client every minute (tested on a real instance: the cron trigger fired at the start of each minute and `GET /api/bots/<id>/executions` showed status `completed`):

```json
{
  "name": "Every minute",
  "flowData": {
    "nodes": [
      { "id": "n1", "type": "trigger_cron", "label": "Cron Timer", "config": { "cron": "* * * * *", "timezone": "UTC" }, "x": 100, "y": 100 },
      { "id": "n2", "type": "action_message", "label": "Send Message", "config": { "targetMode": "client", "target": "<clientId>", "message": "Hello" }, "x": 400, "y": 100 }
    ],
    "edges": [
      { "id": "e1", "source": "n1", "sourcePort": "out", "target": "n2", "targetPort": "in" }
    ]
  }
}
```

- `trigger_cron`: `cron` is a five-field cron expression; `timezone` defaults to UTC.
- `action_message`: `targetMode` is `client`, `channel` or `server`; `target` is the client id (`client`) or the channel id (`channel`). Without a `target` the client that caused the event is used.
- Put the settings under `config`, not under `data`. With `data` the manager reads an empty cron expression, logs `Invalid cron expression ''` and still reports the flow as enabled, but it never fires.
- **Use `client` or `channel` for messages people should see.** With `server` the TeamSpeak server accepts the message (confirmed with a query listener: `notifytextmessage targetmode=3`), but the TeamSpeak 6 client has no server chat and shows it nowhere.
- Channel messages are sent from the manager's query session. Older source versions moved that session into the target channel first and failed with `already member of channel` (TeamSpeak error 770) when it was already there, so nothing was sent. The manager now skips the move in that case and moves the session back afterwards (needs the source version that contains this fix).

## Music bots

- **Repeat modes.** `POST /api/music-bots/<id>/queue/repeat` with `{"mode": ...}` accepts `off`, `track` (repeat the current track) and `queue` (repeat the whole queue). Anything else, such as `single` or `all`, is answered with HTTP 400 `Invalid repeat mode`.
- **Channel codec.** A channel with Opus Voice (codec 4, quality 6, the TeamSpeak default) made music crackle in a test; after switching the bot's channel to Opus Music (codec 5, quality 10) the sound was clean. Set the codec of the channel the music bot joins to Opus Music. The manager shows no hint about this and does not change channel settings itself.
- **Memory with long tracks.** A 77-minute YouTube track made the manager use about 1.2 GB of RAM in a test (about 190 MB otherwise). Playback itself does not load the file: ffmpeg decodes it while it is played (measured with a 77-minute file: about 120 MB for the manager and 50 MB for ffmpeg, constant). The peak therefore most likely comes from the download and conversion with yt-dlp, which could not be reproduced here without YouTube access. On a 4 GB device, avoid downloading several very long tracks at the same time.
- **Opus encoder.** The log line `@discordjs/opus unavailable, using opusscript (WASM)` means the manager encodes in software, which needs more CPU. Music still plays; it only costs CPU.

## Server snapshot

Create a snapshot with `POST /api/servers/<configId>/virtual-servers/<sid>/snapshot` (admin only, `Authorization: Bearer` token of the manager). It must be a `POST`; a `GET` is answered with 404 (`Cannot GET`). The answer is HTTP 200 with the snapshot as JSON in the field `data`. Tested against TeamSpeak 6 6.0.0-beta13.1.

Restoring: the manager has a deploy route, `POST .../virtual-servers/<sid>/snapshot/deploy`, which forwards its request body to the TeamSpeak command `serversnapshotdeploy`; that route itself was not tested. Deploying a snapshot directly through ServerQuery was tested: it restored the saved state (a test channel created afterwards was gone). **The virtual server restarts while a snapshot is deployed**, so all clients are disconnected for a moment.

## Navidrome as music source

The manager can use a Navidrome (Subsonic) server, for example the Navidrome app of this repository, as a source for the music bot. Found tracks are copied into the manager's music folder (`/data/music`) and then play like any other song.

1. In the manager open **Settings → Navidrome**, switch it on and enter the address, a Navidrome user name and its password. Inside Home Assistant use the internal host name of the Navidrome app (shown on the app's info page in Home Assistant) with port `4533`, for example `http://<navidrome-app-host>:4533`. The password is stored encrypted and never shown again; leave the field empty to keep it.
2. Press **Test connection**. It reports the Navidrome version or a readable error.
3. In the music library of a server a Navidrome search field appears. Search, then **Add** a track. Adding the same track again does not download it twice.

Things to know:

- The search needs a search term (at most 200 characters); an empty one is refused, because Navidrome would answer an empty search with its whole library. At most 20 tracks are shown.
- Deleting a song in the manager deletes only the copy in `/data/music`, not the file in Navidrome.
- Tested against Navidrome 0.64.2 outside Home Assistant: the search (including the refused empty, blank and overlong terms). Only checked by unit tests and the build, not run against a real Navidrome: the connection test, adding a track, adding the same track twice, and deleting a song. Not tested at all: access from the manager to the Navidrome app inside Home Assistant, playing an imported track through the music bot in TeamSpeak, large libraries.

## Server logs page

The "Logs" page asks TeamSpeak for the log of the virtual server. TeamSpeak creates that file with the first log line of the virtual server after a start; until then it answers error 2052 (`file input/output error`), which used to show as an empty page and an HTTP 502. The manager now shows the instance log in that case, with a note on top. The TeamSpeak 6 app of this repository keeps its logs across restarts, so the file normally exists (see its documentation).

## AppArmor

The app runs with an AppArmor profile (`apparmor.txt`, `apparmor: true`). The Supervisor loads it when the app is installed and reloads it when the app is updated. What the profile allows:

- **Write access** only to `/data`, `/tmp`, `/run` and the app's own folders (the nginx folders `/var/log/nginx`, `/var/lib/nginx`, `/var/cache/nginx`, and `/root`). Other files are read-only or not accessible (apart from the usual device files such as `/dev/null`).
- **Programs and scripts** run only from the system folders of the image and the app's own program folders.
- **Capabilities:** the standard Docker set without `net_raw`.
- **Network:** TCP, UDP, IPv4/IPv6, Unix sockets and netlink; no raw or packet sockets.
- **Mount:** denied.

Tested by the maintainer on a Raspberry Pi 4 with HAOS 18.5, AppArmor enforcing: first-time setup, connecting to the TeamSpeak 6 app, a music bot with yt-dlp and ffmpeg, the video sidecar, 60 parallel queries, and a restart of the whole system; no "Permission denied" appeared. Not tested: updating an app while its profile is loaded.

**If an extension of your own reports "Permission denied":** the profile blocked an access. Write to `/data` instead, or to `/tmp` for temporary files. The kernel log of the host shows `apparmor="DENIED"` lines with the blocked path (visible on the HAOS console or through the developer SSH access). If the app itself needs the path, open an issue in the repository with that line; the profile is changed in `apparmor.txt` and arrives with an app update.

## Local and external access

**Local (LAN):** open `http://<ha-host>:8066`. There is no Ingress; the panel is protected by its own login only, not by Home Assistant authentication.

**External (internet):** recommendation **VPN or trusted access only** (a reverse proxy with TLS plus an access layer such as VPN or Cloudflare Access). Never expose the WebQuery port `10080`. The public server widgets under `/widget/` are intentionally unauthenticated status views; they are the only part meant to be public.
