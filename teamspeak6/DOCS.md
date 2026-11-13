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

**How a backup is made reliable:** a Home Assistant backup only contains what is already in `/data`, so the 5-minute window above would also hide the newest changes in a backup (a channel created just before the backup was missing after a restore). The app therefore sets `backup_pre`: right before the Supervisor copies `/data`, it runs `/usr/local/bin/ts6-backup-sync` in the running app. The script copies the current state to `/data/teamspeak6/server` with SQLite's online backup (the running database is not touched; no checkpoint, no files removed next to the live database) and copies the other changed files (SSH host key, allow/deny lists, file transfers). The app keeps running, nobody is disconnected. The same script does the 5-minute copy.

- A backup holds the state of the moment it starts. What is changed while the backup is being written may or may not be in it.
- The 5-minute window still applies to anything that does not go through the Supervisor (copying `/data` by hand, a snapshot of the whole disk) and to a crash or power loss.
- If the script fails, its message is in the Supervisor log and the backup may hold older data.
- Tested with a stand-in for the Supervisor (running the script in the container, archiving `/data`, restoring into an empty `/data`): a permanent channel created right before the backup was there after the restore, one created after the backup was gone. Without the script the first one was missing. Not tested with a real Supervisor backup and restore.

## ServerQuery access and `query_ip_allowlist.txt`

The file `query_ip_allowlist.txt` (default content `127.0.0.1`) is **not** an access list. In TeamSpeak it names the addresses that are exempt from the flood protection of the query interface; `query_ip_denylist.txt` is the list of blocked addresses. Tested with `6.0.0-beta13.1`: from another container (not `127.0.0.1`) the SSH and HTTP query interfaces were reachable, and a login with the correct `serveradmin` password or API key worked. So the only protection of ServerQuery is the password: keep ports `10022` and `10080` inside your LAN (or VPN) and set `query_admin_password`.

TeamSpeak allows **guests** (no password, no API key) on the SSH and HTTP query interfaces by default. The app switches both off (`TSSERVER_QUERY_SSH_ALLOW_GUEST=0` and `TSSERVER_QUERY_HTTP_ALLOW_GUEST=0`). Tested with `6.0.0-beta13.1`: without the setting a guest could log in over SSH without a password and was only refused individual commands over HTTP; with the setting the SSH guest login is refused and the HTTP interface answers `api key missing`. Logins with the `serveradmin` password (SSH) and with an API key (HTTP) still work. If one of your tools relied on guest access, it needs the password or an API key now.
