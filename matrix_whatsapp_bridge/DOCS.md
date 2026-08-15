# Extended Documentation — WhatsApp Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` werden bei der Erstregistrierung
automatisch generiert und dürfen danach **nicht** verändert werden — sonst verliert
Synapse die Kopplung zur Appservice und alle bereits gebrückten Räume/User brechen.

## Appservice-Registrierung (Shared Volume)

Diese Bridge schreibt ihre `registration.yaml` nach `/share/whatsapp_bridge_registration.yaml`.
Das Matrix-Synapse-Add-on liest diese Datei nur ein, wenn dort die Option
`whatsapp_bridge_enabled` aktiviert ist (Synapse-Neustart danach nötig).

Ändert sich an dieser Bridge etwas, das die Appservice-Registrierung betrifft
(`appservice_id`, Bot-Username, Namespaces), muss `/data/registration.yaml` gelöscht
werden, damit sie beim nächsten Start neu generiert wird — Synapse muss danach ebenfalls
neu gestartet werden.

## Backup

- `/data` enthält `config.yaml`, `registration.yaml` und bei SQLite die komplette
  Bridge-Datenbank (Session-State, Nachrichten-Mapping) — **muss** gesichert werden,
  sonst muss WhatsApp nach einem Restore neu verknüpft werden.
- `/share/whatsapp_bridge_registration.yaml` ist aus `/data/registration.yaml` reproduzierbar
  (wird beim nächsten Start automatisch nachkopiert, falls fehlend) — nicht zwingend
  Teil des Backups.

## Datenbank-Wechsel (SQLite → Postgres)

Kein automatischer Migrationspfad. Wechsel des `db_type` nach dem ersten Start führt
zu einer leeren Datenbank (alle Verknüpfungen/History gehen verloren) — vorher `login`-Status
sauber trennen (`logout` im Bridge-Chat) und danach neu verknüpfen.

## Bekannte Einschränkungen

- Ein Signal wird pro WhatsApp-Account benötigt (kein Multi-Account innerhalb einer
  Bridge-Instanz vorgesehen).
- Encryption (Megolm) muss auf beiden Seiten (Bridge-Option `encryption` + Matrix-Client)
  aktiviert sein, um verschlüsselte Portal-Räume zu bekommen.
