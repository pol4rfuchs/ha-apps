# Matrix Server (ESS CE) — Home Assistant Add-on

Full Matrix homeserver stack: Synapse + Element Web + Element Call (Voice/Video) + Ketesa (Admin UI) — as a single Home Assistant Add-on.

---

## Quick Start

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add: `https://github.com/pol4rfuchs/ha-apps`
3. Install **Matrix Server (ESS CE)** and configure at minimum:

```yaml
server_name: "your-domain.duckdns.org"
postgres_password: "changeme_please"
enable_registration: false
```

4. Click **Start** — first start takes 2–3 minutes (web apps are downloaded at runtime)

> ⚠️ `server_name` cannot be changed after the first start — it becomes part of every Matrix ID permanently.

---

## Creating the First Admin User

```bash
docker exec -it addon_local_matrix_server matrix-create-admin.sh
```

---

## Ports

| Port | Service | Access |
|------|---------|--------|
| `7080` | Element Web | Via NPM |
| `7081` | Element Call (Voice/Video WebApp) | Via NPM |
| `8008` | Synapse API | Via NPM |
| `8090` | Ketesa (Admin UI) | Via NPM |
| `8448` | Matrix Federation | Direct — port-forward required |
| `7880` | LiveKit SFU | Via NPM (WebSocket required) |
| `8089` | LiveKit JWT Bridge | Via NPM |
| `3478/udp` | TURN (media control) | Direct — port-forward required, cannot go via NPM |
| `5349/tcp` | TURN TLS fallback | Direct — port-forward required, cannot go via NPM |
| `30000-30020/udp` | TURN Relay Range (media) | Direct — port-forward required, cannot go via NPM |

> ⚠️ The TURN/relay ports are the most commonly missed step: calls will connect but carry no audio/video without them forwarded on your router — even between two devices on the same LAN, since LiveKit always routes media through TURN by design.

See the [NPM_SETUP.md](https://github.com/pol4rfuchs/ha-apps/blob/main/matrix_synapse/NPM_SETUP.md) for the full Nginx Proxy Manager setup.

---

## Data Persistence

```
/data/matrix/
├── postgresql/             ← PostgreSQL database
├── synapse/
│   ├── homeserver.yaml
│   ├── signing.key         ← Back this up — loss = loss of federation identity
│   └── media_store/
├── element-web/            ← Element Web (persistent)
├── synapse-admin/          ← Ketesa / Admin UI (persistent, folder name kept for compat)
├── .element-web_version    ← Installed Element Web version
├── .ketesa_version         ← Installed Ketesa version
└── .element-call_version   ← Installed Element Call version (if voice enabled)
```

Element Web, Ketesa, and Element Call each compare their installed version against upstream `latest` on every add-on start and re-download automatically on mismatch.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Server name has invalid format` | Remove trailing slash from `server_name` |
| Admin Panel shows "Something went wrong" | F12 → Application → Clear Site Data |
| Federation broken | Router: forward port 8448 → HA-IP:8448 |
| Element Web / Ketesa / Element Call not loading | Delete the relevant `.{app}_version` file in `/data/matrix/` and restart |
| Call connects but no audio/video | TURN UDP 3478 and/or relay range 30000-30020 not forwarded on the router (direct, not via NPM) |
| Login stuck loading via `http://<LAN-IP>:7080` | Plain HTTP has no secure context — browsers disable WebCrypto. Use the HTTPS domain instead, even from the LAN |
