<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/matrix_synapse/logo.png" alt="Matrix Server Logo" width="500">

# 🔷 Matrix Server — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Synapse Version](https://img.shields.io/badge/Synapse-%3E%3D1.163.0-0DBD8B?style=for-the-badge&logo=matrix&logoColor=white)](https://github.com/element-hq/synapse)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Full Matrix homeserver stack — Synapse + Element Web + Element Call (Voice/Video) + Ketesa — as a single Home Assistant Add-on.**

</div>

---

## 🧩 What's included

| Component | Version | Purpose |
|---|---|---|
| **Synapse** | pip floor, Renovate-tracked | Matrix homeserver |
| **PostgreSQL 15** | Debian pkg | Database |
| **Element Web** | latest (auto-fetched, version-tracked) | Web client |
| **Element Call** | latest (auto-fetched, version-tracked) | Voice / Video calls |
| **LiveKit SFU** | latest (auto-fetched, version-tracked) | WebRTC media server |
| **Ketesa** (formerly Synapse Admin) | latest (auto-fetched, version-tracked) | Admin UI |
| **S6-Overlay** | — | Multi-service init |

> ℹ️ The admin UI is [Ketesa](https://github.com/etkecc/ketesa) — the etke.cc project formerly known as Synapse Admin, renamed in 2026. It's a drop-in replacement of the original Awesome-Technologies fork, with wider Synapse compatibility and active maintenance. Element Web, Element Call, and Ketesa are all downloaded at first start and re-checked against upstream `latest` on every subsequent start — no manual updates needed.
>
> ℹ️ Synapse itself works differently: it's `pip install`ed at **Docker build time**, not fetched at container start. A new Synapse release only lands once the image is rebuilt — Renovate opens a PR when a new PyPI release appears, and merging it triggers that rebuild.

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
server_name: "example.org"
element_web_url: "https://example.org"
enable_registration: false
```

### Step 3 — Start

First start takes 2–3 minutes. Element Web and Ketesa are downloaded at runtime (HA blocks network during the Docker build phase).

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `server_name` | — | Your Matrix domain. **No trailing slash.** |
| `element_web_url` | `https://example.org:7080` | External HTTPS URL for Element Web. |
| `postgres_password` | — | Password of the internal database user. Leave empty: the add-on generates one and stores it in `/data/matrix/.pg_password`. If you set a value, it is applied to the database on every start. |
| `enable_registration` | `false` | Allow public registration. |
| `enable_federation` | `true` | Connect to the Matrix federation. |
| `max_upload_size_mb` | `50` | Max media upload size in MB. |
| `log_level` | `WARNING` | `DEBUG / INFO / WARNING / ERROR` |
| `ntfy_url` | — | Optional: external ntfy URL for UnifiedPush. |
| `enable_voice_calls` | `false` | Enable Element Call (MSC3401) with LiveKit SFU. Downloads LiveKit and lk-jwt-service on first start. |
| `livekit_secret` | — | Shared secret for LiveKit. Leave empty to auto-generate on first start (stored in `/data/matrix/.livekit_secret`). |
| `element_call_url` | — | External HTTPS URL for Element Call. Only used if `enable_voice_calls` is `true`. |
| `livekit_url` | — | WebSocket URL for LiveKit SFU (`wss://...`). Only used if `enable_voice_calls` is `true`. |
| `livekit_jwt_url` | — | HTTPS URL for the LiveKit JWT bridge. Only used if `enable_voice_calls` is `true`. |
| `registration_shared_secret` | — | Secret for admin-controlled user registration. Leave empty to auto-generate. |
| `mas_enabled` | `false` | Delegates login/registration entirely to the matrix-auth-service add-on (required for Element X QR-code login). Disables native Synapse auth. |
| `mas_endpoint` | `http://homeassistant.local:8082` | Internally reachable URL of the matrix-auth-service add-on (e.g. http://homeassistant.local:8082). |
| `mas_secret` | — | Must exactly match the value generated/set in the matrix-auth-service add-on. |
| `whatsapp_bridge_enabled` | `false` | Registers the mautrix-whatsapp bridge's appservice with Synapse (requires the WhatsApp Bridge add-on running with its registration.yaml present in /share). |
| `signal_bridge_enabled` | `false` | Registers the mautrix-signal bridge's appservice with Synapse (requires the Signal Bridge add-on running with its registration.yaml present in /share). |
| `telegram_bridge_enabled` | `false` | Registers the mautrix-telegram bridge's appservice with Synapse (requires the Telegram Bridge add-on running with its registration.yaml present in /share). |
| `enable_synapse_admin` | `true` | Start the Synapse Admin web UI on port 8090. |
| `livekit_turn_enabled` | `false` | Off by default: calls use direct SFU UDP ports (30000-30020), which is more reliable on normal home/mobile networks. Only enable this if you're on a very restrictive network that only allows HTTPS/port 443 (the internal TURN server then uses that fallback path). |
| `admin_ui_username` | `admin` | Basic-Auth username for the Ketesa (Admin UI) on port 8090. Protects the admin interface at the network level. |
| `admin_ui_password` | — | Basic-Auth password for the Ketesa (Admin UI). Leave empty to auto-generate on first start (stored in /data/matrix/.admin_ui_auth, never logged). |
| `media_retention_local_days` | `0` | Auto-purge locally uploaded media older than this many days. 0 = disabled (keep forever). |
| `media_retention_remote_days` | `30` | Auto-purge cached remote (federated) media older than this many days. 0 = disabled (keep forever). 30 is a sensible default. |
| `backup_enabled` | `true` | Periodically dump the Synapse database via pg_dump to /data/matrix/backups/ (consistent, unlike raw filesystem snapshots). |
| `backup_interval_hours` | `24` | How often to run the pg_dump backup job. |
| `backup_retention_days` | `7` | How many days of backups to keep before rotating out old dumps. |
| `login_rate_limit_per_second` | `0.17` | Sustained allowed login attempts per second, per address/account (Synapse rc_login). Synapse default is 0.17. |
| `login_rate_limit_burst` | `3` | Burst allowance for login attempts before rate limiting kicks in. |
| `registration_rate_limit_per_second` | `0.17` | Sustained allowed registration attempts per second (Synapse rc_registration). Only relevant if enable_registration is true. |
| `registration_rate_limit_burst` | `3` | Burst allowance for registration attempts before rate limiting kicks in. |

> ⚠️ `server_name` cannot be changed after the first start — it becomes the permanent Matrix ID (`@user:server_name`).

---

## 🌐 Ports

| Port | Service | Access |
|---|---|---|
| `7080` | Element Web | Via NPM → `element.your-domain` |
| `7081` | Element Call | Via NPM → `element-call.your-domain` |
| `8008` | Synapse API | Via NPM → `matrix.your-domain` |
| `8090` | Ketesa (Admin UI) | Via NPM → `admin.your-domain` |
| `8448` | Matrix Federation | Direct — port-forward required |
| `7880` | LiveKit SFU | Via NPM (WebSocket required) |
| `8089` | LiveKit JWT Bridge | Via NPM |
| `3478/udp` | TURN (media control) | Only with `livekit_turn_enabled: true` — direct, cannot go via NPM |
| `5349/tcp` | TURN TLS fallback | Only with `livekit_turn_enabled: true` — direct (only needed for strict corporate firewalls) |
| `30000-30020/udp` | LiveKit media (direct SFU path, or TURN relay with `livekit_turn_enabled`) | **Direct — port-forward required, cannot go via NPM** |

> ⚠️ The media range is the most commonly missed step in setup — most guides only mention Federation as needing a direct router forward. Without UDP 30000-30020 forwarded, calls will connect (signaling works fine over NPM) but carry no audio or video at all, even between two devices on the same LAN. By default (`livekit_turn_enabled: false`) LiveKit uses this range directly; UDP 3478 and TCP 5349 are only needed if you enable the built-in TURN server. The range is intentionally kept to 21 ports rather than LiveKit's 10,000-port default; see `NPM_SETUP.md` for why.

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

> ℹ️ This creates a **new** admin user. To promote an existing user to admin instead, update the database directly:
> ```bash
> docker exec -it addon_local_matrix_server \
>   gosu postgres psql -d synapse -c "UPDATE users SET admin = 1 WHERE name = '@username:example.org';"
> ```
> Log out and back in afterwards — an already-active session won't pick up the change automatically.

---

## 💾 Data persistence

```text
/data/matrix/
├── postgresql/             ← PostgreSQL database
├── .pg_initialized         ← Marker: Postgres cluster already initialized (skip re-init on restart)
├── synapse/
│   ├── homeserver.yaml     ← Synapse config (rewritten on every start)
│   ├── log.yaml            ← Synapse logging config (rewritten on every start)
│   ├── signing.key         ← ⚠️ Back this up — loss = loss of federation identity
│   └── media_store/        ← Uploaded media
├── element-web/                    ← Element Web (persistent), incl. config.json + per-domain variants
├── element-call/                   ← Element Call (persistent, only if enable_voice_calls), incl. config.json + per-domain variants
├── synapse-admin/                  ← Ketesa / Admin UI (persistent, folder name kept for compat)
├── livekit.yaml                     ← LiveKit server config (rewritten on every start, only if enable_voice_calls)
├── .element-web_version            ← Installed Element Web version
├── .ketesa_version                 ← Installed Ketesa version
├── .element-call_version           ← Installed Element Call version (if voice enabled)
├── .livekit-server_version         ← Installed LiveKit binary version (if voice enabled)
├── .lk-jwt-service_version         ← Installed lk-jwt-service binary version (if voice enabled)
├── .livekit_secret                 ← Auto-generated LiveKit shared secret (if voice enabled)
└── .registration_secret            ← Auto-generated registration_shared_secret
```

Element Web, Ketesa, Element Call, and (if voice is enabled) the LiveKit/lk-jwt-service binaries each compare their installed version against upstream `latest` on every add-on start and re-download automatically on mismatch — no manual action needed.

To force a re-download of a specific component (e.g. after a corrupted extraction):

```bash
docker exec addon_local_matrix_server rm /data/matrix/.ketesa_version
# then restart the add-on — it will detect the missing version file and re-fetch
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
    homeserver: https://matrix.example.org
    username: "@homeassistant:example.org"
    password: "ha_user_password"
    default_room: "#homeassistant:example.org"
```

See [`ha_matrix_integration.yaml`](ha_matrix_integration.yaml) for a full example with automations.

---

## 📊 Resource usage (Pi 4, 8 GB RAM)

| Service | RAM | CPU (idle) |
|---|---|---|
| PostgreSQL | ~100 MB | <1% |
| Synapse | ~300–500 MB | 1–3% |
| Element Web | ~10 MB | <1% |
| Ketesa | ~10 MB | <1% |
| LiveKit + lk-jwt-service (if enabled) | ~50–100 MB | 1–2% idle, more during calls |
| **Total** | **~450–650 MB** (~550–750 MB with voice) | **~3–5%** |

---

## 🔍 Test federation

```
https://federationtester.matrix.org/#example.org
```

---

## 🔧 Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Server name has invalid format` | Trailing slash in `server_name` | Remove the slash |
| Admin Panel "Something went wrong" | Stale browser cache | F12 → Application → Clear Site Data |
| Admin Panel 401 | NPM Access List active | Set Access List to "Publicly Accessible" |
| Element Web wrong server | Wrong config.json loaded | Clear browser cache |
| Web apps not loading | Extraction failed | Delete the relevant `.{app}_version` file in `/data/matrix/` + restart add-on |
| Synapse token invalid | Add-on reinstalled, DB empty | Re-create admin user |
| Federation broken | Port 8448 not forwarded | Router: 8448 → HA-IP:8448 |
| Call connects but no audio/video | UDP range 30000-30020 not forwarded on the router (and UDP 3478 / TCP 5349 if `livekit_turn_enabled` is `true`) | Forward them directly (not via NPM) to the HA host. Needed even for calls between devices on the same LAN. |
| Login stuck loading / blank screen via `http://<LAN-IP>:7080` | Plain HTTP has no "secure context" — browsers disable WebCrypto (needed for E2E encryption) on anything that isn't HTTPS or `localhost` | Use the HTTPS domain (e.g. `https://element.your-domain`) instead, even from the LAN — most routers support NAT hairpinning so this works without leaving the network. Direct `:7080` IP access is a convenience fallback only and won't fully work by design. |

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
