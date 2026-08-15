# Extended Documentation — Signal Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` werden bei der Erstregistrierung
automatisch generiert und dürfen danach **nicht** verändert werden — sonst verliert
Synapse die Kopplung zur Appservice und alle bereits gebrückten Räume/User brechen.

## Appservice-Registrierung (Shared Volume)

Diese Bridge schreibt ihre `registration.yaml` nach `/share/signal_bridge_registration.yaml`.
Das Matrix-Synapse-Add-on liest diese Datei nur ein, wenn dort die Option
`signal_bridge_enabled` aktiviert ist (Synapse-Neustart danach nötig).

## Backup

- `/data` enthält `config.yaml`, `registration.yaml` und bei SQLite die komplette
  Bridge-Datenbank (Session-State, Nachrichten-Mapping) — **muss** gesichert werden,
  sonst muss Signal nach einem Restore neu verknüpft werden.
- `/share/signal_bridge_registration.yaml` ist aus `/data/registration.yaml` reproduzierbar
  (wird beim nächsten Start automatisch nachkopiert, falls fehlend) — nicht zwingend
  Teil des Backups.

## Build-Besonderheit (Rust + Go)

Signal ist die einzige der drei Bridges, die zusätzlich zu Go auch einen Rust-Build-Schritt
braucht (`libsignal_ffi.a`, offizielles Signal-Protokoll in Rust). Der Build folgt exakt dem
offiziellen `mautrix/signal`-Dockerfile: Stage 1 baut `libsignal_ffi.a` via `build-rust.sh`,
Stage 2 linkt Go dagegen via `build-go.sh` (`LIBRARY_PATH`). Dadurch ist die Build-Zeit spürbar
länger als bei WhatsApp/Telegram — reiner CI-Zeit-Effekt, keine Auswirkung auf Laufzeit-RAM.

## Verknüpfung

Anders als bei WhatsApp läuft die Verknüpfung über "Verknüpfte Geräte" in den Signal-
Einstellungen, nicht über einen In-App-QR-Scanner. Bei Erst-Login fragt Signal, ob die
Nachrichten-Historie übertragen werden soll — optional, aber empfohlen für vollständigen
Kontext in Matrix.

## Bekannte Einschränkungen

- Registrierung als Signal-Primärgerät wird von der Bridge nicht unterstützt — nur
  Verknüpfung als Zweitgerät (offizielle App oder `signal-cli`).
- Encryption (Megolm) muss auf beiden Seiten (Bridge-Option `encryption` + Matrix-Client)
  aktiviert sein, um verschlüsselte Portal-Räume zu bekommen.
