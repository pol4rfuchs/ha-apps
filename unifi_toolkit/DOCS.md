# UniFi Toolkit - Documentation

## Setup

1. Start the app and open the **UniFi Toolkit** panel in the sidebar.
2. Open the configuration dialog in the Toolkit UI and enter the controller URL
   (for example `https://<your-controller>`) and a UniFi API key.
3. Credentials are stored encrypted (Fernet) in the app database. They are **not**
   app options, because upstream only reads them from its own UI.

## Options

| Option | Default | Description |
|---|---|---|
| `log_level` | `INFO` | Log verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`). `DEBUG` also prints every SQL statement of the toolkit (very noisy), use it only for troubleshooting. |
| `stalker_refresh_interval` | `60` | Wi-Fi Stalker polling interval in seconds (10-3600). |
| `webhook_allow_private_ips` | `true` | Allow webhooks to LAN targets such as Home Assistant, ntfy or n8n. Cloud metadata and link-local addresses stay blocked. |

## Data and backups

Everything lives in `/data`: the SQLite database and `encryption.key`. Both are part
of Home Assistant backups (cold backup: the app is stopped briefly so the database is
consistent) and must be restored together. If the key is lost, saved
UniFi credentials cannot be decrypted and must be entered again.

## Security

- Only the Home Assistant Ingress gateway can connect; other peers get HTTP 403.
- Authentication is provided by Home Assistant. The Toolkit's own login is disabled.
- **House Arrest can create and delete firewall rules.** The Toolkit has no read-only
  mode, so limit the permissions of the API key you give it accordingly.
- The panel makes no external requests: Alpine.js and Chart.js are bundled at build
  time (checksum verified), Google Fonts are removed and upstream's GitHub update
  check is answered locally. Updates arrive through Home Assistant, not the Toolkit UI.
- Python dependencies are pinned via `constraints.txt` for reproducible builds.
- The advertisement banner for the author's consulting service at the bottom of the dashboard is not shown in this app (the "Get Help" button in the header and its page stay).
- Links to GitHub, Ko-fi and the author's website inside the Toolkit UI are ordinary links: they open only when you click them, the app itself never calls them.
- If the Toolkit process crashes, the app stops. Turn on the **Watchdog** switch of the app so Home Assistant starts it again.

## Local and external access

**Local (LAN):** open **UniFi Toolkit** in the Home Assistant sidebar. The app has no
host port and is only reachable through Home Assistant Ingress, so the Home Assistant
login protects it.

**External (internet):** recommendation **VPN only**. The Toolkit manages your network
(House Arrest creates and deletes firewall rules, Wi-Fi Stalker can block clients), so
anyone who gets into your Home Assistant can use it. Do not publish the app by
port-forwarding (there is no port to forward) and do not reach Home Assistant from the
internet without two-factor authentication.

## First start

On a fresh database upstream logs a migration warning ("no such table") before it
creates the schema. This is upstream behaviour and harmless.

## License

UniFi Toolkit is MIT licensed, Copyright (c) 2025 Crosstalk Solutions. The license
text ships inside the image at `/app/LICENSE`. Bundled Alpine.js and Chart.js are
MIT licensed.
