<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/forgejo/logo.png" alt="Forgejo Logo" width="500">

# 🦊 Forgejo — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Forgejo Version](https://img.shields.io/badge/Forgejo-15.0.4-609926?style=for-the-badge&logo=forgejo&logoColor=white)](https://codeberg.org/forgejo/forgejo)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Forgejo v16** – Die freie, selbst-gehostete Git-Plattform direkt in Home Assistant.

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Upstream image** | `codeberg.org/forgejo/forgejo` (rootless) |
| **Forgejo version** | `15.0.4` |
| **Add-on version** | `16.0.5` |
| **SSH Git access** | optional (`ssh_enabled`) |
| **Arch** | `amd64`, `aarch64` |

---

## Installation

1. **Repository hinzufügen** in HA:
   ```
   https://github.com/pol4rfuchs/ha-apps
   ```
2. **Add-on installieren** (suche nach „Forgejo")
3. **Starten** – beim ersten Aufruf erscheint der Einrichtungs-Wizard

## Konfiguration

| Option | Standard | Beschreibung |
|--------|----------|--------------|
| `app_name` | `Forgejo` | Name der Instanz |
| `domain` | *(leer)* | Hostname für externe Erreichbarkeit |
| `ssl` | `false` | HTTPS aktivieren |
| `certfile` | `fullchain.pem` | SSL-Zertifikat aus `/ssl/` |
| `keyfile` | `privkey.pem` | SSL-Schlüssel aus `/ssl/` |
| `ssh_enabled` | `false` | SSH Git-Zugriff |
| `ssh_port` | `22` | SSH-Port |
| `log_level` | `Info` | Log-Detailgrad |

## Datenpersistenz

Alle Daten liegen in `addon_config` – überlebt Updates und Neustarts:

```
/addon_configs/local_forgejo/   (Host)
/config/                        (im Container)
├── conf/app.ini                ← Forgejo-Konfiguration (editierbar)
├── data/                       ← SQLite-DB, Pakete, Sessions
├── repositories/               ← Git-Repositories
├── ssh/                        ← SSH-Host-Keys
└── log/                        ← Logs
```

`app.ini` kann direkt über den HA Datei-Editor bearbeitet werden
(Einstellungen → Add-ons → Forgejo → Konfiguration oder Datei-Editor Add-on).
Erweiterte Forgejo-Einstellungen die nicht im HA-UI sind → direkt in app.ini.

## Lokales Testen (vor erstem GHCR-Push)

Das Add-on nutzt ein prebuilt Image von GHCR (`ghcr.io/pol4rfuchs/forgejo-ha-app`).
Für lokales Testen bevor das Image gebaut ist:

1. `image:`-Zeile in `config.yaml` auskommentieren
2. `build.yaml` ist dann aktiv → HA Supervisor baut lokal
3. Addon-Ordner nach `/addons/forgejo/` auf dem HA-Host kopieren

```bash
# Via SSH (SSH-Addon in HA aktivieren):
scp -P 22222 -r ./forgejo root@homeassistant.local:/addons/forgejo/
```

Dann: **Einstellungen → Add-ons → Add-on Store → ⋮ → Check for updates**

## Erweiterte Konfiguration (direkt in app.ini)

Alle Forgejo-Einstellungen die nicht im HA-UI sind, können direkt in
`/config/conf/app.ini` gesetzt werden:

```ini
[service]
DISABLE_REGISTRATION = true

[packages]
ENABLED = true

[actions]
ENABLED = true
```

Alternativ via Umgebungsvariablen (werden beim Start automatisch angewendet):
```
FORGEJO__service__DISABLE_REGISTRATION=true
FORGEJO__packages__ENABLED=true
```
## 📜 License

```text
MIT
```

This add-on wrapper is licensed under the MIT License.

Forgejo is licensed under [MIT](https://codeberg.org/forgejo/forgejo/src/branch/forgejo/LICENSE).