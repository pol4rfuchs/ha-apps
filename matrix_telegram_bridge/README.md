# Telegram Bridge (mautrix)

Application-Service Bridge, die Telegram über [mautrix-telegram](https://github.com/mautrix/telegram)
an einen selbstgehosteten Matrix-Synapse-Homeserver anbindet. Läuft als eigenständiges,
isoliertes Add-on (kein gemeinsamer Container mit anderen Bridges — siehe Isolations-Philosophie).

## Installation

1. Add-on installieren und starten.
2. Auf https://my.telegram.org eine App registrieren (kostenlos), `telegram_api_id` +
   `telegram_api_hash` in die Add-on-Optionen eintragen — **ohne diese beiden Werte
   verbindet sich die Bridge nicht mit Telegram.**
3. Weitere Optionen setzen: `homeserver_address` / `homeserver_domain` (Adresse des
   Matrix-Synapse-Add-ons), `db_type` (SQLite oder Postgres).
4. Beim ersten Start generiert die Bridge automatisch:
   - `config.yaml` (aus den gesetzten Optionen)
   - `registration.yaml`, kopiert nach `/share/telegram_bridge_registration.yaml`
5. Im **Matrix-Synapse-Add-on** die Option `telegram_bridge_enabled` aktivieren und Synapse
   neu starten (Appservice-Registrierung wird erst dann von Synapse eingelesen).
6. In einem beliebigen Matrix-Client eine DM an `@telegrambot:<deine-domain>` schicken,
   `login` senden — anders als bei WhatsApp/Signal läuft der Login über Telefonnummer +
   SMS/App-Code, nicht über QR-Scan.

## Links

- Upstream: https://github.com/mautrix/telegram
- Doku: https://docs.mau.fi/bridges/go/telegram/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
