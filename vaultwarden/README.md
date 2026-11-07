# Vaultwarden

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Vaultwarden Version](https://img.shields.io/badge/Vaultwarden-1.37.5-175DDC?style=for-the-badge&logo=bitwarden&logoColor=white)](https://github.com/dani-garcia/vaultwarden)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Lean, Bitwarden-compatible password manager server (Vaultwarden) as a Home Assistant app – with all upstream features: organizations, sends, emergency access, 2FA (TOTP, WebAuthn, Duo, YubiKey), SSO (OpenID Connect), push, SMTP.

**Status:** wip

Important: the web vault needs its own HTTPS origin (ingress is technically not possible). For the setup with a reverse proxy see [DOCS.md](DOCS.md).

## Installation

1. Open **Settings → Apps → App Store** in Home Assistant.
2. In the menu at the top right choose **Repositories** and add `https://github.com/pol4rfuchs/ha-apps`.
3. Select **Vaultwarden** in the list and click **Install**.
4. Set the options (at least `domain`; for the first account set `signups_allowed` to `true` briefly, see [DOCS.md](DOCS.md)) and start the app.

See [DOCS.md](DOCS.md) for configuration details.

## Links

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Repository ha-apps](https://github.com/pol4rfuchs/ha-apps)
- [Vaultwarden (Upstream)](https://github.com/dani-garcia/vaultwarden)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
