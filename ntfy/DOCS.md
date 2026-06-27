# Home Assistant Add-on: ntfy

Self-hosted push notification service. Send notifications to your phone, desktop or browser via a simple HTTP POST — no third-party servers, fully under your control.

---

## Quick Start

### Step 1 — Install the add-on

1. **Settings → Add-ons → Add-on Store** → ⋮ (top right) → **Repositories**
2. Add: `https://github.com/pol4rfuchs/ha-apps`
3. Search for **ntfy**, click **Install**

### Step 2 — Configure

Go to the add-on **Configuration** tab and set at minimum:

```yaml
admin_username: admin
admin_password: your-secure-password
```

This creates an admin account automatically on first start. All other settings are optional.

### Step 3 — Start

Click **Start**. Check the **Log** tab — you should see:

```
Starting ntfy add-on …
Admin user 'admin' ready
HA integration token created:
  tk_XXXXXXXXXXXXXXXX
  Saved to: /data/ntfy/ha_token.txt
Starting ntfy → http://homeassistant.local:4280
```

### Step 4 — Open the web UI

> ⚠️ **Do NOT use the HA sidebar link** — it will show a white screen (known incompatibility with HA Ingress). Always open ntfy directly:

```
http://homeassistant.local:4280
```

Log in with the `admin_username` / `admin_password` you configured.

---

## Token Auto-Provisioning

On first startup, the add-on automatically creates a persistent API token for the admin user and saves it to:

```
/data/ntfy/ha_token.txt
```

The token is printed clearly in the **Log** tab on first start. Copy it once and store it in `secrets.yaml`:

```yaml
ntfy_token: tk_XXXXXXXXXXXXXXXX
```

On subsequent restarts the file already exists — no duplicate token is created.

If the token is lost, delete `/data/ntfy/ha_token.txt` and restart the add-on to generate a new one.

---

## Admin / Management UI

This add-on no longer ships its own management UI. For a full web-based admin interface, install the separate **ntfy_manager** add-on (same repository).

`ntfy_manager` talks to this add-on's API directly — no extra configuration needed here once both are running. It covers:

- **Overview** — health, version, stats, uptime, user count
- **Send** — compose and send test notifications, with live preview
- **Users** — create, delete, change password
- **Tokens** — create personal access tokens
- **Access Control** — per-user, per-topic permissions (wildcards supported, e.g. `ha-*` or `*`)
- **Reservations** — reserve topics for your account
- **Messages** — browse cached notifications across topics
- **Server** — connection info + auto-generated `rest_command` snippet for `configuration.yaml`
- **Debug** — live SSE connection monitor

See the ntfy_manager add-on's own documentation for setup, login, and a page-by-page walkthrough.

---

## Home Assistant Integration

### Option A — HA ntfy Integration (recommended)

1. **Settings → Devices & Services → Add Integration** → search **ntfy**
2. Enter server URL: `http://homeassistant.local:4280`
3. Enter your admin username and the token from `ha_token.txt` (or create one in the Tokens tab)

### Option B — rest\_command (manual)

The **ntfy_manager** add-on's Server tab generates this snippet automatically with your actual base URL. Add to `configuration.yaml`:

```yaml
rest_command:
  ntfy_notify:
    url: "http://homeassistant.local:4280/{{ topic }}"
    method: POST
    headers:
      Authorization: "Bearer {{ secret('ntfy_token') }}"
      Title: "{{ title | default('') }}"
      Priority: "{{ priority | default('3') }}"
      Tags: "{{ tags | default('') }}"
    payload: "{{ message }}"
    content_type: "text/plain"
```

Store the token in `secrets.yaml`:

```yaml
ntfy_token: tk_XXXXXXXXXXXXXXXX
```

Automation example:

```yaml
action:
  - service: rest_command.ntfy_notify
    data:
      topic: ha-alerts
      message: "Front door opened"
      title: "Door Alert"
      priority: "4"
      tags: "door,warning"
```

---

## Configuration Reference

| Option | Default | Description |
|--------|---------|-------------|
| `log_level` | INFO | `TRACE` / `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `base_url` | — | External URL (e.g. `https://ntfy.your-domain.com`). Required for attachments, iOS push, and **UnifiedPush / Matrix Push Gateway**. |
| `behind_proxy` | false | Set to `true` if running behind Nginx / Traefik / Caddy |
| `auth_default_access` | deny-all | Unauthenticated access: `deny-all` · `read-only` · `write-only` · `read-write` |
| `enable_signup` | true | Allow self-registration via web UI |
| `enable_login` | true | Show login form in web UI |
| `enable_reservations` | false | Allow users to reserve topic names |
| `cache_duration` | 12h | How long messages are cached (e.g. `12h`, `7d`) |
| `attachment_file_size_limit` | 15M | Max size per attachment — requires `base_url` |
| `attachment_total_size_limit` | 5G | Total attachment storage — requires `base_url` |
| `keepalive_interval` | 45s | Keepalive for SSE/WebSocket connections |
| `upstream_base_url` | — | iOS push: set to `https://ntfy.sh` — requires `base_url` |
| `admin_username` | — | Admin account username — created automatically on startup |
| `admin_password` | — | Admin account password |

---

## CLI Access (docker exec)

When you exec into the container, `NTFY_AUTH_FILE` is set automatically — no manual export needed:

```bash
# These all work immediately without any setup:
ntfy user list
ntfy access
ntfy token list admin
```

Three wrapper functions are also available to avoid interactive password prompts:

```bash
# Add user (role defaults to "user")
ntfy_adduser myuser mypassword
ntfy_adduser myadmin mypassword admin

# Change password
ntfy_passwd myuser newpassword

# Create token
ntfy_token myuser "Home Assistant"
```

Running the raw `ntfy user add` or `ntfy user change-pass` commands directly will still prompt for a password interactively — use the wrappers above instead.

---

## Reverse Proxy (Nginx)

```nginx
location / {
    proxy_pass http://localhost:4280;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_buffering off;
    proxy_read_timeout 3600s;
}
```

Set `behind_proxy: true` and `base_url: "https://ntfy.your-domain.com"`.

---

## UnifiedPush (Android Push via Element / FluffyChat)

ntfy kann als **UnifiedPush Distributor** und als **Matrix Push Gateway** dienen — damit erhalten Android-Clients wie Element oder FluffyChat Push-Nachrichten über deinen eigenen Server, ohne Google FCM.

### Voraussetzungen

**`base_url` muss gesetzt sein.** Ohne `base_url` ist der Matrix Push Gateway Endpoint (`/_matrix/push/v1/notify`) nicht aktiv. Im Log erscheint dann beim Start eine deutliche Warnung.

### Wie es funktioniert

```
Element Android
  → wählt ntfy als UnifiedPush Distributor
  → registriert sich bei deinem ntfy-Server (Topic wird automatisch erstellt)
  → trägt als Pusher bei Synapse ein:
      Push Gateway URL: https://ntfy.deine-domain.tld/_matrix/push/v1/notify

Synapse
  → sendet Nachrichten-Pushes an den ntfy Gateway
  → ntfy liefert die Nachricht an dein Gerät

Kein Google, kein Firebase, kein externer Dienst.
```

### Einrichtung Schritt für Schritt

**1. ntfy Add-on:** `base_url` auf deine externe ntfy-URL setzen, Addon neu starten. Log zeigt:
```
UnifiedPush / Matrix Push Gateway aktiv:
  https://ntfy.deine-domain.tld/_matrix/push/v1/notify
```

**2. ntfy App auf Android:** F-Droid Version installieren (die Play Store Version hat kein UnifiedPush). Server in den App-Einstellungen auf deine `base_url` setzen. Die App läuft danach als UnifiedPush Distributor im Hintergrund.

**3. Element Android:** Einstellungen → Benachrichtigungen → ntfy als Distributor auswählen. Element registriert sich automatisch bei Synapse. Kein manueller Eingriff in Synapse nötig.

**4. Prüfen:** Gateway erreichbar?
```bash
curl -X POST https://ntfy.deine-domain.tld/_matrix/push/v1/notify
# Erwartete Antwort: 400 Bad Request (kein JSON) — Gateway ist aktiv
```

### Auth-Hinweis

Der Endpoint `/_matrix/push/v1/notify` ist von der normalen ACL ausgenommen und immer öffentlich — auch wenn `auth_default_access: deny-all` gesetzt ist. Synapse muss den Endpoint ohne Credentials erreichen können.

---

## iOS Push Notifications

For native iOS push (no polling), set:

```yaml
upstream_base_url: "https://ntfy.sh"
base_url: "https://ntfy.your-domain.com"
```

---

## Backup

All data is stored in `/data/ntfy/` and included in HA backups automatically:

| Path | Contents |
|------|----------|
| `user.db` | Users, passwords, tokens, ACL rules |
| `ha_token.txt` | Auto-provisioned HA integration token |
| `cache/cache.db` | Message cache |
| `attachments/` | File attachments (only if `base_url` is set) |

---

## Known Limitations

| Issue | Explanation |
|-------|-------------|
| **White screen in HA sidebar** | ntfy's SPA uses absolute asset paths — incompatible with HA Ingress. Use the direct URL `:4280` instead of the HA sidebar link. |
| **Token listing not available via API** | ntfy's REST API has no endpoint to list a user's existing tokens. Create tokens via ntfy_manager's Tokens tab; view/revoke existing ones in the ntfy Web UI → Account → Access Tokens. |
| **Cannot change a user's role after creation** | ntfy's API has no endpoint for role changes on existing users. Workaround: set `admin_username` in this add-on's config for admin accounts. |
| **Cannot delete/modify admin accounts via the API** | ntfy returns 401 for admin-role accounts on these endpoints. Manage admin accounts via this add-on's configuration only. |
| **`hijacked connection` in logs** | Harmless — appears when a client drops a WebSocket/SSE connection unexpectedly. No action needed. |
| **Interactive password prompt in raw CLI** | `ntfy user add` and `ntfy user change-pass` prompt for a password when called directly. Use the `ntfy_adduser` / `ntfy_passwd` wrapper functions instead. |
