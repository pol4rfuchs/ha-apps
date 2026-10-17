# Vaultwarden

Schlanker, Bitwarden-kompatibler Passwortmanager-Server (Vaultwarden) als Home-Assistant-App – mit allen Upstream-Funktionen: Organisationen, Sends, Notfallzugriff, 2FA (TOTP, WebAuthn, Duo, YubiKey), SSO (OpenID Connect), Push, SMTP.

**Status:** wip

Wichtig: Der Web Vault braucht einen eigenen HTTPS-Ursprung (Ingress ist technisch nicht möglich). Setup mit Reverse Proxy siehe [DOCS.md](DOCS.md).

## Installation

1. In Home Assistant **Settings → Apps → App Store** öffnen.
2. Oben rechts im Menü **Repositories** wählen und `https://github.com/pol4rfuchs/ha-apps` hinzufügen.
3. **Vaultwarden** in der Liste auswählen und **Install** klicken.
4. Optionen setzen (mindestens `domain`; für das erste Konto `signups_allowed` kurz auf `true`, siehe [DOCS.md](DOCS.md)) und die App starten.

Siehe [DOCS.md](DOCS.md) für Konfigurationsdetails.

## Links

- [Dokumentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Repository ha-apps](https://github.com/pol4rfuchs/ha-apps)
- [Vaultwarden (Upstream)](https://github.com/dani-garcia/vaultwarden)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
