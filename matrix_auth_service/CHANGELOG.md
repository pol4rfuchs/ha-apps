# Changelog

## 0.1.0

- Initiales Konzept-Skeleton: Dockerfile (Multi-Stage, Binary aus
  `ghcr.io/element-hq/matrix-authentication-service`), eigene
  Postgres-Instanz, cont-init-Script für Secrets/Config-Generierung
- `postgres-backup` S6-Service ergänzt (periodischer `pg_dump`, analog
  Synapse-Add-on, inkl. `finish`-Script — im Synapse-Original fehlt das)
- `backup_exclude`-Pfad korrekt relativ zum `/data`-Mount gesetzt
  (`mas/postgresql/pg_wal`) — im Synapse-Original steht dort fälschlich
  `data/postgresql/pg_wal`, was `pg_wal` nie tatsächlich ausschließt
- Noch ungetestet — kein Build, kein Container-Start durchgeführt
- `icon.png`/`logo.png`/`apparmor.txt` bewusst zurückgestellt
