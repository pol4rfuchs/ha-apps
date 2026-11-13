# TeamSpeak 6 Server — Documentation

## Quick Start

1. Set **Accept TeamSpeak License** to `true` (required!)
2. Optionally set a **ServerQuery admin password** (`query_admin_password`)
3. Click **Start**
4. Check the **Log** tab for the first-time admin **privilege key (token)**
5. Connect with your TeamSpeak 6 client to `<your-ha-ip>:9987`

Server name, server password and slot count are not app options; set them in the TeamSpeak client or through ServerQuery.

## Finding the Privilege Key

On first start, look in the log for a line like:

```
token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

In your TeamSpeak client: **Permissions → Use Privilege Key** → paste the token. It is only shown once. The generated ServerQuery password and API key of the first start are hidden in the log (the app replaces them with `<hidden>`). Set `query_admin_password` to get a ServerQuery login you know.

## Local and external access

**Local (LAN):** connect to `<ha-host>:9987` (UDP). The ServerQuery ports `10022` (SSH) and `10080` (HTTP) are published on the host as well. There is no raw ServerQuery port (`10011`) in TeamSpeak 6. The two ports are meant for the LAN: anyone who reaches them and knows the `serveradmin` password (or its API key) can administer the server. Set `query_admin_password` yourself. It is applied at every start, so you can set or change it at any time (tested); restart the app afterwards.

**External (internet):** forward only the ports friends need, to the Home Assistant host:

| Port | Protocol | Forward? |
|---|---|---|
| 9987 | UDP | yes (voice) |
| 30033 | TCP | yes, only if you want file transfer |
| 10022, 10080 | TCP | **no** — LAN or VPN only |

## Ports

The ports are fixed in the app. If a host port is already in use, change the host-side mapping in the app's **Network** tab; the clients then connect to that host port.

## Backup

The app stores all data in `/data/teamspeak6`, which is included in Home Assistant backups. The running server works on a copy inside the container; the app writes it back to `/data/teamspeak6/server` every 5 minutes and when it stops cleanly, so a crash or power loss costs at most the last 5 minutes. The server logs in `/data/teamspeak6/logs` are left out of backups; they are cleared on every start anyway.

## ServerQuery access and `query_ip_allowlist.txt`

The file `query_ip_allowlist.txt` (default content `127.0.0.1`) is **not** an access list. In TeamSpeak it names the addresses that are exempt from the flood protection of the query interface; `query_ip_denylist.txt` is the list of blocked addresses. Tested with `6.0.0-beta13.1`: from another container (not `127.0.0.1`) the SSH and HTTP query interfaces were reachable, and a login with the correct `serveradmin` password or API key worked. So the only protection of ServerQuery is the password: keep ports `10022` and `10080` inside your LAN (or VPN) and set `query_admin_password`.

According to the server's `--help`, both interfaces also accept **guests** without a password (`--query-ssh-allow-guest` and `--query-http-allow-guest` default to on). In a test over HTTP a guest was refused `serverlist` (`command not allowed for guest access`) and `clientlist` (insufficient permissions); which commands a guest may run was not checked, and guest access over SSH was not tested. It is one more reason not to expose these ports.
