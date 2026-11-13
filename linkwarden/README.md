# Linkwarden

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Linkwarden Version](https://img.shields.io/badge/Linkwarden-2.17.0-1E88E5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/linkwarden/linkwarden)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

[Linkwarden](https://github.com/linkwarden/linkwarden) as a Home Assistant app – a self-hosted bookmark manager that keeps a copy of every page you save (PDF, screenshot, web page copy and readable view), so your articles stay available when the original disappears. PostgreSQL is built in, nothing else has to be set up. Unofficial community app, not endorsed or supported by the upstream project.

**Status:** experimental

| Property | Value |
|---|---|
| **Upstream image** | `ghcr.io/linkwarden/linkwarden` |
| **Linkwarden version** | `2.17.0` |
| **Default port** | `3200` |
| **Arch** | `amd64`, `aarch64` |

Important: sign-up is open until you switch on `disable_registration` (after you created your account); anyone who can reach the port can create an account before that. Keep the port inside your network. AppArmor is switched off, and only `amd64` is tested so far, see [DOCS.md](DOCS.md).

## Installation

1. Open **Settings → Apps → App Store** in Home Assistant.
2. In the menu at the top right choose **Repositories** and add `https://github.com/pol4rfuchs/ha-apps`.
3. Select **Linkwarden** in the list and click **Install**.
4. Set `public_url` to the address you will open Linkwarden with, start the app and wait until the log says `Starting Linkwarden`.
5. Open `http://<ha-host>:3200` and sign up (see [DOCS.md](DOCS.md), section *First start*).

See [DOCS.md](DOCS.md) for configuration details, the optional remote browser and how to move from another Linkwarden.

## Links

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Repository ha-apps](https://github.com/pol4rfuchs/ha-apps)
- [Linkwarden (Upstream)](https://github.com/linkwarden/linkwarden)
