<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/ntfy/logo.png" alt="ntfy Logo" width="500">

## ntfy Home Assistant App

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ntfy--ha--app-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ntfy-ha-app)
[![ha-apps Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![ntfy Version](https://img.shields.io/badge/based%20on%20ntfy-v2.27.0-2ECC71?style=for-the-badge&logo=ntfy&logoColor=white)](https://github.com/binwiederhier/ntfy)
[![App Version](https://img.shields.io/badge/ntfy--ha--app-v1.2.6-2ECC71?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)
[![AI Assisted](https://img.shields.io/badge/AI%20Assisted-Claude%20Code-C2410C?style=for-the-badge&logo=anthropic&logoColor=white&labelColor=2D2D2D)](https://www.anthropic.com/claude-code)

**Self-hosted Push Notifications für Home Assistant — direkt auf deinem HAOS, ohne fremde Push-Server, sauber per HTTP/API steuerbar.**

</div>

---
### WIKI
[ntfy Documentation](https://github.com/pol4rfuchs/ha-apps/tree/main/ntfy)


## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)

> **DISCLAIMER:** This is an unofficial, community-maintained Home Assistant add-on.  
> Not affiliated with or endorsed by the ntfy project or Binwiederhier.

---

## Add-ons in this repository

### [ntfy](./ntfy)

Run a self-hosted ntfy server directly inside Home Assistant.

- Push notifications to phone, desktop and browser
- HTTP publish API
- Authentication with users, passwords, tokens and ACL rules
- Companion **ntfy_manager** add-on available for a full web admin UI
- HA integration token auto-provisioning
- Persistent data under `/data/ntfy`
- Multi-arch support: `amd64`, `aarch64`

## How to use

1. Click the badge above **or** manually add the repository URL in Home Assistant:  
   `Settings → Add-ons → Add-on Store → ⋮ → Repositories`

2. Install the **ntfy** add-on.

3. Set your admin credentials in the **Configuration** tab.

4. Start the add-on and copy the generated HA integration token from the log.

5. Open ntfy directly at:

```text
http://homeassistant.local:4280
```

> ⚠️ **Important:** Do **not** use the HA sidebar link for the ntfy web UI if it shows a white screen.  
> That is a known HA Ingress incompatibility. Use the direct URL on port `4280`.

---

# 🔔 ntfy — Home Assistant App

<div align="center">

![ntfy](https://img.shields.io/badge/ntfy-Self--Hosted%20Push-2ECC71?style=for-the-badge&logo=ntfy&logoColor=white)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)
![Admin UI](https://img.shields.io/badge/Admin%20UI-ntfy__manager%20add--on-F39C12?style=for-the-badge)
![API](https://img.shields.io/badge/API-HTTP%20Publish-8E44AD?style=for-the-badge)

**Kurz gesagt: ntfy ist dein eigener Push-Server für Home Assistant — schnell, lokal kontrollierbar und ideal für Automationen, Alerts und Systemmeldungen.**

</div>

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Features](#-features)
- [Installation](#-installation-1)
- [First Start](#-first-start)
- [Configuration](#-configuration)
- [Admin / Management UI](#-admin--management-ui)
- [Home Assistant Integration](#-home-assistant-integration)
- [Ports & Networking](#-ports--networking)
- [CLI Reference](#-cli-reference)
- [Data Persistence & Backup](#-data-persistence--backup)
- [Known Issues](#-known-issues)
- [Examples](#-examples)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)
- [Security Notes](#-security-notes)
- [Documentation](#-documentation)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🧭 Overview

This repository contains a complete **Home Assistant Add-on** that runs a self-hosted [`ntfy`](https://github.com/binwiederhier/ntfy) server.

| Property | Value |
|---|---|
| **HA Add-on Name** | `ntfy` |
| **HA Add-on Slug** | `ntfy` |
| **Based on** | `ntfy v2.27.0` |
| **App Version** | `v1.2.6` |
| **Web UI Port** | `4280` |
| **Main Data Path** | `/data/ntfy` |
| **Auth Database** | `/data/ntfy/user.db` |
| **HA Token File** | `/data/ntfy/ha_token.txt` |
| **Architectures** | `amd64`, `aarch64` |

> ℹ️ ntfy is simple by design: publish a message via HTTP, receive it on your phone, desktop or browser.  
> Für Home Assistant ist das perfekt für Systemmeldungen, Alarmierungen, Status-Infos und eigene Automationen.

---

## ✅ Prerequisites

Before you start, make sure this is in place:

- 🏠 **Home Assistant OS** or **Home Assistant Supervised**
- 🌐 Network access from your devices to the ntfy URL
- 🔐 Admin username and secure admin password
- 📱 ntfy app on Android/iOS/Desktop/Browser, if you want push clients
- 🧠 Basic understanding of topics, users and tokens

Recommended:

- A reverse proxy if exposing ntfy externally
- HTTPS when used outside your LAN
- Topic ACLs when multiple users/devices are involved
- Home Assistant backup before bigger changes

---

## ✨ Features

### 📱 Push Notifications

- Send notifications to phone, desktop and browser
- Publish via simple HTTP requests
- Use topics like `ha-alerts`, `ha-info`, `ha-system`, `ha-planty`
- Works nicely with Home Assistant automations and scripts

### 🔐 Authentication

- Admin user from add-on config
- User management
- Password changes
- API tokens
- Topic ACL rules
- Topic reservations

### 🛠️ Admin / Management UI

- This add-on no longer ships its own admin panel
- Install the separate **ntfy_manager** add-on for a full web UI: live KPIs, send with preview, users/tokens/ACLs/reservations, message browser, SSE debug monitor
- Generates Home Assistant `rest_command` examples

### 💾 Persistence

- User database under `/data/ntfy/user.db`
- HA integration token under `/data/ntfy/ha_token.txt`
- Message cache under `/data/ntfy/cache/cache.db`
- Attachments under `/data/ntfy/attachments/`

### 🏗️ Platform

- `amd64`
- `aarch64`
- HA backup integration
- Works great on Raspberry Pi 4 and x86 Home Assistant hosts

---

## 🚀 Installation

### Step 1 — Add the repository in Home Assistant

Navigate in Home Assistant to:

```text
Settings → Add-ons → Add-on Store → ⋮ → Repositories
```

Paste this repository URL:

```text
https://github.com/pol4rfuchs/ha-apps
```

or use the one-click badge:

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)

---

### Step 2 — Install the add-on

1. Open the **Add-on Store**
2. Search for **ntfy**
3. Click **Install**
4. Wait until the image is downloaded and prepared

---

### Step 3 — Minimum configuration

Open:

```text
Settings → Add-ons → ntfy → Configuration
```

Set at minimum:

```yaml
admin_username: "admin"
admin_password: "your-secure-password"
enable_signup: true
enable_login: true
```

> 🔐 Use a real password.  
> If ntfy is reachable from outside your LAN, weak credentials are a bad idea.

---

### Step 4 — Start the add-on

1. Go to the **Info** tab
2. Enable **Start on boot** if ntfy should run permanently
3. Click **Start**
4. Open the **Log** tab

On first start you should see something like:

```text
Admin user 'admin' ready
HA integration token created: tk_XXXXXXXXXXXXXXXX
Saved to: /data/ntfy/ha_token.txt
```

---

## 🧩 First Start

After the first start, copy the HA integration token from the log.

Store it in `secrets.yaml`:

```yaml
ntfy_token: "tk_XXXXXXXXXXXXXXXX"
ntfy_auth_header: "Bearer tk_XXXXXXXXXXXXXXXX"
```

> ✅ `ntfy_token` is useful for integrations.  
> ✅ `ntfy_auth_header` is useful for `rest_command` headers.

Then open ntfy directly:

```text
http://homeassistant.local:4280
```

or, if using your HA IP:

```text
http://<ha-ip>:4280
```

---

## ⚙️ Configuration

### Basic options

| Option | Example | Description |
|---|---|---|
| `admin_username` | `admin` | Admin account username |
| `admin_password` | `your-secure-password` | Admin account password |
| `enable_signup` | `true` | Allows account creation if enabled |
| `enable_login` | `true` | Enables login/auth in ntfy |

### Recommended starter config

```yaml
admin_username: "admin"
admin_password: "your-secure-password"
enable_signup: true
enable_login: true
```

> 💡 For a private HAOS setup, this is the clean starting point: login enabled and tokens managed properly. Install the **ntfy_manager** add-on alongside this one for a web admin UI.

---

## 🛠️ Admin / Management UI

This add-on no longer ships its own management UI. Install the separate **ntfy_manager** add-on (same repository) for a full web admin interface.

`ntfy_manager` talks to this add-on's API directly — no extra configuration needed here once both are running.

### What's in ntfy_manager?

| View | What it does |
|---|---|
| **Overview** | Live KPIs: health, uptime, messages, users and system status probes |
| **Send** | Send notifications with live preview |
| **Users** | Create users, delete users and change passwords |
| **Tokens** | Create API tokens and copy them quickly |
| **Access Control** | View, add and delete per-user per-topic ACL rules |
| **Reservations** | Reserve topics to prevent unauthorized publishing |
| **Messages** | Browse and filter cached notifications per topic |
| **Server** | Live config display and generated Home Assistant YAML |
| **Debug** | SSE live monitor |

> ℹ️ See the **ntfy_manager** add-on's own documentation for installation, login and a page-by-page walkthrough.

---

## 🏠 Home Assistant Integration

### Option A — Official/Home Assistant ntfy integration

Recommended path:

1. Open **Settings → Devices & Services**
2. Click **Add Integration**
3. Search for **ntfy**
4. Server URL:

```text
http://homeassistant.local:4280
```

5. Token: use the token from:

```text
/data/ntfy/ha_token.txt
```

The token is also printed in the add-on log on first start.

---

### Option B — `rest_command`

Use this when you want direct control from automations/scripts.

In `secrets.yaml`:

```yaml
ntfy_auth_header: "Bearer tk_XXXXXXXXXXXXXXXX"
```

In your Home Assistant YAML:

```yaml
rest_command:
  ntfy_notify:
    url: "http://homeassistant.local:4280/{{ topic }}"
    method: "POST"
    headers:
      Authorization: !secret ntfy_auth_header
      Title: "{{ title | default('') }}"
      Priority: "{{ priority | default('3') }}"
      Tags: "{{ tags | default('') }}"
    payload: "{{ message }}"
    content_type: "text/plain"
```

Automation action example:

```yaml
action:
  - action: rest_command.ntfy_notify
    data:
      topic: "ha-alerts"
      message: "Front door opened"
      title: "Door Alert"
      priority: "4"
      tags: "door,warning"
```

> ✅ This avoids the broken pattern `Authorization: "Bearer !secret ntfy_token"`.  
> Home Assistant secrets should be used as the full header value, not embedded inside a string.

---

## 🌐 Ports & Networking

### Default port overview

| Port | Protocol | Purpose | Expose externally |
|---|---|---|---|
| `4280` | TCP | ntfy Web UI and HTTP API | Optional |

### Direct local URLs

| Service | URL |
|---|---|
| ntfy Web UI/API | `http://homeassistant.local:4280` |

### External access

If you expose ntfy outside your LAN:

- Use HTTPS
- Use authentication
- Use strong passwords
- Use ACLs
- Prefer a reverse proxy
- Do not expose management UIs (e.g. ntfy_manager) casually

> 🔒 ntfy on the internet without authentication is basically an open notification endpoint. Keep it locked down.

---

## 🧰 CLI Reference

Shell access requires the Home Assistant SSH add-on.

`NTFY_AUTH_FILE` is set automatically in the add-on shell, so normally no manual export is needed.

### Container access

```bash
docker exec -it $(docker ps | grep ntfy | awk '{print $1}') sh
```

Single command without entering the container:

```bash
docker exec -it $(docker ps | grep ntfy | awk '{print $1}') \
  sh -c 'ntfy user list'
```

---

### Wrapper functions

Available in every interactive shell session automatically:

```bash
ntfy_adduser <username> <password>
ntfy_adduser <username> <password> admin
ntfy_passwd <username> <password>
ntfy_token <username> "Label"
```

| Wrapper | What it does |
|---|---|
| `ntfy_adduser <username> <password>` | Create normal user |
| `ntfy_adduser <username> <password> admin` | Create admin user |
| `ntfy_passwd <username> <password>` | Change user password |
| `ntfy_token <username> "Label"` | Create token for user |

---

### User management

| Command | Description |
|---|---|
| `ntfy user list` | List all users and roles |
| `ntfy user del <username>` | Delete a user |
| `ntfy user change-role <username> admin` | Promote user to admin |
| `ntfy user change-role <username> user` | Demote user to normal user |

---

### Token management

| Command | Description |
|---|---|
| `ntfy token list <username>` | List all tokens for a user |
| `ntfy token add --label="HA" <username>` | Create token with label |
| `ntfy token add --expires=30d <username>` | Create token with expiry |
| `ntfy token del <username> <token>` | Delete a token |

---

### Access Control

| Command | Description |
|---|---|
| `ntfy access` | Show all ACL rules |
| `ntfy access <username> <topic> read-write` | Grant read and write |
| `ntfy access <username> <topic> read-only` | Grant read-only |
| `ntfy access <username> <topic> write-only` | Grant write-only |
| `ntfy access <username> <topic> deny` | Deny access |
| `ntfy access --reset` | Remove all ACL rules |

> ACL rules can also be managed via the **ntfy_manager** add-on under Access Control.

---

### Publish

| Command | Description |
|---|---|
| `ntfy publish <topic> <message>` | Send a simple message |
| `ntfy publish --title="Alert" <topic> <message>` | Send with title |
| `ntfy publish --priority=5 <topic> <message>` | Send with max priority |

> CLI changes take effect immediately. No add-on restart required.

---

## 💾 Data Persistence & Backup

All important data lives in:

```text
/data/ntfy/
```

### Data directory

```text
/data/ntfy/
├── user.db          ← users, passwords, tokens and ACL rules
├── ha_token.txt     ← auto-provisioned HA integration token
├── cache/
│   └── cache.db     ← cached messages
└── attachments/     ← file attachments, requires base_url
```

### What is stored where?

| Path | Contents |
|---|---|
| `/data/ntfy/user.db` | Users, password hashes, tokens and ACL rules |
| `/data/ntfy/ha_token.txt` | Auto-created Home Assistant integration token |
| `/data/ntfy/cache/cache.db` | Message cache |
| `/data/ntfy/attachments/` | File attachments |

### Home Assistant Backup

Home Assistant backups include the add-on `/data` directory.

```text
Settings → System → Backups → Create Backup
```

A full backup should preserve:

- Users
- Passwords
- Tokens
- ACL rules
- HA integration token
- Message cache
- Attachments

> ✅ Before major updates: create a Home Assistant backup.  
> That gives you a clean rollback point.

---

## ⚠️ Known Issues

| Issue | Fix |
|---|---|
| White screen in HA sidebar | Use direct URL `http://homeassistant.local:4280` |
| Token listing not available via API | ntfy's REST API has no endpoint to list existing tokens; create via ntfy_manager, view/revoke in ntfy Web UI → Account → Access Tokens |
| Cannot change user role after creation | ntfy API limitation; use CLI or `admin_username` config for admin accounts |
| `hijacked connection` in logs | Harmless; client dropped a WebSocket/SSE connection |
| Push not arriving on phone | Check app battery optimization, topic subscription and network reachability |
| `401 Unauthorized` | Token missing, wrong or user has no topic permission |
| `403 Forbidden` | ACL blocks the topic action |

---

## 🧪 Examples

### Create HA integration token

```bash
ntfy token add --label="Home Assistant" haos
```

Copy the printed token into `secrets.yaml`.

---

### Create a second admin

```bash
ntfy user add --role=admin secondadmin
```

---

### Restrict a topic to one user

```bash
ntfy access haos HAOS read-write
ntfy access '*' HAOS deny
```

---

### Publish a test notification from CLI

```bash
ntfy publish ha-alerts "Hello from HAOS ntfy"
```

---

### Publish with title and priority

```bash
ntfy publish --title="HA Alert" --priority=5 ha-alerts "Something needs attention"
```

> Changes via CLI take effect immediately. No add-on restart required.

---

## 📁 Project Structure

Recommended repository layout:

```text
ntfy-ha-app/
├── repository.yaml
├── README.md
└── ntfy/
    ├── config.yaml
    ├── build.yaml
    ├── Dockerfile
    ├── DOCS.md
    ├── CHANGELOG.md
    ├── icon.png
    ├── logo.png
    └── rootfs/
        └── run.sh
```

### File roles

| File | Role |
|---|---|
| `repository.yaml` | Identifies the repository as a Home Assistant add-on repository |
| `ntfy/config.yaml` | Add-on metadata, ports, schema, options and UI settings |
| `ntfy/build.yaml` | Build configuration per architecture |
| `ntfy/Dockerfile` | Builds the ntfy add-on image |
| `ntfy/rootfs/run.sh` | Startup script inside the add-on |
| `ntfy/DOCS.md` | Add-on Store documentation |
| `ntfy/CHANGELOG.md` | Version history |

---

## 🔧 Troubleshooting

### ❌ Web UI shows a white screen in Home Assistant sidebar

Use the direct URL instead:

```text
http://homeassistant.local:4280
```

This is a HA Ingress/sidebar compatibility issue, not necessarily an ntfy server failure.

---

### ❌ HA integration token missing

Check the token file:

```text
/data/ntfy/ha_token.txt
```

Also check the add-on log for:

```text
HA integration token created
```

If needed, create a token manually:

```bash
ntfy token add --label="Home Assistant" haos
```

---

### ❌ Notification fails with `401 Unauthorized`

Likely causes:

- Token missing
- Token copied incorrectly
- Wrong `Authorization` header
- Token belongs to a different user
- User has no permission for the target topic

For `rest_command`, prefer:

```yaml
headers:
  Authorization: !secret ntfy_auth_header
```

with this in `secrets.yaml`:

```yaml
ntfy_auth_header: "Bearer tk_XXXXXXXXXXXXXXXX"
```

---

### ❌ Notification fails with `403 Forbidden`

Likely causes:

- ACL denies the topic
- Topic reservation belongs to another user
- User only has read-only access
- Wildcard deny rule is blocking the publish

Check ACL rules:

```bash
ntfy access
```

---

### 📋 Log Analysis

| Log Entry / Symptom | Meaning |
|---|---|
| `Admin user 'admin' ready` | Admin account exists and is usable |
| `HA integration token created` | Token for Home Assistant was generated |
| `Saved to: /data/ntfy/ha_token.txt` | Token was persisted |
| `listening on :4280` | ntfy Web UI/API is running |
| `401 Unauthorized` | Missing or invalid token |
| `403 Forbidden` | ACL or reservation blocks access |
| `hijacked connection` | Usually harmless client disconnect |
| `address already in use` | Port conflict |

---

## 🔐 Security Notes

- Use strong admin credentials.
- Do not publish your tokens.
- Do not commit `user.db`, `ha_token.txt` or generated secrets into Git.
- Keep management UIs (e.g. ntfy_manager) LAN/VPN-only if possible.
- Use HTTPS when exposing ntfy publicly.
- Use ACLs for sensitive topics.
- Prefer separate tokens per integration/device.
- Rotate tokens if one leaks.

> 🔒 Treat a ntfy token like a password. Anyone with a write-capable token can publish to the allowed topics.

---

## 📖 Documentation

Full documentation:

- [DOCS.md](ntfy/DOCS.md)
- [CLI Reference](DOCS.md#cli-reference)
- [Repository Documentation](https://github.com/pol4rfuchs/ha-apps)

Optional desktop companion:

- [ntfy Desktop app by aetherinox](https://github.com/aetherinox/ntfy-desktop)

---

## 📝 Changelog

### v1.1.6.6

- ✅ Based on ntfy `v2.22.0`
- ✅ HA integration token auto-provisioning
- ✅ Admin Panel support
- ✅ User, token and ACL management helpers
- ✅ Persistent data under `/data/ntfy`
- ✅ Multi-arch support: `amd64`, `aarch64`
- ✅ Home Assistant backup integration

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream ntfy project is not relicensed by this repository and remains
under its upstream license.

Upstream:

- ntfy: https://github.com/binwiederhier/ntfy
- Upstream license: See upstream repository

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)

---

<div align="center">

Made with ❤️ for the Home Assistant and self-hosting community

[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=flat-square&logo=home-assistant&logoColor=white)](https://www.home-assistant.io)
[![ntfy](https://img.shields.io/badge/ntfy-Self--Hosted%20Push-2ECC71?style=flat-square&logo=ntfy&logoColor=white)](https://ntfy.sh)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)

</div>
