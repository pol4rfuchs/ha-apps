# Changelog

## [1.0.2](https://github.com/pol4rfuchs/ha-apps/compare/matrix_auth_service-v1.0.1...matrix_auth_service-v1.0.2) (2026-09-06)


### Bug Fixes

* **matrix_auth_service:** update dependency element-hq/matrix-authentication-service to v1.24.0 ([#354](https://github.com/pol4rfuchs/ha-apps/issues/354)) ([3e13247](https://github.com/pol4rfuchs/ha-apps/commit/3e13247f192e8b5212ce46a8bd4809b768457e64))

## [1.0.1](https://github.com/pol4rfuchs/ha-apps/compare/matrix_auth_service-v1.0.0...matrix_auth_service-v1.0.1) (2026-08-22)


### Bug Fixes

* **matrix_auth_service:** trigger release for v1.23.0 ([48fc450](https://github.com/pol4rfuchs/ha-apps/commit/48fc4508eb0fcd4f60104afac81363aec74e4ffd))

## 1.0.0 (2026-08-15)


### Features

* **matrix_auth_service:** initial add-on skeleton ([76b9e64](https://github.com/pol4rfuchs/ha-apps/commit/76b9e64e3ba5c0a829a01099f0a273cc5df26484))

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
