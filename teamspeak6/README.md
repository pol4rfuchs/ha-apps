<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/teamspeak6/logo.png" alt="TeamSpeak 6 Server Logo" width="500">

# TeamSpeak 6 Server Home Assistant App

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-teamspeak6--ha--app-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/teamspeak6-ha-app)
[![TS6 Version](https://img.shields.io/badge/TeamSpeak%206-v6.0.0--beta12.1-F39C12?style=for-the-badge&logo=teamspeak&logoColor=white)](https://github.com/teamspeak/teamspeak6-server)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

### WIKI
[TS6-Wiki](https://github.com/pol4rfuchs/ha-apps/wiki)

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)

> **DISCLAIMER:** This is an unofficial, community-maintained Home Assistant add-on. Not affiliated with or endorsed by the TeamSpeak Systems, Inc..
## Add-ons in this repository


### [TeamSpeak 6 Server](./teamspeak6)

Run a TeamSpeak 6 voice server natively on your Raspberry Pi 4 via Home Assistant.

- ARM64 (aarch64) native
- Full UI configuration: ports, server name, password, max clients
- Persistent data storage
- Based on the official `teamspeaksystems/teamspeak6-server` image

## How to use

1. Click the badge above **or** manually add the repository URL in Home Assistant:  
   `Settings → Add-ons → Add-on Store → ⋮ → Repositories`

2. Install the **TeamSpeak 6 Server** add-on.

3. Accept the TeamSpeak license in the Configuration tab and start.


# 🎙️ TeamSpeak 6 Server — Home Assistant App

<div align="center">

![TS6 Banner](https://img.shields.io/badge/TeamSpeak%206-Server-blue?style=for-the-badge&logo=teamspeak&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%204-c51a4a?style=for-the-badge&logo=raspberry-pi&logoColor=white)
![Arch](https://img.shields.io/badge/Arch-aarch64%20%2F%20ARM64-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-Apache%202.0-green?style=for-the-badge)

**A fully configured Home Assistant Add-on that runs a TeamSpeak 6 voice server natively on the Raspberry Pi 4 — fully manageable through the HA UI.**

</div>

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Sources & Docker Images](#-sources--docker-images)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Ports & Networking](#-ports--networking)
- [First Start & Admin Token](#-first-start--admin-token)
- [Data Persistence & Backup](#-data-persistence--backup)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)

---

## 🧭 Overview

This repository contains a complete **Home Assistant Add-on** (formerly: Hass.io addon) that runs a **TeamSpeak 6 Server** on ARM64 hardware (Raspberry Pi 4).

| Property | Value |
|---|---|
| **HA Addon Slug** | `teamspeak6` |
| **Add-on version** | `1.1.17` |
| **Architecture** | `aarch64` (ARM64) |
| **Architecture** | `x64` (AMD64) |
| **Startup** | `application` |
| **Boot** | `auto` |
| **Persistence** | `/data/teamspeak6` |
| **Base Image** | `teamspeaksystems/teamspeak6-server:<pinned version>` |

> ℹ️ The add-on is built on top of publicly available community Docker images that provide the official TS6 server for Raspberry Pi via Box64 emulation or native ARM compilation.

---

## ✅ Prerequisites

Before you start, make sure the following is in place:

- 🏠 **Home Assistant OS** or **Home Assistant Supervised** (not Core/Container)
- 🍓 **Raspberry Pi 4** (2 GB RAM or more recommended)
- 🌐 **Internet access** on the Pi (for the image download)
- 📋 **TeamSpeak Server License** (free, must be accepted)

---

## 🐳 Sources & Docker Images

This add-on supports two community-maintained ARM ports of the official TeamSpeak 6 server. Both can be used as a base image.

### Option A — `indogermane/teamspeak6-server-arm`

> Native ARM64 build, regularly updated

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-indogermane%2Fteamspeak6--server--arm-2496ED?style=flat-square&logo=docker&logoColor=white)](https://hub.docker.com/r/indogermane/teamspeak6-server-arm/tags)

```
docker pull indogermane/teamspeak6-server-arm:latest
```

| Property | Details |
|---|---|
| Maintainer | `indogermane` |
| Platform | `linux/arm64` |
| Last Updated | regularly |
| Pulls | ~680+ |

---

### Option B — `fezlight/teamspeak6-server-arm`

> x86-64 TS6 via Box64 emulation on ARM, alternative base

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-fezlight%2Fteamspeak6--server--arm-2496ED?style=flat-square&logo=docker&logoColor=white)](https://hub.docker.com/r/fezlight/teamspeak6-server-arm/tags)

```
docker pull fezlight/teamspeak6-server-arm:latest
```

| Property | Details |
|---|---|
| Maintainer | `fezlight` |
| Platform | `linux/arm64` (via Box64) |
| Last Updated | regularly |

---

> 🔄 **Switching images:** To use a different base image, update the `image:` field in `teamspeak6/config.yaml` and `build_from.aarch64:` in `teamspeak6/build.yaml` accordingly.

---

## 🚀 Installation

### Step 1 — Publish the repository on Gitea/GitHub

```bash
# Clone or extract the ZIP
git init ha-teamspeak6-addon
cd ha-teamspeak6-addon

# Add files
git add .
git commit -m "feat: initial TeamSpeak 6 addon"

# Push to your remote (must be public!)
git push -u origin main
```

> ⚠️ The repository **must be public** so that Home Assistant can access it.

---

### Step 2 — Add the repository in Home Assistant

Navigate in Home Assistant to:

```
Settings → Add-ons → Add-on Store → ⋮ (three dots) → Repositories
```

Paste the URL of your repository:

```
https://github.com/pol4rfuchs/ha-apps
```

or via one-click badge:

## Installation

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)
---

### Step 3 — Install the add-on

1. After adding the repository, **"TeamSpeak 6 Server"** will appear in the Add-on Store
2. Click **Install**
3. Wait for the download to complete (~1–2 minutes)

---

### Step 4 — Accept the license & start

1. Go to the **Configuration** tab
2. Enable the **"Accept TeamSpeak License"** toggle → `true`
3. Click **Save**
4. Go back to **Info** and click **Start**
5. Open the **Log** tab and wait for the first start

---

## ⚙️ Configuration

All settings are fully accessible through the Home Assistant UI.  
Tab: `Settings → Add-ons → TeamSpeak 6 Server → Configuration`

### 🖥️ Basic Server Settings

| Option | Default | Type | Description |
|---|---|---|---|
| `server_name` | `Home Assistant TeamSpeak Server` | `str` | Display name of the server in the client |
| `server_password` | *(empty)* | `str` | Password to join. Leave empty = open server |
| `max_clients` | `32` | `int (1–1024)` | Maximum simultaneous connections |
| `welcome_message` | `Welcome to our TeamSpeak Server!` | `str` | Greeting text shown on connect |

### 🔐 Query & Admin

| Option | Default | Type | Description |
|---|---|---|---|
| `query_admin_password` | *(empty)* | `str` | Password for the `serveradmin` account. Empty = auto-generated (check the logs!) |

### 📊 Logging

| Option | Default | Type | Description |
|---|---|---|---|
| `log_level` | `3` | `int (0–4)` | `0`=Critical · `1`=Error · `2`=Warning · `3`=Info · `4`=Debug |

### 🪪 License

| Option | Default | Type | Description |
|---|---|---|---|
| `license_accepted` | `false` | `bool` | **Required.** Must be `true`, otherwise the server will not start |

### 🔌 Port Configuration

| Option | Default | Type | Description |
|---|---|---|---|
| `voice_port` | `9987` | `int (1–65535)` | UDP port for voice connections |
| `filetransfer_port` | `30033` | `int (1–65535)` | TCP port for file transfers |
| `query_port` | `10011` | `int (1–65535)` | TCP raw ServerQuery |
| `query_ssh_port` | `10022` | `int (1–65535)` | TCP SSH ServerQuery |
| `query_http_port` | `10080` | `int (1–65535)` | TCP HTTP ServerQuery |

> 💡 **Tip:** When changing ports, also update the **Network mappings** in the **Network** tab so that the host port and container port match.

---

## 🌐 Ports & Networking

### Default Port Overview

| Port | Protocol | Purpose | Expose externally |
|---|---|---|---|
| `9987` | **UDP** | Voice — clients connect here | ✅ Yes |
| `30033` | TCP | File transfers | ✅ Yes (optional) |
| `10011` | TCP | Raw ServerQuery Interface | ⛔ No |
| `10022` | TCP | SSH ServerQuery Interface | ⛔ No |
| `10080` | TCP | HTTP ServerQuery Interface | ⛔ No |

### Router Port Forwarding (external access)

To allow users outside your local network to connect, forward the following ports on your router:

```
UDP  9987  → <raspberry-pi-ip>:9987   (Voice)
TCP 30033  → <raspberry-pi-ip>:30033  (optional, file transfer)
```

> 🔒 The query ports (10011, 10022, 10080) should **not** be publicly exposed — they are used for server administration and pose a security risk if left unprotected.

---

## 🔑 First Start & Admin Token

### Finding the Privilege Key (Token)

On the **very first start**, TeamSpeak 6 generates a one-time **privilege key** that grants the first user full server admin rights.

**Where to find it:**

```
Add-on → Log tab → look for this line:

token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**How to use it:**

1. Connect to the server with the TeamSpeak 6 client (`<pi-ip>:9987`)
2. In the client: **Permissions → Use Privilege Key**
3. Paste the token and confirm

> ⚠️ **Important:** The token is only shown once and can only be used once. Save it immediately! If lost, a new one can be created via the ServerQuery interface (`10011`).

### ServerQuery Admin Access

If `query_admin_password` was left empty, the password is auto-generated and shown in the log:

```
ServerAdmin password: <generated-password>
```

---

## 💾 Data Persistence & Backup

### Data Directory

All server data is stored persistently at the following path:

```
/data/teamspeak6/
├── ts6server.sqlitedb      ← Main database (virtual servers, permissions, channels)
├── ts6server.sqlitedb-wal  ← Write-Ahead Log
├── ts6server.sqlitedb-shm  ← Shared Memory
├── ts6.ini                 ← Generated configuration file
├── serveradmin_password    ← Query admin password (600 permissions)
├── query_ip_allowlist.txt  ← Query IP whitelist
├── query_ip_denylist.txt   ← Query IP blacklist
└── logs/                   ← Server logs
    └── ts6server_*.log
```

### Home Assistant Backup

The `/data` directory is **automatically** included in HA backups.

```
Settings → System → Backups → Create Backup
```

A full backup includes all server data including channels, permissions, users and settings.

---

## 📁 Project Structure

### File Roles

| File | Role | HA Reference |
|---|---|---|
| `repository.yaml` | Identifies the repo as an HA addon repository | [Docs](https://developers.home-assistant.io/docs/apps/repository) |
| `config.yaml` | Core configuration: arch, ports, schema, options | [Docs](https://developers.home-assistant.io/docs/apps/configuration) |
| `build.yaml` | Defines the base Docker image per architecture | [Docs](https://developers.home-assistant.io/docs/apps/tutorial) |
| `translations/en.yaml` | Localized labels for the config UI | [Docs](https://developers.home-assistant.io/docs/apps/presentation) |
| `rootfs/run.sh` | Executed on startup, reads `options.json` | — |

---

## 🔧 Troubleshooting

### ❌ Server won't start

```
[ERROR] You must accept the TeamSpeak Server License
```

**Fix:** Open Configuration → set the **"Accept TeamSpeak License"** toggle to `true` → Save → Restart.

---

### ❌ Token was missed / not noted down

**Fix via ServerQuery (local):**

```bash
# Connect via telnet on the query port
telnet <pi-ip> 10011

# Login as serveradmin
login serveradmin <your-query-password>

# Select virtual server 1
use sid=1

# Create a new privilege key
tokenadd tokentype=0 tokenid1=6 tokenid2=0
```

---

### ❌ Clients can't connect from outside

**Checklist:**

- [ ] UDP port `9987` forwarded on the router?
- [ ] Firewall on the Pi allows UDP 9987?
- [ ] Using the correct external IP?
- [ ] Voice port in HA config matches the Network tab mapping?

```bash
# Test if port is open (externally via nmap)
nmap -sU -p 9987 <your-external-ip>
```

---

### ❌ Port conflict

```
Error: address already in use
```

**Fix:** Set a different port value in the **Configuration** tab (e.g. `19987` instead of `9987`) and update the host port mapping in the **Network** tab accordingly.

---

### ❌ Binary not found

The startup script automatically searches for the TS6 binary. If it still can't be found:

1. Check the **Log** tab to see which directories were searched
2. Inspect the Docker image: `docker run --rm indogermane/teamspeak6-server-arm:latest ls -la /`
3. If necessary, hardcode the path in `run.sh`

---

### 📋 Log Analysis

| Log Entry | Meaning |
|---|---|
| `token=xxx...` | One-time admin privilege key → **save it immediately!** |
| `ServerAdmin password: xxx` | Auto-generated query password |
| `listening on 0.0.0.0:9987` | Server is running and waiting for connections ✅ |
| `license check failed` | License not accepted or file missing |
| `bind failed` | Port already in use → choose a different port |

---

## 📝 Changelog

### v1.0.0 — Initial Release

- ✅ Full ARM64 / aarch64 support (Raspberry Pi 4)
- ✅ All 5 ports configurable via HA UI
- ✅ Server name, password, max clients, welcome message via UI
- ✅ License acceptance enforced via UI toggle
- ✅ Automatic persistence under `/data/teamspeak6`
- ✅ English UI translations (`translations/en.yaml`)
- ✅ Based on the official `teamspeaksystems/teamspeak6-server` image and `fezlight/teamspeak6-server-arm`

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream TeamSpeak 6 Server software is not relicensed by this
repository and remains subject to the TeamSpeak Server License Agreement.

Upstream:

- TeamSpeak 6 Server: https://github.com/teamspeak/teamspeak6-server
- Vendor legal terms: https://teamspeak.com/en/privacy-and-legal/ts-server-license-agreement/

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)
---

<div align="center">

Made with ❤️ for the Home Assistant community

[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=flat-square&logo=home-assistant&logoColor=white)](https://www.home-assistant.io)
[![Docker](https://img.shields.io/badge/Docker-ARM64-2496ED?style=flat-square&logo=docker&logoColor=white)](https://hub.docker.com/r/indogermane/teamspeak6-server-arm)
[![TeamSpeak](https://img.shields.io/badge/TeamSpeak-6-blue?style=flat-square&logo=teamspeak&logoColor=white)](https://teamspeak.com)

</div>

