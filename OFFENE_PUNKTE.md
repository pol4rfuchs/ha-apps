# Offene Punkte – ha-apps

Stand: 2026-10-04, nach Repo-Audit, PR #454 und den Folge-PRs (Base-Images, Wiki, unifi, Platzhalter).
Prioritäten: **hoch** / mittel / niedrig.

## 1. Erledigt

- [x] `---` als erste Zeile in 13 `config.yaml` (PR #454)
- [x] `ubuntu-latest` → `ubuntu-24.04` in allen Workflows inkl. amd64-Matrix in `build-app.yaml` (PR #454)
- [x] `matrix_synapse/Dockerfile`: `chmod +x` für `element-web/run`, `livekit/finish`, `livekit-jwt/finish`, `postgres-backup/finish` (PR #454)
- [x] `nextcloud/translations/de.yaml` neu (13 Optionen) (PR #454)
- [x] yamllint-Whitespace in Workflows (Doppel-Leerzeichen `build-app.yaml`, Leerzeichen am Zeilenende)
- [x] Port-Tabelle (§14): 8082/8083 (matrix_auth_service), 8599 (unifi_os_control_center); keine Kollisionen
- [x] Hadolint-Warnung DL3025 bei `matrix_synapse` HEALTHCHECK: Absicht (Shell-Form wegen `|| exit 1`), kein Handlungsbedarf
- [x] Base-Image-Bumps auf `hassio-addons/base:21.0.7`: ntfy, ntfy_manager, forgejo, ts6_manager (ts6_manager zusätzlich `pip3 install --break-system-packages` für yt-dlp)
- [x] Wiki-Seiten für unifi_os_control_center, matrix_auth_service und die drei Bridges (inkl. Hub und `.wiki-versions.json`)
- [x] unifi_os_control_center: pip-Pins in `requirements.txt`, `HEALTHCHECK`
- [x] matrix_auth_service: Platzhalter-Defaults neutralisiert (§9)

## 2. Braucht Entscheidung oder Infos

- [ ] **hoch** – `ts6_manager`: Phantom-Option `log_level`. Das s6-Start-Skript (`rootfs/etc/s6-overlay/s6-rc.d/ts6-backend/run`) liest sie nie. Entweder Log-Variable des Upstream-Backends nennen und verdrahten, oder Option aus `config.yaml`/Schema/Translations entfernen.
- [ ] mittel – `stage:` fehlt in fast allen `config.yaml` (nur Bridges und unifi setzen es). Festlegen, welche Add-ons `stable` sind.
- [ ] mittel – Fehlende Assets:
  - `icon.png`: forgejo, nextcloud
  - `logo.png`: matrix_auth_service, restic_backup, intiface_central
  - `apparmor.txt`: matrix_auth_service, intiface_central
- [ ] niedrig – unifi_os_control_center: `controller_url` Default leer statt `unifi.example.internal` (Schema `url` → `url?` und Backend-Prüfung nötig)

## 3. AppArmor (später, jeweils mit Start- und Restart-Test)

Aktuell `apparmor: false` bei 14 Add-ons (nur restic_backup, matrix_signal_bridge, matrix_telegram_bridge haben `true`).

- [ ] Gruppe A, Profil mit s6-Baseline vorhanden, nur Test + Umschalten: forgejo, matrix_synapse, matrix_whatsapp_bridge, nginx_proxy_manager, ntfy, ntfy_manager, ts6_manager, unifi_os_control_center
- [ ] Gruppe B, Profil erst um s6-Baseline ergänzen: navidrome, nextcloud, searxng, teamspeak6
- [ ] `intiface_central` hat bewusst Vollzugriff (`full_access`, `host_dbus`, `host_network`); Ausnahme, kein Profil nötig

## 4. Base-Images

- [ ] **Test auf dem Pi** nach dem Merge der Base-Image-PRs: ntfy, ntfy_manager, forgejo, ts6_manager (bei ts6_manager auf Node/Prisma-Laufzeit und yt-dlp achten)
- [ ] matrix_synapse, matrix_auth_service: `debian-base:7.7.1` **nicht** bumpen. Aktuell 9.5.0 (Debian 13/trixie) hat kein `postgresql-15`, beide Dockerfiles installieren `postgresql-15` und nutzen `/usr/lib/postgresql/15/bin`. Eigenes Projekt (PostgreSQL 15 → 17, Datenmigration).
- [ ] niedrig – unifi_os_control_center: `base-python:3.13-alpine3.22` → aktuell `3.14-alpine3.24` (optional, Abhängigkeiten prüfen)
- [ ] §16 im Regelkatalog aktualisieren: `debian-base` aktuell 9.5.0 (nicht 8.1.0), `base` aktuell 21.0.7 (nicht 21.0.1)

## 5. ntfy_manager

- [ ] niedrig – s6 `finish` fehlt bei `nginx` und `ntfy-admin` (§11). Verhaltensänderung, deshalb bisher nicht angefasst.

## 6. unifi_os_control_center

- [ ] verworfen – `frontend/dist` per Multi-Stage-Build: das committete `dist` ist laut README/DOCS Absicht (lokale HAOS-Builds ohne npm)
- [ ] AppArmor siehe Abschnitt 3

## 7. Kleinkram

- [ ] niedrig – `.gitignore` im Repo-Root fehlt (nur unifi hat eine eigene)

## 8. Hinweis Release Please

PR-Titel `chore: …` löst keine Version-Bumps aus. Base-Image- und Platzhalter-PRs sind `fix(<addon>): …` und lösen je Add-on einen Release-Please-PR aus; diese nacheinander mergen (Manifest-Konflikte).
