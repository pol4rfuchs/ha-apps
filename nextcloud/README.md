<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/nextcloud/logo.png" alt="Nextcloud Logo" width="500">

# ☁️ Nextcloud — Home Assistant App

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Nextcloud Version](https://img.shields.io/badge/Nextcloud-35.0.2-0082C9?style=for-the-badge&logo=nextcloud&logoColor=white)](https://github.com/nextcloud/server)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**A full [Nextcloud](https://nextcloud.com/) instance for Home Assistant OS — based on the official Nextcloud Docker image, no restrictions on installing apps from [apps.nextcloud.com](https://apps.nextcloud.com/).**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Base image** | `nextcloud:apache` (official) |
| **Nextcloud version** | `35.0.2` |
| **Add-on version** | `33.0.25` |
| **Default port** | `8280` |
| **App store** | ✅ unrestricted |
| **Arch** | `amd64`, `aarch64` |

---

## Key differences from community alternatives

| | This add-on | alexbelgium | enricodeleo |
|---|---|---|---|
| Base image | `nextcloud:apache` (official) | `linuxserver/nextcloud` | `nextcloud` (official, outdated) |
| App store | ✅ unrestricted | ❌ restricted | ✅ |
| Actively maintained | ✅ | ✅ | ❌ |
| aarch64 native | ✅ | ✅ | ✅ |

## Prerequisites

- **MariaDB add-on** (recommended): configure with a `nextcloud` database and user before first start
- Port **8280** must be free on the host (or change it in the add-on config)

## Installation

1. Add the `pol4rfuchs/ha-apps` repository to Home Assistant
2. Install **Nextcloud**
3. Configure options (see below)
4. Start the add-on
5. Open the Web UI — on first boot Nextcloud installs itself (~1–2 min)

## Configuration

| Option | Default | Description |
|---|---|---|
| `admin_user` | `admin` | Initial admin username |
| `admin_password` | `""` | Initial admin password — **required**, the first start fails while it is empty |
| `trusted_domains` | `"homeassistant.local homeassistant"` | Space-separated list, e.g. `"nextcloud.example.com 192.0.2.10"` — add the LAN IP or domain you use **before the first start** |
| `db_type` | `mysql` | `mysql` / `pgsql` / `sqlite` |
| `db_host` | `core-mariadb` | MariaDB hostname (HA internal: `core-mariadb`) |
| `db_port` | `3306` | Database port |
| `db_name` | `nextcloud` | Database name |
| `db_user` | `nextcloud` | Database user |
| `db_password` | `""` | Database password |
| `php_memory_limit` | `512M` | PHP memory limit |
| `max_upload_size` | `16G` | Max upload file size |
| `max_execution_time` | `3600` | PHP max execution time (seconds) |

## Data persistence

All data is stored under `/data/nextcloud/` in the add-on's persistent volume:

```
/data/nextcloud/
├── config/       # config.php and further config files
├── custom_apps/  # apps installed from the Nextcloud app store
├── themes/
├── data/         # User files (NEXTCLOUD_DATA_DIR)
└── version.php   # Version of the installed code (used for updates)
```

The Nextcloud code itself is not stored: it comes from the add-on image and is
restored on every start.

On add-on updates only the app code changes. Nextcloud's own `occ upgrade` runs automatically when the new version is newer; user files in `data/` are never touched. Downgrades and skipping a major version are refused.

## Trusted domains

Add your domain and/or IP to `trusted_domains` **before** first access, or Nextcloud will refuse the connection. After initial setup you can also run:

```bash
# Inside the add-on shell:
php /var/www/html/occ config:system:set trusted_domains 1 --value="nextcloud.example.com"
```

## Proxying via NPM

Set `trusted_domains` to your NPM proxy domain and configure the following headers in the NPM proxy host:

```
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

Then in Nextcloud admin → Overview fix the remaining warnings via `occ`:

```bash
php /var/www/html/occ config:system:set overwriteprotocol --value="https"
php /var/www/html/occ config:system:set overwrite.cli.url --value="https://nextcloud.example.com"
```

## 📜 License

```text
Apache-2.0 (add-on wrapper)  /  AGPL-3.0 (Nextcloud Server)
```

The add-on wrapper (metadata, Dockerfile, scripts and documentation in this directory) is licensed under the Apache License 2.0, see [`../LICENSE`](../LICENSE).

Nextcloud Server is licensed under [AGPL-3.0](https://github.com/nextcloud/server/blob/master/COPYING).