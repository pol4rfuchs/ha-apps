# NetBox

NetBox is an IP address management (IPAM) and data center infrastructure management (DCIM) tool. This app runs the NetBox build of [netbox-docker](https://github.com/netbox-community/netbox-docker) together with PostgreSQL 18 and Valkey 9 in one container. The database and Valkey only listen on `127.0.0.1` inside the container; nothing but the web UI (port `8001`) is reachable from outside.

## Requirements

- About 1 GB of free RAM. Measured on amd64 in Docker: roughly 320 MB idle with one worker, each further worker adds several hundred MB, and the database migration of a first start peaks at about 1 GB. This was not measured on a Raspberry Pi.
- **No ingress.** NetBox is opened directly on port `8001`.
- The first start (and every update that changes the database) applies migrations. On a Raspberry Pi this takes several minutes. Until it is done the port answers with `503` and a short message, and the health check counts the app as healthy.

## First start

1. Set `allowed_hosts` to the addresses you will use (for example the IP of your Home Assistant host and, if you use one, the domain of your reverse proxy). Without it any host name is accepted and a warning is logged.
2. Start the app and wait for `Starting NetBox on port 8001` in the log.
3. There is **no default account.** Either:
   - set `admin_password` before the first start, or
   - leave it empty: the app creates the user from `admin_username` with a random password and writes it to `initial_admin_password.txt` in the app's configuration folder (on the Home Assistant host: `/addon_configs/<id>_netbox/`, reachable with the File editor, Samba or SSH app). The log only shows the first four characters.
4. Open `http://<ha-host>:8001`, log in, change the password and delete `initial_admin_password.txt`.

The user is only created if it does not exist yet. Changing `admin_password` later does not change an existing password; do that in the NetBox UI (or reset it with `manage.py changepassword` inside the container).

## Configuration

### `log_level`

Verbosity of the log output of the app, NetBox, PostgreSQL and Valkey. Use `debug` only for troubleshooting (it also switches on the web access log).

Default: `info`

### `admin_username`

Name of the first superuser.

Default: `admin`

### `admin_password`

Password of the first superuser, used only when the user is created. Empty = a random password is generated (see *First start*).

Default: –

### `admin_email`

Optional e-mail address of the first superuser.

Default: –

### `allowed_hosts`

Host names and addresses under which NetBox is opened. NetBox answers `400 Bad Request` for any other `Host` header. Empty = any host is accepted.

Default: `[]`

### `csrf_trusted_origins`

Origins (with `https://`) from which NetBox is opened through a reverse proxy, for example `https://netbox.example.org`. Without the matching entry a login behind a proxy fails with a CSRF error.

Default: `[]`

### `time_zone`

Time zone of NetBox, for example `Europe/Berlin`. Empty = the time zone of Home Assistant; an unknown name falls back to `UTC`.

Default: –

### `workers`

Number of web worker processes (1–4). Each worker needs several hundred MB of RAM.

Default: `2`

### `plugins`

NetBox plugins, each as `module` (the Python module, for example `netbox_qrcode`) and `pip` (the PyPI package with an **exact** version, for example `netbox-qrcode==1.0.0`). See *Plugins*.

Default: `[]`

## Plugins

Plugins are optional and off by default. Every entry must pin an exact version (`name==version`); ranges, URLs and options are refused and the app stops with a message.

- The packages are downloaded from PyPI **when the list changes** (or after a NetBox update that changes its dependencies) and kept in `/data/netbox/plugins`. This is the only step where the app contacts the Internet; later starts do not need it.
- Install only plugins you trust. They run inside NetBox with access to its database.
- The versions of NetBox's own dependencies are used as constraints, so a plugin cannot replace them. If it needs a conflicting version, the install fails and the app does not start; remove the entry again.
- Check that the plugin supports the NetBox version of this app before you add it.
- Removing an entry removes the installed package at the next start, but the plugin's tables stay in the database.
- Plugin settings (`PLUGINS_CONFIG`) go into `extra.py`, see below. If a plugin needs the Internet itself, add `ISOLATED_DEPLOYMENT = False` there.

## Extra settings (`extra.py`)

Settings that have no option (LDAP, SSO, e-mail, `PLUGINS_CONFIG`, …) go into the file `extra.py` in the app's configuration folder (`/addon_configs/<id>_netbox/extra.py`). It is read at every start as Python code in the NetBox settings, so it can set or override any [NetBox setting](https://netboxlabs.com/docs/netbox/en/stable/configuration/):

```python
PLUGINS_CONFIG["my_plugin"] = {"some_setting": "value"}
EMAIL = {"SERVER": "mail.example.org", "PORT": 587, "USE_TLS": True, "FROM_EMAIL": "netbox@example.org"}
```

Only put code in this file that you wrote or have read; it runs with the rights of NetBox. A syntax error stops NetBox from starting.

## What the app sets on purpose

- The database password, `SECRET_KEY` and the API token pepper are generated at the first start, stored in `/data/netbox/secrets` and never shown. The database password is set again at every start.
- NetBox does not call the Internet by itself: census reporting and the Copilot agent are switched off, `ISOLATED_DEPLOYMENT` is on, and there is no release check. Links in the UI (documentation, GitHub) are ordinary links that only open when you click them. The bundled documentation under `/static/docs/` is stripped of its Google Fonts links at build time.
- Login is required for every page (`LOGIN_REQUIRED` stays on).
- PostgreSQL, Valkey and NetBox run as their own unprivileged users.

## Backup and restore

The backup type is `cold`: the Supervisor stops the app, copies `/data` and starts it again, so the PostgreSQL files are consistent. Everything lives in `/data/netbox`: `postgresql` (database), `valkey` (job queue), `media` (uploaded images), `scripts` and `reports`, `plugins`, `secrets`.

- Restore the backup as a whole. The secrets belong to the database; `SECRET_KEY` and the API token pepper from another installation will not work with it.
- The app **does not migrate PostgreSQL across major versions** (it is 18 now). If an update ships a new major version, the app refuses to start and says so in the log; the changelog announces it. Before such an update make a dump with `pg_dump` from the running old app, and restore it into the new one.
- NetBox's own updates (new NetBox version) migrate the database automatically at the next start. Take a backup first.

## Local and external access

**Local (LAN):** open `http://<ha-host>:8001`. NetBox has its own login (users, groups, object permissions and API tokens), and every page needs it. There is no `ssl` option, the app serves plain HTTP. NetBox itself does not need HTTPS for the UI to work, but passwords and API tokens then cross your network unencrypted; use a reverse proxy with TLS if that matters to you.

**External (internet):** recommendation **only VPN.** A NetBox database describes your whole network (addresses, devices, cabling, credentials in comments and custom fields), so it is a target and should not sit on the public Internet. If you still publish it, use only a reverse proxy with TLS (for example Nginx Proxy Manager), never forward port `8001` directly, and:

- set `allowed_hosts` to the public domain, and `csrf_trusted_origins` to `https://<that domain>`,
- use a strong admin password and give every person their own user with the least permissions they need,
- keep the app updated (NetBox publishes security fixes in patch releases).

The reverse proxy connects to `http://<ha-host>:8001`. NetBox trusts the `X-Forwarded-*` headers of private network addresses only.

## Troubleshooting

- **`Bad Request (400)`:** the address in the browser is not in `allowed_hosts`.
- **`CSRF verification failed` behind a proxy:** add the proxy origin to `csrf_trusted_origins`.
- **The page shows `NetBox is starting` (503):** a migration is still running; check the log.
- **`Memory overcommit must be enabled` in the log:** a hint from Valkey about a host setting. It does not stop the app; background saves could fail when the host is almost out of memory.
- **The app does not start after a change to `plugins`:** read the log; the message names the entry or the pip error.
