# TeamSpeak 6 Server — Documentation

## Quick Start

1. Set **Accept TeamSpeak License** to `true` (required!)
2. Optionally set a **ServerQuery admin password** (`query_admin_password`)
3. Click **Start**
4. Check the **Log** tab for the first-time admin **privilege key (token)**
5. Connect with your TeamSpeak 6 client to `<your-ha-ip>:9987`

Server name, server password and slot count are not add-on options; set them in the TeamSpeak client or through ServerQuery.

## Finding the Privilege Key

On first start, look in the log for a line like:

```
token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

In your TeamSpeak client: **Permissions → Use Privilege Key** → paste the token. It is only shown once. If you left `query_admin_password` empty, the log also shows the generated password of the ServerQuery login `serveradmin`.

## Local and external access

**Local (LAN):** connect to `<ha-host>:9987` (UDP). The ServerQuery ports `10011` (raw), `10022` (SSH) and `10080` (HTTP) are published on the host as well. They are meant for the LAN: anyone who reaches them and knows (or, with an empty `query_admin_password`, has read from the log) the `serveradmin` password can administer the server. Set `query_admin_password` yourself.

**External (internet):** forward only the ports friends need, to the Home Assistant host:

| Port | Protocol | Forward? |
|---|---|---|
| 9987 | UDP | yes (voice) |
| 30033 | TCP | yes, only if you want file transfer |
| 10011, 10022, 10080 | TCP | **no** — LAN or VPN only |

## Ports

The ports are fixed in the add-on. If a host port is already in use, change the host-side mapping in the add-on's **Network** tab; the clients then connect to that host port.

## Backup

The add-on stores all data in `/data/teamspeak6`, which is included in Home Assistant backups. The running server works on a copy inside the container; the add-on writes it back to `/data/teamspeak6/server` every 5 minutes and when it stops cleanly, so a crash or power loss costs at most the last 5 minutes.
