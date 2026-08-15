# WhatsApp Bridge (mautrix)

Application-Service Bridge, die WhatsApp über [mautrix-whatsapp](https://github.com/mautrix/whatsapp)
an einen selbstgehosteten Matrix-Synapse-Homeserver anbindet. Läuft als eigenständiges,
isoliertes Add-on (kein gemeinsamer Container mit anderen Bridges — siehe Isolations-Philosophie).

## Installation

1. Add-on installieren und starten.
2. Optionen setzen: `homeserver_address` / `homeserver_domain` (Adresse des Matrix-Synapse-
   Add-ons), `db_type` (SQLite oder Postgres).
3. Beim ersten Start generiert die Bridge automatisch:
   - `config.yaml` (aus den gesetzten Optionen)
   - `registration.yaml`, kopiert nach `/share/whatsapp_bridge_registration.yaml`
4. Im **Matrix-Synapse-Add-on** die Option `whatsapp_bridge_enabled` aktivieren und Synapse
   neu starten (Appservice-Registrierung wird erst dann von Synapse eingelesen).
5. In einem beliebigen Matrix-Client eine DM an `@whatsappbot:<deine-domain>` schicken,
   `login` senden und QR-Code mit WhatsApp (Verknüpfte Geräte) scannen.

## Links

- Upstream: https://github.com/mautrix/whatsapp
- Doku: https://docs.mau.fi/bridges/go/whatsapp/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
