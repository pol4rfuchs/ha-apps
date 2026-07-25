<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/ts6_manager/logo.png" alt="TS6 Manager Logo" width="500">

# TS6 Manager — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-teamspeak6--manager--ha--app-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Upstream](https://img.shields.io/badge/Upstream-clusterzx%2Fts6--manager-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/clusterzx/ts6-manager)
[![App Version](https://img.shields.io/badge/ts6--manager-1.1.2-F39C12?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)
[![License](https://img.shields.io/badge/License-MIT-2ECC71?style=for-the-badge)](LICENSE)

**Web-based Management Interface für deinen TeamSpeak 6 Server — als sauber verpacktes Home Assistant Add-on.**

</div>

---
### WIKI
[ts6-manager Documentation](https://github.com/pol4rfuchs/ha-apps/tree/main/ts6_manager)


## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)

> **DISCLAIMER:** This is an unofficial, community-maintained Home Assistant add-on wrapper for `clusterzx/ts6-manager`.  
> Not affiliated with or endorsed by TeamSpeak Systems, Inc. or the upstream project maintainer.

---

## Add-ons in this repository

### [TS6 Manager](./ts6_manager)

Run a web-based TeamSpeak 6 management panel directly as a Home Assistant Add-on.

- Web Dashboard with live stats
- Channel tree and client management
- Kick, ban, move and poke actions
- Permissions, groups, ban list and token management
- Music bots with radio, YouTube via `yt-dlp` and local library
- Bot Flow Engine with visual node editor
- Embeddable server widgets as SVG, PNG and JSON
- Persistent SQLite database under `/data`

---

# 🎛️ TS6 Manager — Home Assistant Add-on

<div align="center">

![TS6 Manager](https://img.shields.io/badge/TeamSpeak%206-Manager-blue?style=for-the-badge&logo=teamspeak&logoColor=white)
![Web UI](https://img.shields.io/badge/Web--UI-Dashboard-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)
![Port](https://img.shields.io/badge/Port-8066-F39C12?style=for-the-badge)
![Database](https://img.shields.io/badge/Database-SQLite-2ECC71?style=for-the-badge)

**Kurz gesagt: TS6 Manager ist die Web-Oberfläche für deinen TeamSpeak 6 Server — bequem über Home Assistant installiert, gestartet und gesichert.**

</div>

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Features](#-features)
- [Installation](#-installation-1)
- [First Start](#-first-start)
- [Connect to TeamSpeak 6 Server](#-connect-to-teamspeak-6-server)
- [Ports & Networking](#-ports--networking)
- [Data Persistence & Backup](#-data-persistence--backup)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)
- [Security Notes](#-security-notes)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🧭 Overview

This repository contains a complete **Home Assistant Add-on** that wraps [`clusterzx/ts6-manager`](https://github.com/clusterzx/ts6-manager) into a single add-on image.

| Property | Value |
|---|---|
| **HA Add-on Name** | `TS6 Manager` |
| **HA Add-on Slug** | `ts6_manager` |
| **Add-on Version** | `1.1.2` |
| **Default Web UI Port** | `8066` |
| **Backend Target** | TeamSpeak 6 WebQuery HTTP API |
| **TS6 WebQuery Port** | `10080` |
| **Persistence** | `/data` |
| **Database** | SQLite |
| **Music Storage** | `/data/music` |
| **Upstream Project** | [`clusterzx/ts6-manager`](https://github.com/clusterzx/ts6-manager) |

> ℹ️ Der Manager ist **nicht** der TeamSpeak Server selbst.  
> Er verbindet sich über die **WebQuery HTTP API** mit deinem vorhandenen TeamSpeak 6 Server.

---

## ✅ Prerequisites

Before you start, make sure this is already working:

- 🏠 **Home Assistant OS** or **Home Assistant Supervised**
- 🎙️ A running **TeamSpeak 6 Server**
- 🌐 **WebQuery HTTP API** enabled on the TS6 Server
- 🔌 WebQuery HTTP port reachable from the add-on, default: `10080`
- 🔑 WebQuery API key from the TeamSpeak 6 server log
- 🧠 Basic network access between Home Assistant and the TS6 server

### Required TS6 Server values

| Setting | Example |
|---|---|
| **Host** | `<Pi-IP>` or `<HA-IP>` |
| **WebQuery Port** | `10080` |
| **API Key** | From TS6 server log |
| **Protocol** | HTTP WebQuery |

> 💡 Wenn TS6 Server und TS6 Manager beide auf demselben Home Assistant Host laufen, ist meistens die lokale Host/IP-Konfiguration der wichtigste Punkt.

---

## ✨ Features

### 📊 Dashboard

- Live server stats
- Bandwidth graph
- Server status overview
- Channel tree
- Connected clients

### 👥 Client Management

- Kick clients
- Ban clients
- Move clients
- Poke clients
- Client overview and quick actions

### 🔐 Server Administration

- Permissions
- Server groups
- Ban list
- Token management
- Connection settings

### 🎵 Music Bots

- Radio streams
- YouTube support via `yt-dlp`
- Local music library
- Persistent music folder under `/data/music`

### 🤖 Bot Flow Engine

- Visual node editor
- Automation-style bot flows
- Useful for small TS6 automations without writing everything by hand

### 🧩 Embeddable Widgets

- SVG widgets
- PNG widgets
- JSON status endpoint

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
2. Search for **TS6 Manager**
3. Click **Install**
4. Wait until the image is downloaded and prepared

---

### Step 3 — Configure the network port

Default Web UI port:

```text
8066
```

If you change it in the Home Assistant **Network** tab, use the new host port when opening the Web UI.

---

### Step 4 — Start the add-on

1. Open the **Info** tab
2. Enable **Start on boot** if you want it to run permanently
3. Click **Start**
4. Open the **Log** tab and check for startup errors
5. Open the **Web UI**

---

## 🧩 First Start

On the first start, open:

```text
TS6 Manager → Open Web UI
```

Then go to:

```text
/setup
```

Create your first admin account.

> ⚠️ Save the login credentials.  
> They are stored in the manager database under `/data/ts6webui.db`.

---

## 🔌 Connect to TeamSpeak 6 Server

After creating the admin account:

```text
Settings → Connections
```

Enter your TS6 WebQuery connection:

| Field | Value |
|---|---|
| **Host** | `<Pi-IP>` |
| **WebQuery Port** | `10080` |
| **API Key** | API key from TS6 server log |

### Where to find the WebQuery API key

Open the TeamSpeak 6 Server add-on log and search for the WebQuery/API key line.

Typical place:

```text
Settings → Add-ons → TeamSpeak 6 Server → Log
```

> 🔑 The API key is generated by the TS6 Server.  
> The manager only uses it to authenticate against the WebQuery HTTP API.

---

## 🌐 Ports & Networking

### TS6 Manager Web UI

| Port | Protocol | Purpose | Expose externally |
|---|---|---|---|
| `8066` | TCP | TS6 Manager Web UI | Optional, preferably behind trusted access only |

### TeamSpeak 6 Server API dependency

| Port | Protocol | Purpose | Expose externally |
|---|---|---|---|
| `10080` | TCP | TS6 WebQuery HTTP API | ⛔ No |

> 🔒 Do **not** expose the WebQuery API port publicly.  
> Keep `10080` local/private and only reachable from trusted services.

---

## 💾 Data Persistence & Backup

All important TS6 Manager data lives under `/data`.

```text
/data/
├── ts6webui.db       ← SQLite database
├── secrets.env       ← JWT_SECRET + ENCRYPTION_KEY
└── music/            ← Downloaded music and local library
```

### What is stored where?

| Path | Content |
|---|---|
| `/data/ts6webui.db` | Users, settings, connections, manager state |
| `/data/secrets.env` | Auto-generated JWT and encryption secrets |
| `/data/music/` | Downloaded music and local music files |

### Home Assistant Backup

Home Assistant backups include the add-on `/data` directory.

```text
Settings → System → Backups → Create Backup
```

A full backup should preserve:

- Admin account
- Manager settings
- TS6 connection profiles
- Music library
- Bot/flow configuration, if stored by the upstream app in SQLite or `/data`

> ✅ Before big updates: create a Home Assistant backup.  
> That is the clean rollback point.

---

## 📁 Project Structure

Recommended repository layout:

```text
teamspeak6-manager-ha-app/
├── repository.yaml
├── README.md
└── ts6_manager/
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

### File Roles

| File | Role |
|---|---|
| `repository.yaml` | Identifies the repository as a Home Assistant add-on repository |
| `ts6_manager/config.yaml` | Add-on metadata, ports, schema, options and UI settings |
| `ts6_manager/build.yaml` | Build configuration per architecture |
| `ts6_manager/Dockerfile` | Builds the single-image TS6 Manager add-on |
| `ts6_manager/rootfs/run.sh` | Startup script inside the add-on |
| `ts6_manager/DOCS.md` | Add-on Store documentation |
| `ts6_manager/CHANGELOG.md` | Version history |

---

## 🔧 Troubleshooting

### ❌ Web UI does not open

**Checklist:**

- [ ] Add-on is started?
- [ ] Log shows no startup error?
- [ ] Port `8066` mapped in the **Network** tab?
- [ ] Browser uses the correct Home Assistant host/IP?
- [ ] No other add-on is already using the same host port?

---

### ❌ Cannot connect to TS6 Server

**Checklist:**

- [ ] TeamSpeak 6 Server is running?
- [ ] WebQuery HTTP API is enabled?
- [ ] WebQuery port is `10080`?
- [ ] API key is correct?
- [ ] Host/IP points to the TS6 server, not accidentally to the manager itself?
- [ ] TS6 Manager can reach the TS6 Server over the network?

---

### ❌ API key invalid

**Fix:**

1. Open the TeamSpeak 6 Server log
2. Copy the WebQuery API key again
3. Paste it in **Settings → Connections**
4. Save and test again

> Watch out for copied spaces, line breaks or old keys.

---

### ❌ Music bot / YouTube download fails

**Checklist:**

- [ ] `yt-dlp` is included in the image?
- [ ] Add-on has internet access?
- [ ] `/data/music` is writable?
- [ ] The target URL is supported by `yt-dlp`?
- [ ] Check the add-on logs for the exact error

---

### ❌ Database or login broken after update

**Safe recovery path:**

1. Stop the add-on
2. Create or restore a Home Assistant backup
3. Check if `/data/ts6webui.db` exists
4. Start the add-on again
5. Watch the log carefully

```text
/data/ts6webui.db
```

If this file is missing, the manager starts like a fresh installation.

---

### 📋 Log Analysis

| Log Entry / Symptom | Meaning |
|---|---|
| `listening on ... 8066` | Web UI is running |
| `database opened` | SQLite database loaded successfully |
| `permission denied` | `/data` or `/data/music` is not writable |
| `connection refused` | Target TS6 WebQuery API not reachable |
| `invalid api key` | Wrong or outdated WebQuery API key |
| `address already in use` | Port conflict on the host |

---

## 🔐 Security Notes

- Do **not** expose TS6 WebQuery port `10080` directly to the internet.
- Keep the manager behind Home Assistant authentication, VPN or trusted LAN access.
- Treat the WebQuery API key like a password.
- Back up `/data` before updates.
- Do not commit `secrets.env`, database files or API keys into Git.

---

## 📝 Changelog

### v1.0.0 — Initial Release

- ✅ Initial Home Assistant Add-on wrapper for `clusterzx/ts6-manager`
- ✅ Web UI exposed on port `8066`
- ✅ Persistent SQLite database under `/data/ts6webui.db`
- ✅ Auto-generated secrets under `/data/secrets.env`
- ✅ Persistent music directory under `/data/music`
- ✅ TeamSpeak 6 WebQuery connection support

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream `clusterzx/ts6-manager` project is not relicensed by this
repository and remains under its upstream license.

TeamSpeak 6 Server itself is not relicensed by this repository and remains
subject to the TeamSpeak Server License Agreement.

Upstream:

- TS6 Manager: https://github.com/clusterzx/ts6-manager
- TeamSpeak 6 Server: https://github.com/teamspeak/teamspeak6-server
- TeamSpeak legal terms: https://teamspeak.com/en/privacy-and-legal/ts-server-license-agreement/

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)

---

<div align="center">

Made with ❤️ for the Home Assistant and TeamSpeak community

[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=flat-square&logo=home-assistant&logoColor=white)](https://www.home-assistant.io)
[![TeamSpeak](https://img.shields.io/badge/TeamSpeak-6-blue?style=flat-square&logo=teamspeak&logoColor=white)](https://teamspeak.com)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)

</div>
