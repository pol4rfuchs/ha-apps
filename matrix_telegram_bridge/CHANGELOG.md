# Changelog

## [0.2610.0-ha2-pol4r1] - Postgres-Passwort und Config-Fehler

- Postgres: Benutzer, Passwort und DB-Name werden in der DB-URI URL-kodiert.
  Passwörter mit `@ : / ? # %` zerlegten die URI (falscher Host, Passwort abgeschnitten).
- Optionswerte gehen per Umgebung (`strenv()`) an yq statt in den Ausdruck. Ein `"` im
  Passwort machte den Ausdruck ungültig, und die Bridge lief still mit der alten Config weiter.
- Schlägt das Schreiben der config.yaml fehl, bricht der Start jetzt mit einer Fehlermeldung ab.

## [26.7.0-ha1-pol4r1] - Initial Release

- Erstveröffentlichung: mautrix-telegram v0.2607.0 (Go/bridgev2-Rewrite) als
  eigenständiges HA-Add-on
- Source-Build (Go 1.25, Alpine 3.24), aarch64 + amd64
- SQLite/Postgres wählbar, Encryption-Toggle, Appservice-Registrierung via `/share`
- Pflichtfelder telegram_api_id/telegram_api_hash (my.telegram.org)
