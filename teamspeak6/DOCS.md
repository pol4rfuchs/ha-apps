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

## AppArmor

The app runs with an AppArmor profile (`apparmor.txt`, `apparmor: true`). The Supervisor loads it when the app is installed and reloads it when the app is updated. What the profile allows:

- **Write access** only to `/data`, `/tmp`, `/run` and the app's own folders (`/var/tsserver`, the runtime copy of the server data). Other files are read-only or not accessible (apart from the usual device files such as `/dev/null`).
- **Programs and scripts** run only from the system folders of the image and the app's own program folders.
- **Capabilities:** the standard Docker set without `net_raw`.
- **Network:** TCP, UDP, IPv4/IPv6, Unix sockets and netlink; no raw or packet sockets.
- **Mount:** denied.

Tested by the maintainer on a Raspberry Pi 4 with HAOS 18.5, AppArmor enforcing: start, restart, backup and restore, and a restart of the whole system. Not tested: load on the TeamSpeak 6 server (many clients), and updating an app while its profile is loaded.

**If an extension of your own reports "Permission denied":** the profile blocked an access. Write to `/data` instead, or to `/tmp` for temporary files. The kernel log of the host shows `apparmor="DENIED"` lines with the blocked path (visible on the HAOS console or through the developer SSH access). If the app itself needs the path, open an issue in the repository with that line; the profile is changed in `apparmor.txt` and arrives with an app update.

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

The app stores all data in `/data/teamspeak6`, which is included in Home Assistant backups. The running server works on a copy inside the container; the app writes it back to `/data/teamspeak6/server` every 5 minutes and when it stops cleanly, so a crash or power loss costs at most the last 5 minutes. The server logs in `/data/teamspeak6/logs` are left out of backups. They are kept across restarts (one file per virtual server and one for the instance); a file over 5 MiB is cut to its last 1 MiB when the app starts.

**How a backup is made reliable:** a Home Assistant backup only contains what is already in `/data`, so the 5-minute window above would also hide the newest changes in a backup (a channel created just before the backup was missing after a restore). The app therefore sets `backup_pre`: right before the Supervisor copies `/data`, it runs `/usr/local/bin/ts6-backup-sync` in the running app. The script copies the current state to `/data/teamspeak6/server` with SQLite's online backup (the running database is not touched; no checkpoint, no files removed next to the live database) and copies the other changed files (SSH host key, allow/deny lists, file transfers). The app keeps running, nobody is disconnected. The same script does the 5-minute copy.

- A backup holds the state of the moment it starts. What is changed while the backup is being written may or may not be in it.
- The 5-minute window still applies to anything that does not go through the Supervisor (copying `/data` by hand, a snapshot of the whole disk) and to a crash or power loss.
- If the script fails, its message is in the Supervisor log and the backup may hold older data.
- Tested with a stand-in for the Supervisor (running the script in the container, archiving `/data`, restoring into an empty `/data`): a permanent channel created right before the backup was there after the restore, one created after the backup was gone. Without the script the first one was missing. Not tested with a real Supervisor backup and restore.

## Flood protection and `query_ip_allowlist`

TeamSpeak 6 locks out a query client that sends more than 10 commands within 3 seconds for 10 minutes (instance settings `serverinstance_serverquery_flood_commands=10`, `flood_time=3`, `ban_time=600`, as seen on a real system). Over the HTTP query, a request with a virtual server id counts as two commands. Tested with `6.0.0-beta13.1`: a client from another container got its first 5 requests answered, then the connection was dropped, and it stayed dropped for minutes (also for new connections); restarting TeamSpeak cleared it. TS6 Manager is such a client. The lock is the cause of its HTTP 502 errors ("client is flooding", "socket hang up").

The option `query_ip_allowlist` lists the addresses that are exempt. The app writes them, together with `127.0.0.1` and `::1`, into `query_ip_allowlist.txt` at every start, so edits of that file by hand are replaced. The default is `172.30.32.0/23`, the network of the Home Assistant apps, which keeps other apps on the same Home Assistant working. Tested: with the network in the list, 40 quick requests from another container were all answered. Entries must be an IP address or a network (IPv4 prefix 16–32, IPv6 prefix 48–128); `0.0.0.0/0`, `::/0` and other wide networks are refused and the app does not start.

The exemption is only about flooding, not about passwords. Tested from an allowlisted address: 30 wrong password attempts were not blocked by an IP lock, but after a few wrong attempts TeamSpeak refused even the correct password for at least 100 seconds. The password (or API key) is still required. Apps in the allowlisted network can still send as many correct requests as they like; if you do not want that, set the list to empty (`[]`).

## Server log (`logview`)

TeamSpeak creates the log file of a virtual server only with the first log line of that virtual server after a start. Until then the query command `logview` for that virtual server answers error 2052 (`file input/output error`); this is how `6.0.0-beta13.1` behaves, not a permission or path problem (the app runs as root and writes to `/data/teamspeak6/logs`). TS6 Manager showed it as an empty "Logs" page and an HTTP 502. The app therefore keeps the logs across restarts (one growing file per virtual server and one for the instance, `TSSERVER_APPEND_LOGS=1`), so the file of the virtual server already exists after a restart; files over 5 MiB are cut to their last 1 MiB at start. Tested: after two restarts `logview` answered right away. Error 2052 can still appear once, right after the update from an older version of this app (its first start removes the old per-start log files) until the virtual server logs its first line; TS6 Manager then shows the instance log with a note.

## ServerQuery access and `query_ip_allowlist.txt`

The file `query_ip_allowlist.txt` (written by the app from the option `query_ip_allowlist`, see above) is **not** an access list. In TeamSpeak it names the addresses that are exempt from the flood protection of the query interface; `query_ip_denylist.txt` is the list of blocked addresses. Tested with `6.0.0-beta13.1`: from another container (not `127.0.0.1`) the SSH and HTTP query interfaces were reachable, and a login with the correct `serveradmin` password or API key worked. So the only protection of ServerQuery is the password: keep ports `10022` and `10080` inside your LAN (or VPN) and set `query_admin_password`.

TeamSpeak allows **guests** (no password, no API key) on the SSH and HTTP query interfaces by default. The app switches both off (`TSSERVER_QUERY_SSH_ALLOW_GUEST=0` and `TSSERVER_QUERY_HTTP_ALLOW_GUEST=0`). Tested with `6.0.0-beta13.1`: without the setting a guest could log in over SSH without a password and was only refused individual commands over HTTP; with the setting the SSH guest login is refused and the HTTP interface answers `api key missing`. Logins with the `serveradmin` password (SSH) and with an API key (HTTP) still work. If one of your tools relied on guest access, it needs the password or an API key now.
