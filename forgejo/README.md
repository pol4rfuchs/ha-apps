<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/forgejo/logo.png" alt="Forgejo Logo" width="500">

# 🦊 Forgejo — Home Assistant App

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Forgejo Version](https://img.shields.io/badge/Forgejo-17.0.1-609926?style=for-the-badge&logo=forgejo&logoColor=white)](https://codeberg.org/forgejo/forgejo)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Forgejo v16** – The free, self-hosted Git platform directly in Home Assistant.

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Upstream image** | `codeberg.org/forgejo/forgejo` (rootless) |
| **Forgejo version** | `17.0.1` |
| **Add-on version** | `16.0.21` |
| **SSH Git access** | optional (`ssh_enabled`) |
| **Arch** | `amd64`, `aarch64` |

---

## Installation

1. **Add the repository** in HA:
   ```
   https://github.com/pol4rfuchs/ha-apps
   ```
2. **Install the add-on** (search for "Forgejo")
3. **Start it** – on the first visit the setup wizard appears

## Configuration

| Option | Default | Description |
|--------|----------|--------------|
| `app_name` | `Forgejo` | Name of the instance |
| `domain` | *(empty)* | Hostname for external access |
| `ssl` | `false` | Enable HTTPS |
| `certfile` | `fullchain.pem` | SSL certificate from `/ssl/` |
| `keyfile` | `privkey.pem` | SSL key from `/ssl/` |
| `ssh_enabled` | `false` | SSH Git access |
| `ssh_port` | `22` | SSH port |
| `log_level` | `Info` | Log verbosity |

## Data persistence

All data lives in `addon_config` – it survives updates and restarts:

```
/addon_configs/local_forgejo/   (host)
/config/                        (in the container)
├── conf/app.ini                ← Forgejo configuration (editable)
├── data/                       ← SQLite DB, packages, sessions
├── repositories/               ← Git repositories
├── ssh/                        ← SSH host keys
└── log/                        ← logs
```

`app.ini` can be edited directly with the HA file editor
(Settings → Add-ons → Forgejo → Configuration, or the File editor add-on).
Advanced Forgejo settings that are not in the HA UI → directly in app.ini.

## Local testing (before the first GHCR push)

The add-on uses a prebuilt image from GHCR (`ghcr.io/pol4rfuchs/forgejo`).
`build.yaml` no longer exists in the repo (the central CI/CD pipeline even
aborts hard if one is present in the add-on folder) — local testing runs
directly through the Dockerfile instead:

```bash
docker buildx build \
  --build-arg BUILD_ARCH=aarch64 \
  --build-arg BUILD_VERSION=dev \
  -t forgejo-local ./forgejo
```

Or: open a PR with the change — `02-build-test.yml` automatically builds only
the changed add-on (path filtering) for amd64+arm64 in CI.

## Advanced configuration (directly in app.ini)

All Forgejo settings that are not in the HA UI can be set directly in
`/config/conf/app.ini`:

```ini
[service]
DISABLE_REGISTRATION = true

[packages]
ENABLED = true

[actions]
ENABLED = true
```

Alternatively via environment variables (applied automatically at startup):
```
FORGEJO__service__DISABLE_REGISTRATION=true
FORGEJO__packages__ENABLED=true
```
## 📜 License

```text
Apache-2.0 (add-on wrapper)  /  GPL-3.0-or-later (Forgejo)
```

The add-on wrapper (metadata, Dockerfile, scripts and documentation in this directory) is licensed under the Apache License 2.0, see [`../LICENSE`](../LICENSE).

Forgejo itself is licensed under the [GPL version 3.0 or any later version](https://codeberg.org/forgejo/forgejo/src/branch/forgejo/LICENSE); versions before 9.0 were MIT.