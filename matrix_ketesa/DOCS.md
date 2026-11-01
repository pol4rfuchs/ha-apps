# Matrix Ketesa (Admin UI)

Ketesa (formerly Synapse Admin) is the admin web UI for Matrix Synapse: users, rooms, media, federation, registration
tokens and more. This app packages the pinned upstream release (a static single-page app) together with a small
login in front of it.

## How it works

- The app serves the Ketesa files from the image on port `8091`. Every request needs the app login (HTTP basic auth).
- Ketesa itself runs in your **browser**. After the app login you enter the URL of your homeserver and sign in with a
  Matrix account that has admin rights. The browser talks to the homeserver directly; this app never connects to Synapse.
- Two logins therefore apply: the app login (this app) and the Matrix admin login (your homeserver).

## Requirements

- A Matrix Synapse homeserver whose URL your browser can reach (for the `matrix_synapse` app this is the public HTTPS
  address behind your reverse proxy). The admin API (`/_synapse/admin`) must not be blocked by the proxy.
- A Matrix account with admin rights on that homeserver (see the `matrix_synapse` app for how to create the first one).

## Configuration

### Option: `log_level`

`debug` logs every request, `warning` logs requests without valid credentials, `error` only failures. Default: `info`.
Credentials are never written to the log.

### Options: `admin_ui_username` / `admin_ui_password`

Credentials of the login in front of the UI. The user name must not contain a colon.

If `admin_ui_password` is empty, a random password is generated on the first start and stored in the app config
folder as `admin_ui_password.txt` (on the host: `/addon_configs/<slug>_matrix_ketesa/`, mode 600). It is reused on
every later start. Setting the option overrides the file. The password is not printed to the log.

## Local and external access

**Local (LAN):** open `http://<ha-host>:8091`. There is no ingress. The login uses HTTP basic auth, which sends the
credentials with every request, so over plain `http` they are readable on the network. Use it on a trusted LAN, or put
a reverse proxy with TLS in front of it.

**External (internet):** recommendation **VPN only.** Ketesa administers your whole homeserver, so do not forward
port `8091` and do not publish it through the reverse proxy. Only your Matrix homeserver itself needs to be
reachable from outside, never this UI.

## Migrating from the bundled Ketesa in `matrix_synapse`

`matrix_synapse` still contains its own copy of Ketesa on port `8090` (options `enable_synapse_admin`,
`admin_ui_username`, `admin_ui_password`). This app replaces it:

1. Install and start this app, set the credentials and open port `8091`.
2. Check that you can sign in to your homeserver.
3. After that you can switch off `enable_synapse_admin` in `matrix_synapse`.

The old copy is removed from `matrix_synapse` in a later release, announced in that app's changelog.

## Updates

The Ketesa version is pinned in the Dockerfile (`ARG KETESA_VERSION`). Renovate proposes new upstream versions, and a
new app version brings the update. The running app needs no internet access.

## Data and backup

The only state is `admin_ui_password.txt` in the app config folder. It is part of the Home Assistant backup of the
app and, like any password, should be treated as a secret.

## Privacy

The server part of this app makes no outbound connections. What the Ketesa UI itself loads in your browser was not
verified for this app; check it before using the UI in an environment where external requests matter.

## Open items

- **AppArmor is off** (`apparmor: false`): `apparmor.txt` is an untested draft in complain mode. It needs a test run on
  a Pi before it can be switched on.
- **No upstream checksum:** the release tarball is fetched over TLS from the pinned tag at build time; no upstream
  checksum is verified.
- **Not yet tested on a Pi/HAOS:** the Supervisor option validation and the start as a real app are only covered by CI.
- `icon.png` and `logo.png` are placeholders, not the upstream logo.
