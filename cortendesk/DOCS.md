# CortenDesk

Console (devices, users, address books, groups) plus ID server and relay in one app.
The bundled server is the CortenDesk server fork (rustdesk-server 1.1.16 plus a fix for
signed-in clients from 1.4.1).

## Configuration

### Option: `app_url` (required)

Public address of the app as your clients reach it, including scheme and
console port, e.g. `http://rd.example.com:21114`. The host part is announced to the clients as
ID server (`<host>:21116`) and relay (`<host>:21117`). Without a reachable host,
sessions that need the relay hang.

### Options: `id_server` / `relay_server` (optional)

Format `host:port`, e.g. `rd.example.com:21116` or `rd.example.com:21117`. Empty = host from
`app_url` with ports 21116 or 21117. Needed if clients on the LAN and from outside use the same
instance: `hbbs` announces the same relay address to **all** clients. If it is a
LAN IP, relay sessions from outside hang. With a hostname that resolves both internally and externally
(split DNS), both work.

### Option: `admin_user` / `admin_password` (required)

First administrator. **Only takes effect on the very first start** (as long as no user exists).
Later changes of the option do not change the password; that is done in the console.

### Option: `native_webclient`

Enables the browser client. Default: off. The WebSocket ports 21118/21119 are not mapped
to the host: they listen on all addresses in the container and are therefore only reachable in the internal Docker network.
Voice calls in the browser client only work over HTTPS (or `localhost`), i.e. through a reverse proxy with TLS.

### Option: `downloads_max_mb`

Upload limit for client installers under System → Client Downloads. Default: 512 MB (as upstream).

### Option: `log_level`

Controls the log verbosity of the console (Laravel) and of the ID/relay server (`RUST_LOG`).
Values: `DEBUG`, `INFO`, `WARNING`, `ERROR`. Default: `INFO`.
Passed on to upstream as `CORTENDESK_LOG_LEVEL`, which derives `LOG_LEVEL` and `RUST_LOG` from it.

## Ports

| Port | Purpose |
|---|---|
| 21114/tcp | Console (container port 8080) |
| 21115/tcp | hbbs NAT type test |
| 21116/tcp + udp | hbbs ID server |
| 21117/tcp | hbbr relay |

Only forward 21115–21117/TCP and 21116/UDP on the router. Make the console (21114) reachable from outside
only with TLS (e.g. through a reverse proxy) and only if needed.

In the RustDesk clients: ID server = `<host>`, relay server = `<host>`, API server =
`app_url`, key = public key from the log (`key …` in the line `server …`) or in the console.

## Local and external access

**Local (LAN):** The console runs directly on port `21114` (`http://<ha-host>:21114`), not via ingress. It has its own
login (administrator from `admin_user` and `admin_password`); the app only starts once `app_url` and `admin_password`
are set (otherwise the app exits with a message in the log). RustDesk clients on the LAN talk directly to the ID server (`21115/21116`) and the relay (`21117`).

**External (internet):** Recommendation: **OK with restrictions.** For clients from outside it is enough to forward `21115–21117/TCP` and
`21116/UDP` on the router (see Ports); the ID server and relay are meant for that, and the clients check the server key. Do **not put the
console (`21114`) directly on the internet**, only behind a reverse proxy with TLS or via VPN. Never expose the
WebSocket ports `21118/21119`: `hbbs`/`hbbr` trust unchecked `X-Forwarded-For` headers there, which is why
they are not mapped to the host. Other apps in Home Assistant's internal Docker network can reach them; with
`host_network: true` they would be open on the whole LAN.

## Privacy and outgoing connections

The app does not fetch anything from the internet on its own: the update check against GitHub is switched off
(`CORTENDESK_UPDATE_CHECK=false`), the web interface loads no external scripts, fonts or trackers (checked with
upstream 1.14.0: login page and dashboard, no outbound connection when idle). Only if you set it up in the console
does CortenDesk connect to external services (Apprise notifications, SMTP, FTP/FTPS or
S3 backup copies, OIDC login). The menu item "Build Installers" is a link to the third-party service `rdgen.crayoneater.org`
and is only opened on click.

## Data and backup

Everything lives in `/data` (SQLite database, server key pair, app key, uploads) and is included in the
app backup. The backup mode is `cold` (the app is stopped briefly so the SQLite files
are consistent). **Do not lose the key pair:** without `/data/rustdesk/id_ed25519` all clients have to
be set up again. Since upstream 1.13.0 the console additionally stores its own backups under `/data/backups`
(daily at 03:30). They contain the app key and all secrets, are therefore also part of the Home Assistant backup and
must be treated like passwords.

## Known limitations

- **AppArmor is off (`apparmor: false`):** The image does not run under s6 but `supervisord` (root)
  with `php-fpm`, `nginx`, `hbbs`, `hbbr`. The bundled profile `apparmor.txt` is an untested draft in
  complain mode (only logs, blocks nothing) and is not loaded with `apparmor: false`. To test it
  on your own system, set `apparmor: true` in a local copy of the app, evaluate the log and only then remove `complain`
  from the `flags`.
- **Message at startup:** `nginx` may briefly log `connect() failed … /api/server/policy` at startup, because
  `hbbs` queries the console before `php-fpm` is ready. This is harmless and disappears after a few seconds.
- **Update check switched off:** The app sets `CORTENDESK_UPDATE_CHECK=false` (upstream from 1.11.0),
  the console no longer queries GitHub and shows no update badge. Updates come through the app version.
- **Database path:** SQLite lives in `/data/db/cortendesk.sqlite` (not `/data`), because `/data`
  belongs to root in HA and php-fpm runs as `www-data`.
- **Bridge mode untested for UDP:** Whether hbbs sees the real client IP with mapped ports
  is open. If the log shows addresses from 172.30.x.x, P2P fails and everything goes through the relay.
  Then switch to `host_network: true` (see below).
- **SQLite:** Sufficient for a few devices. A MariaDB connection is not implemented.
- **Host network:** With `host_network: true` nginx listens on port 8080 only (possible collision with
  other apps) and 21118/21119 are reachable on the LAN.
