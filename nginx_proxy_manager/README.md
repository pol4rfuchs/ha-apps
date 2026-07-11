<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/nginx_proxy_manager/logo.png" alt="Nginx Proxy Manager Logo" width="500">

# 🔀 Nginx Proxy Manager — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![NPM Version](https://img.shields.io/badge/NPM-2.15.1-E74C3C?style=for-the-badge&logo=nginx&logoColor=white)](https://github.com/NginxProxyManager/nginx-proxy-manager)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Reverse proxy management with a clean UI, SSL automation and native Home Assistant integration.**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Upstream image** | `jc21/nginx-proxy-manager` |
| **NPM version** | 2.15.1 |
| **Admin UI port** | `81` |
| **HTTP port** | `80` |
| **HTTPS port** | `443` |
| **Arch** | `amd64`, `aarch64` |
| **Database** | SQLite (default) or MariaDB add-on |

---

## ✨ Features

- Official `jc21/nginx-proxy-manager` image — upstream updates apply directly
- Secrets support — DB password and JWT secret from `secrets.yaml`
- SQLite (default) or MariaDB add-on integration
- Web UI on port `81`
- Dark mode (native NPM UI)
- AppArmor profile for secure container operation
- HA backup compatible — data and certificates included in snapshots
- Let's Encrypt with DNS-01 / Cloudflare / wildcard support
- Multi-arch: `amd64` + `aarch64`

---

## 🚀 Installation

### Step 1 — Add the repository

```text
Settings → Add-ons → Add-on Store → ⋮ → Repositories
```

Add:

```text
https://github.com/pol4rfuchs/ha-apps
```

### Step 2 — Install & configure

Install **Nginx Proxy Manager** and open the Configuration tab.

Minimal config (SQLite, no secrets):

```yaml
# No required options for SQLite — just start
```

With MariaDB and secrets:

```yaml
use_mariadb: true
mariadb_host: "core-mariadb"
mariadb_port: 3306
mariadb_database: "npm"
mariadb_username: !secret npm_db_user
mariadb_password: !secret npm_db_password
npm_jwt_secret: !secret npm_jwt_secret
```

### Step 3 — Start

Open the Web UI at `http://[HA-IP]:81`.

Default login credentials (change immediately):

```
Email:    admin@example.com
Password: changeme
```

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `use_mariadb` | `false` | Use MariaDB add-on instead of SQLite. |
| `mariadb_host` | `core-mariadb` | MariaDB hostname (HA add-on name). |
| `mariadb_port` | `3306` | MariaDB port. |
| `mariadb_database` | `npm` | Database name. |
| `mariadb_username` | — | MariaDB username. |
| `mariadb_password` | — | MariaDB password. Use `!secret`. |
| `npm_jwt_secret` | — | JWT secret for session tokens. Use `!secret`. |

---

## 🌐 Ports

| Port | Protocol | Purpose |
|---|---|---|
| `80` | TCP | HTTP proxy / Let's Encrypt ACME challenge |
| `443` | TCP | HTTPS proxy |
| `81` | TCP | NPM Admin UI |

> ⚠️ Ports `80` and `443` must be available on the host. Disable any other service using these ports before starting.

---

## 🔐 Let's Encrypt / DNS-01

NPM supports DNS-01 challenges for wildcard certificates. In the NPM UI:

```text
SSL Certificates → Add SSL Certificate → Let's Encrypt
→ Use DNS Challenge → select provider (e.g. Cloudflare)
→ enter API credentials
```

For DuckDNS: use the DuckDNS provider and enter your token.

---

## 💾 Data persistence

```text
/data/
├── database.sqlite    ← SQLite database (if not using MariaDB)
├── nginx/             ← Generated nginx configs
└── letsencrypt/       ← Certificates and ACME data
```

HA backups include the add-on `/data` directory automatically.

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| Port `81` not accessible | Check Network tab — port must be mapped |
| Port `80` / `443` conflict | Stop another service using these ports |
| Let's Encrypt fails | Ensure ports `80`/`443` are port-forwarded on your router |
| MariaDB connection refused | Verify MariaDB add-on is running and credentials are correct |
| White screen on UI open | Clear browser cache; try direct URL `http://[HA-IP]:81` |

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream Nginx Proxy Manager project is not relicensed by this
repository and remains under its upstream license.

Upstream:

- Nginx Proxy Manager: https://github.com/NginxProxyManager/nginx-proxy-manager
- Upstream license: MIT, see upstream repository

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)