# TeamSpeak 6 Server — Home Assistant Add-on

Run a **TeamSpeak 6 voice server** directly on your Raspberry Pi 4 via Home Assistant.

## Features

- ARM64 native (Raspberry Pi 4 / aarch64)
- All ports configurable through the HA UI
- Persistent TeamSpeak runtime data stored under `/data/teamspeak6/server` (survives restarts/updates)
- Server Query access via raw TCP, SSH, and HTTP

## Installation

1. In Home Assistant go to **Settings → Add-ons → Add-on Store**
2. Click the three-dot menu (⋮) → **Repositories**
3. Add this repository URL:  `https://codeberg.org/Pol4rFuchs/teamspeak6-ha-app`
4. Find **TeamSpeak 6 Server** in the store and click **Install**

## Configuration

| Option | Default | Description |
|---|---|---|
| `server_name` | `Home Assistant TeamSpeak Server` | Display name of the server |
| `server_password` | *(empty)* | Password to join. Leave empty for open server. |
| `max_clients` | `32` | Max simultaneous clients (1–1024) |
| `query_admin_password` | *(empty)* | ServerQuery admin password. Auto-generated if empty — check logs on first start! |
| `welcome_message` | `Welcome to our TeamSpeak Server!` | Greeting shown on connect |
| `log_level` | `3` | 0=Critical · 1=Error · 2=Warning · 3=Info · 4=Debug |
| `voice_port` | `9987` | UDP voice port |
| `filetransfer_port` | `30033` | TCP file transfer port |
| `query_port` | `10011` | TCP raw ServerQuery port |
| `query_ssh_port` | `10022` | TCP SSH ServerQuery port |
| `query_http_port` | `10080` | TCP HTTP ServerQuery port |
| `license_accepted` | `false` | **Must be set to true** before the server will start |

## ⚠️ License

You **must** accept the [TeamSpeak Server License Agreement](https://teamspeak.com/en/privacy-and-legal/ts-server-license-agreement/) before the server can start.  
Enable the **"Accept TeamSpeak License"** toggle in the add-on configuration.

## First Start — Finding Your Admin Token

On the very first start, TeamSpeak generates a **privilege key** (token) for the first server admin.  
Check the **add-on log** immediately after first start:

```Precomputing puzzle, this may take some seconds... This is the Part were it takes LONG Time on Pi 4 !
------------------------------------------------------------------
2026-02-21 13:16:54.584315|INFO    |SQL           |   |updated permissions to version 25
2026-02-21 13:16:54.665649|INFO    |SQL           |   |updated permissions to version 26
2026-02-21 13:16:54.754401|WARNING |Accounting    |   |Unable to open /opt/teamspeak/licensekey.dat
2026-02-21 13:16:54.789944|INFO    |Accounting    |   |Licensing Information
2026-02-21 13:16:54.792417|INFO    |Accounting    |   |licensed to       : TeamSpeak Systems GmbH
2026-02-21 13:16:54.794977|INFO    |Accounting    |   |type              : No License
2026-02-21 13:16:54.800811|INFO    |Accounting    |   |starting date     : Thu Jan 15 00:00:00 2026
2026-02-21 13:16:54.803858|INFO    |Accounting    |   |ending date       : Fri May  1 00:00:00 2026
2026-02-21 13:16:54.806324|INFO    |Accounting    |   |max virtualservers: 1
2026-02-21 13:16:54.808809|INFO    |Accounting    |   |max slots         : 32
2026-02-21 13:16:59.499724|INFO    |              |   |Precomputing puzzle, this may take some seconds...
```

```
token=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Copy this token, connect to the server with your TeamSpeak client, then go to **Permissions → Use Privilege Key** and paste it.  
This grants you full server admin rights.

## Ports

| Port | Protocol | Purpose |
|---|---|---|
| `9987` | UDP | Voice (clients connect here) |
| `30033` | TCP | File transfers |
| `10011` | TCP | Raw ServerQuery |
| `10022` | TCP | SSH ServerQuery |
| `10080` | TCP | HTTP ServerQuery |

Make sure these ports are forwarded in your router if you want external access.

## Data Persistence

Persistent TeamSpeak runtime data is stored in `/data/teamspeak6/server`. Logs and helper markers remain in `/data/teamspeak6`.

On every add-on start, `/var/tsserver` is re-linked to `/data/teamspeak6/server`, so the official TeamSpeak image keeps using the same persisted state across restarts and updates.

## Troubleshooting

- **Server won't start**: Make sure `license_accepted` is set to `true`.
- **Lost admin token**: Check the logs from the very first start.
- **Port conflict**: Change port numbers in the Configuration tab and map them differently in the Network tab.
- **Can't connect externally**: Check your router's port forwarding for UDP 9987.
