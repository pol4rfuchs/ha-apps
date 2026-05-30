# Matrix Server (ESS CE) — Home Assistant Add-on

Full Matrix homeserver stack: Synapse + Element Web + Element Call (Voice/Video) + Synapse Admin — as a single Home Assistant Add-on.

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

| Port | Service |
|------|---------|
| `7080` | Element Web (via NPM) |
| `8008` | Synapse API (via NPM) |
| `8090` | Synapse Admin UI (via NPM) |
| `8448` | Matrix Federation (direct, port-forward required) |
| `7880` | LiveKit SFU (via NPM, voice calls) |
| `8089` | LiveKit JWT Bridge (via NPM, voice calls) |

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
├── element-web/
└── synapse-admin/
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Server name has invalid format` | Remove trailing slash from `server_name` |
| Admin Panel shows "Something went wrong" | F12 → Application → Clear Site Data |
| Federation broken | Router: forward port 8448 → HA-IP:8448 |
| Element Web not loading | Delete `/data/matrix/.webapps_downloaded` and restart |
