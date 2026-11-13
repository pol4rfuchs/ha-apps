# Linkwarden

Linkwarden is a self-hosted bookmark manager that keeps a copy of every page you save: a PDF, a screenshot, a copy of the web page and a readable view. This app runs the official Linkwarden image content (web app and worker) together with PostgreSQL in one container. The database only listens on `127.0.0.1` inside the container; nothing but the web UI (port `3200`) is reachable from outside.

## Requirements

- **No ingress.** Linkwarden is opened directly on port `3200`.
- Archiving PDFs and screenshots needs a browser. The app brings Chromium; alternatively it can use a remote browser (see *Remote browser*). The RAM use of the app was **not measured**, and not on a Raspberry Pi at all.
- Only `amd64` was built and tested so far. `aarch64` (Raspberry Pi) is not tested yet.

## First start

1. Set `public_url` to the address you will use to open Linkwarden, for example `http://<ha-host>:3200`. Logging in only works through this address. Without it a warning is logged and `http://localhost:3200` is used.
2. Start the app and wait for `Starting Linkwarden on port 3200` in the log. The first start creates the database and applies the migrations.
3. Open `http://<ha-host>:3200` and sign up. The first account you create is yours.

**Sign-up is open until you close it.** Anyone who can reach port `3200` can create an account (tested: the API accepts a new user without any login). After you have created your own account, switch on `disable_registration` and restart the app (tested: the API then refuses new accounts). Keep the port inside your network in any case, see *Local and external access*.

## Configuration

### `log_level`

Verbosity of the log output of Linkwarden and PostgreSQL: `debug`, `info`, `warning` or `error`. The Linkwarden processes drop console messages below the chosen level; PostgreSQL always logs its start and stop messages.

### `public_url`

The address under which you open Linkwarden, with `http://` or `https://`, for example `https://links.example.org`. It is passed to the login component as its base address. With a reverse proxy, use the public address of the proxy.

### `browser_url`

Optional URL of a remote browser. Empty (the default) means the built-in Chromium. See *Remote browser*. The value is stored like a password because the URL usually holds a token.

### `disable_browser`

Switches the archiving of web pages off completely. In a test **all four formats** (PDF, screenshot, web page copy, readable view) stayed unavailable, and only the link itself was saved. Chromium was still started; whether this saves RAM was not measured.

### `disable_registration`

Refuses new accounts (default `false`). Create your own account first and switch it on afterwards: with it on before the first account exists, nobody can sign up. It does not remove existing accounts.

### `archive_take_count`

How many links the worker takes per round, for archiving and for the automatic tagging of Linkwarden (default `1`, range 1 to 10). Raise it only if the host has plenty of RAM and CPU.

## Remote browser

A remote browser takes the load of PDFs and screenshots off the Raspberry Pi. It must speak the Chrome DevTools protocol, for example [Browserless](https://github.com/browserless/browserless). Set `browser_url` to its address:

- `ws://<host>:3000?token=<token>` for Browserless with a token, or
- `http://<host>:9222` for a Chromium with remote debugging.

How the app handles it:

- The browser is checked **every time the worker starts**. If it can be reached, the worker uses it (log: `Using the remote browser at <host>:<port>`). If not, the worker uses the built-in Chromium and logs a warning. The app does not crash.
- The worker does not look again while it runs. If the remote browser comes back later, restart the app; a restarted worker (for example after a crash) checks again.
- Only the host is logged. Anything that looks like a credential in a query parameter (`token=`, `apikey=`, `key=`, `password=`, `secret=`) is replaced by `<hidden>` in the log, also in the line that the Linkwarden worker prints itself.
- Tested with a Chromium with remote debugging as a stand-in. A real Browserless instance was not tested with this app.

## Moving from another Linkwarden

Use the JSON export of the old installation and import it here (both are in the Linkwarden settings). The app does not read the database or the files of another installation. The import saves links, collections and tags; every page is then archived again.

- Pages that no longer exist have **no snapshot** after the import. Keep the old installation (stopped, not removed) until everything is archived again.
- Archiving many links at once is heavy for a Raspberry Pi. Keep `archive_take_count` at `1` and let it run.

## What the app sets on purpose

- The database password and the login secret are generated at the first start, stored in `/data/linkwarden/secrets` and never shown. The database password is set again at every start.
- Linkwarden **does not archive addresses in private networks**. In a test, a page on a Docker-internal address was refused; other private addresses were not tried. That is its own protection against requests to internal services, and this app does not switch it off.
- PostgreSQL runs as its own unprivileged user, the web app and the worker as the unprivileged user `linkwarden`.
- If PostgreSQL or the web app crashes (also if the system kills it for lack of memory), the container stops, so the Supervisor sees it. The worker is restarted automatically.
- AppArmor is switched off (`apparmor: false`), like in the NetBox app, until a profile has been tested on a Raspberry Pi.
- Stopping the app takes a few seconds: the worker is ended 5 seconds after the stop signal, then PostgreSQL shuts down cleanly.

## Backup and restore

The backup type is `cold`: the Supervisor stops the app, copies `/data` and starts it again, so the PostgreSQL files are consistent. Everything lives in `/data/linkwarden`: `postgresql` (database), `library` (the archived pages, PDFs and screenshots, this is the big part) and `secrets`.

- Restore the backup as a whole. The secrets belong to the database.
- The app **does not migrate PostgreSQL across major versions** (it is 15 now). If an update ships a new major version, the app refuses to start and says so in the log; the changelog announces it. There is no automatic migration and no tested dump and restore path. Before such an update make a backup and a JSON export of your links (see *Moving from another Linkwarden*).
- Updates of Linkwarden itself migrate the database at the next start. Take a backup first.
- Not tested yet: backup and restore through the Home Assistant Supervisor.

## Local and external access

**Local (LAN):** open `http://<ha-host>:3200`. Linkwarden has its own login. There is no `ssl` option, the app serves plain HTTP, so passwords cross your network unencrypted. Use a reverse proxy with TLS if that matters to you.

**External (internet):** recommendation **only VPN.** Your bookmarks and archived pages can contain private data, and sign-up is open (see *First start*). If you still publish it, use only a reverse proxy with TLS (for example Nginx Proxy Manager), never forward port `3200` directly, and set `public_url` to the public `https://` address.

The reverse proxy connects to `http://<ha-host>:3200`.

## Troubleshooting

- **Login returns to the login page or fails:** `public_url` does not match the address in the browser (including `http` or `https` and the port).
- **A link from your own network is not archived:** private network addresses are blocked by Linkwarden, see *What the app sets on purpose*.
- **`The remote browser at <host> is not reachable` in the log:** the app uses the built-in Chromium. Check the address, the port and the token; restart the app when the browser is up.
- **A page has no PDF or no screenshot:** the page may block headless browsers or take very long to load. The other formats are still created.
- **The app stops right after it starts and says it found another PostgreSQL version:** see *Backup and restore*.
