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

## Admin Panel

The admin panel is a full management interface included with this add-on.

### Enable it

In the **Configuration** tab, set:

```yaml
admin_panel: true
```

Then restart the add-on. Access at:

```
http://homeassistant.local:4281
```

> ⚠️ The white screen warning is also shown directly in the admin panel sidebar after login — no need to remember this from the docs.

### Login

Enter the ntfy server URL (`http://homeassistant.local:4280`), your admin username and password. You must have the **admin** role to log in.

---

### Overview tab

Shows live KPIs (server health, session uptime, message count, user count), system status probes against the ntfy API, and connection info. Click **Probe** to refresh.

---

### Send tab

Send a test notification:

1. Enter a **Topic** (e.g. `ha-notify`)
2. Optionally set **Title**, **Priority**, **Tags**, **Click URL**
3. Enter a **Message**
4. Click **Send**

The live preview on the right updates as you type, showing exactly what recipients will see.

---

### Users tab

| Action | How |
|--------|-----|
| **Create user** | Click **Create user** → fill in username + password → confirm. New users always get the **user** role. |
| **Change password** | Click **Change PW** next to a user. |
| **Delete user** | Click **Delete** next to a user. |
| **Change role** | Not supported via API. To promote a user to admin: add them as `admin_username` in config and restart. |

> Admin accounts show **"managed via config"** — they cannot be deleted or have their password changed via the panel. Use the add-on configuration for that.

---

### Tokens tab

| Action | How |
|--------|-----|
| **Create token** | Click **Create token** → enter a label → confirm. Token is copied to clipboard automatically. |
| **View / delete tokens** | Not available here due to browser CORS restrictions (port 4281 → 4280). Use ntfy Web UI → **Account → Access Tokens** instead. |

> The HA integration token created at startup (`ha_token.txt`) does not appear here automatically. It is visible in the ntfy Web UI under Account → Access Tokens.

---

### Access Control tab

Manage per-user, per-topic permissions:

| Action | How |
|--------|-----|
| **View rules** | Lists all ACL grants from all users. |
| **Add / update rule** | Select user, enter topic (wildcards supported: `ha-*` or `*`), choose permission → **Save Rule**. |
| **Delete rule** | Click **Delete** next to a row. |

Permissions: `read-write` · `read-only` · `write-only` · `deny-all`

> Admin users have global access — no ACL entries needed for them.
> `*` (anonymous) controls what unauthenticated clients can do.

---

### Reservations tab

Reserve topics so only your admin account can publish to them:

| Action | How |
|--------|-----|
| **Reserve topic** | Enter topic name, choose what everyone else can do → **Reserve**. |
| **Delete reservation** | Click **Delete** next to a row. |

Recommended topics to reserve: `ha-alerts` `ha-system` `ha-notify`

---

### Messages tab

Browse cached notifications without opening the ntfy web UI:

- Enter one or more comma-separated topics
- Set a time range and message limit
- Click **Fetch Messages**

Shows total count, topics hit, high-priority count, and a card per message with title, body, tags and timestamp.

---

### Server tab

Shows live server configuration (base URL, health, version, admin user, auth mode) and an auto-generated `rest_command` YAML snippet ready to paste into `configuration.yaml`.

---

### Debug tab

Two tools:

**SSE Connection Monitor** — opens a live Server-Sent Events stream to one or more topics. Shows connection state, reconnect counter, and a live log of every message received. Useful for verifying that HA automations are delivering notifications correctly.

**API Call Log** — records every API call made by the admin panel with method, URL, HTTP status and response body. Click **Run diagnostics** to probe all main endpoints at once.

---

## Home Assistant Integration

### Option A — HA ntfy Integration (recommended)

1. **Settings → Devices & Services → Add Integration** → search **ntfy**
2. Enter server URL: `http://homeassistant.local:4280`
3. Enter your admin username and the token from `ha_token.txt` (or create one in the Tokens tab)

### Option B — rest\_command (manual)

The admin panel **Server tab** generates this snippet automatically with your actual base URL. Add to `configuration.yaml`:

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
| `admin_panel` | false | Enable admin panel on port 4281 |
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
| **White screen in HA sidebar** | ntfy's SPA uses absolute asset paths — incompatible with HA Ingress. Use direct URL `:4280`. The admin panel sidebar shows this warning and a direct link after login. |
| **Token list not shown in admin panel** | Browser CORS restriction between port 4281 and 4280. Create tokens in the Tokens tab; view/delete in ntfy Web UI → Account → Access Tokens. |
| **Cannot change role via admin panel** | ntfy API does not support role changes for existing users. Workaround: use `admin_username` in config for admin accounts. |
| **Cannot delete/modify admin accounts via panel** | ntfy API returns 401 for admin-role accounts. Manage admins via add-on config only. |
| **`hijacked connection` in logs** | Harmless — appears when a client drops a WebSocket/SSE connection unexpectedly. No action needed. |
| **Interactive password prompt in raw CLI** | `ntfy user add` and `ntfy user change-pass` prompt for a password when called directly. Use the `ntfy_adduser` / `ntfy_passwd` wrapper functions instead. |
