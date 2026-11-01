# Matrix Ketesa (Admin UI)

Home Assistant app for [Ketesa](https://github.com/etkecc/ketesa) (formerly Synapse Admin), the admin web UI for a
Matrix Synapse homeserver. It serves the pinned Ketesa release behind its own login. It runs standalone next to the
`matrix_synapse` app and does not need access to it: the UI runs in your browser and talks to your homeserver directly.

See [DOCS.md](DOCS.md) for setup, credentials, network access and open items.

## Overview

| Property | Value |
|---|---|
| **Ketesa version** | `v1.5.1` |
| **App version** | `0.1.0` |
| **Port** | `8091` (basic-auth protected, LAN or VPN only) |
| **Arch** | `amd64`, `aarch64` |

## Installation

1. Open **Settings → Apps → App Store**, then **⋮ → Repositories**, and add `https://github.com/pol4rfuchs/ha-apps`.
2. Install **Matrix Ketesa (Admin UI)**.
3. Optionally set `admin_ui_username` and `admin_ui_password`. If the password is empty, one is generated on the first
   start and stored in the app config folder (`admin_ui_password.txt`).
4. Start the app and open `http://<ha-host>:8091`.
5. Sign in with the app login, then enter your homeserver URL and a Matrix admin account in the Ketesa login form.

## Options

| Option | Default | Description |
|---|---|---|
| `log_level` | `info` | `debug` logs every request, `warning` logs requests without valid credentials, `error` only failures. |
| `admin_ui_username` | `admin` | User name of the login in front of the UI (no colon). |
| `admin_ui_password` | *(empty)* | Password of that login. Empty = generated once and kept in `admin_ui_password.txt`. |

## Links

- Upstream: https://github.com/etkecc/ketesa
- Repo: https://github.com/pol4rfuchs/ha-apps
