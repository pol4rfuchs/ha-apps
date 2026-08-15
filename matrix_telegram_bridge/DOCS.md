# Extended Documentation — Telegram Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` werden bei der Erstregistrierung
automatisch generiert und dürfen danach **nicht** verändert werden — sonst verliert
Synapse die Kopplung zur Appservice und alle bereits gebrückten Räume/User brechen.

`telegram_api_id`/`telegram_api_hash` sind eigene, von Telegram vergebene Werte
(https://my.telegram.org) — nicht zu verwechseln mit as_token/hs_token. Ohne sie startet
die Bridge zwar (Log-Warnung), kann aber keine Telegram-Verbindung aufbauen.

## Appservice-Registrierung (Shared Volume)

Diese Bridge schreibt ihre `registration.yaml` nach `/share/telegram_bridge_registration.yaml`.
Das Matrix-Synapse-Add-on liest diese Datei nur ein, wenn dort die Option
`telegram_bridge_enabled` aktiviert ist (Synapse-Neustart danach nötig).

## Backup

- `/data` enthält `config.yaml`, `registration.yaml` und bei SQLite die komplette
  Bridge-Datenbank — **muss** gesichert werden, sonst muss Telegram nach einem Restore
  neu verknüpft werden (Telefonnummer + Code erneut nötig).
- `telegram_api_id`/`telegram_api_hash` sind reine Config-Werte, kein separates Secret-File.

## Login-Ablauf

Anders als WhatsApp/Signal läuft der Login **nicht** über QR-Code, sondern klassisch über
Telefonnummer + SMS-/App-Bestätigungscode (Telegram-eigener Login-Flow, MTProto-Protokoll).
`login`-Befehl an den Bridge-Bot schicken, Telefonnummer eingeben, Code aus der Telegram-App
oder SMS eintippen.

## Bekannte Einschränkungen / bewusste Vereinfachungen

- **LottieConverter nicht im Image enthalten** (Ressourcenschonung, §12) — animierte
  Sticker/Emoji-Packs werden dadurch evtl. nicht korrekt gebridged. Bei Bedarf im
  Dockerfile nachrüstbar.
- Encryption (Megolm) muss auf beiden Seiten (Bridge-Option `encryption` + Matrix-Client)
  aktiviert sein, um verschlüsselte Portal-Räume zu bekommen.
- Go-Rewrite (April 2026): Alter Python-Relaybot-Modus wird laut Upstream-Release-Notes
  nicht automatisch migriert — bei Bedarf `default_relays` manuell in `config.yaml`
  nachpflegen (betrifft nur, wer vorher schon eine Python-Instanz hatte, nicht bei uns).
