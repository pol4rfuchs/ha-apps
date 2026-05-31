<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/matrix_synapse/icon.png" alt="Matrix Server Icon" width="128">

# 🔷 Matrix Server — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Synapse Version](https://img.shields.io/badge/Synapse-1.148.0-0DBD8B?style=for-the-badge&logo=matrix&logoColor=white)](https://github.com/element-hq/synapse)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Full Matrix homeserver stack — Synapse + Element Web + Element Call (Voice/Video) + Synapse Admin — as a single Home Assistant Add-on.**

</div>

---

## 🧩 What's included

| Component | Version | Purpose |
|---|---|---|
| **Synapse** | 1.148.0 | Matrix homeserver |
| **PostgreSQL 15** | Debian pkg | Database |
| **Element Web** | v1.12.11 | Web client |
| **Element Call** | latest | Voice / Video calls |
| **LiveKit SFU** | latest | WebRTC media server |
| **Synapse Admin** | v0.10.3-etke32 | Admin UI |
| **S6-Overlay** | — | Multi-service init |

> ℹ️ Synapse Admin uses the [etkecc fork](https://github.com/etkecc/synapse-admin) — required for Synapse 1.14x compatibility. The original Awesome-Technologies fork does not work with Synapse 1.14x.

---

## 🚀 Installation

### Step 1 — Add the repository

```text
Settings → Add-ons → Add-on Store → ⋮ → Repositories
```

Add:

```text
https://github.com/pol4rfuchs/ha-apps
```

### Step 2 — Install & configure

Install **Matrix Server (ESS CE)** and set at minimum:

```yaml
server_name: "your-domain.duckdns.org"
element_web_url: "https://your-domain.duckdns.org"
postgres_password: "changeme_please"
enable_registration: false
```

### Step 3 — Start

First start takes 2–3 minutes. Element Web and Synapse Admin are downloaded at runtime (HA blocks network during the Docker build phase).

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `server_name` | — | Your Matrix domain. **No trailing slash.** |
| `element_web_url` | — | External HTTPS URL for Element Web. |
| `element_call_url` | — | External HTTPS URL for Element Call. |
| `livekit_url` | — | WebSocket URL for LiveKit SFU. |
| `livekit_jwt_url` | — | HTTPS URL for LiveKit JWT bridge. |
| `ntfy_url` | — | Optional: external ntfy URL for UnifiedPush. |
| `postgres_password` | — | PostgreSQL password — set before first start. |
| `enable_registration` | `false` | Allow public registration. |
| `enable_federation` | `true` | Connect to the Matrix federation. |
| `max_upload_size_mb` | `50` | Max media upload size in MB. |
| `log_level` | `WARNING` | `DEBUG / INFO / WARNING / ERROR` |

> ⚠️ `server_name` cannot be changed after the first start — it becomes the permanent Matrix ID (`@user:server_name`).

---

## 🌐 Ports

| Port | Service | Access |
|---|---|---|
| `7080` | Element Web | Via NPM → `element.your-domain` |
| `8008` | Synapse API | Via NPM → `matrix.your-domain` |
| `8090` | Synapse Admin UI | Via NPM → `admin.your-domain` |
| `8448` | Matrix Federation | Direct — port-forward required |
| `7880` | LiveKit SFU | Via NPM (WebSocket) |
| `8089` | LiveKit JWT Bridge | Via NPM |

See [`NPM_SETUP.md`](NPM_SETUP.md) for the full Nginx Proxy Manager configuration.

---

## 👤 Creating the first admin user

```bash
docker exec -it addon_local_matrix_server \
  /opt/synapse/bin/register_new_matrix_user \
  -c /data/matrix/synapse/homeserver.yaml \
  --admin -u admin -p YourSecurePassword \
  http://localhost:8008
```

Or use the helper script included in the add-on:

```bash
docker exec -it addon_local_matrix_server matrix-create-admin.sh
```

---

## 💾 Data persistence

```text
/data/matrix/
├── postgresql/             ← PostgreSQL database
├── synapse/
│   ├── homeserver.yaml     ← Synapse config
│   ├── signing.key         ← ⚠️ Back this up — loss = loss of federation identity
│   └── media_store/        ← Uploaded media
├── element-web/            ← Element Web (persistent)
├── synapse-admin/          ← Synapse Admin (persistent)
└── .webapps_downloaded     ← Marker: skip re-download on restart
```

To force re-download of web apps:

```bash
docker exec addon_local_matrix_server rm /data/matrix/.webapps_downloaded
# then restart the add-on
```

---

## 📱 UnifiedPush (Android push via ntfy)

This add-on integrates with the [ntfy add-on](../ntfy) for privacy-friendly push notifications on Element Android — no Google Firebase, no external servers.

```
Element Android
  → selects ntfy as UnifiedPush distributor
  → registers push gateway with Synapse:
      https://ntfy.your-domain/_matrix/push/v1/notify
  → Synapse sends pushes to ntfy
  → ntfy delivers to your device
```

Synapse does not need the ntfy URL in its config — the client registers the gateway automatically.

**Setup:**
1. Set `ntfy_url` in the add-on config
2. Install ntfy from F-Droid (Play Store version has no UnifiedPush)
3. In Element Android: Settings → Notifications → UnifiedPush → select ntfy

---

## 🏠 Home Assistant integration

```yaml
# configuration.yaml
notify:
  - platform: matrix
    name: matrix_notify
    homeserver: https://matrix.your-domain.duckdns.org
    username: "@homeassistant:your-domain.duckdns.org"
    password: "ha_user_password"
    default_room: "#homeassistant:your-domain.duckdns.org"
```

See [`ha_matrix_integration.yaml`](ha_matrix_integration.yaml) for a full example with automations.

---

## 📊 Resource usage (Pi 4, 8 GB RAM)

| Service | RAM | CPU (idle) |
|---|---|---|
| PostgreSQL | ~100 MB | <1% |
| Synapse | ~300–500 MB | 1–3% |
| Element Web | ~10 MB | <1% |
| Synapse Admin | ~10 MB | <1% |
| **Total** | **~450–650 MB** | **~3–5%** |

---

## 🔍 Test federation

```
https://federationtester.matrix.org/#your-domain.duckdns.org
```

---

## 🔧 Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Server name has invalid format` | Trailing slash in `server_name` | Remove the slash |
| Admin Panel "Something went wrong" | Stale browser cache | F12 → Application → Clear Site Data |
| Admin Panel 401 | NPM Access List active | Set Access List to "Publicly Accessible" |
| Element Web wrong server | Wrong config.json loaded | Clear browser cache |
| Web apps not loading | Extraction failed | Delete marker + restart add-on |
| Synapse token invalid | Add-on reinstalled, DB empty | Re-create admin user |
| Federation broken | Port 8448 not forwarded | Router: 8448 → HA-IP:8448 |

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream Matrix Synapse project is not relicensed by this repository
and remains under its upstream license.

Upstream:

- Matrix Synapse: https://github.com/element-hq/synapse
- Upstream license: AGPL-3.0, see upstream repository

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)