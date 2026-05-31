<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/searxng/icon.png" alt="SearXNG Icon" width="128">

# 🔍 SearXNG — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![SearXNG](https://img.shields.io/badge/SearXNG-upstream-3498DB?style=for-the-badge&logo=searxng&logoColor=white)](https://github.com/searxng/searxng)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Privacy-respecting metasearch engine — no tracking, no profiles, self-hosted.**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Upstream image** | `searxng/searxng` |
| **Default port** | `8080` (Ingress) |
| **Arch** | `amd64`, `aarch64` |
| **Access** | HA Ingress (sidebar) |

SearXNG aggregates results from 70+ search engines without tracking users or building profiles. It exposes a JSON API for use in automations.

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

### Step 2 — Install

Install **SearXNG**. No mandatory configuration — it starts with sensible defaults.

### Step 3 — Start

Open via the **Open Web UI** button or the HA sidebar. The Ingress URL is set automatically.

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `set_base_url_for_ingress` | `true` | Auto-sets `SEARXNG_BASE_URL` to the HA Ingress URL. Disable only if you access SearXNG through an external reverse proxy. |

---

## 📝 SearXNG settings file

After the first start, the settings file is written to:

```text
addon_configs/<SLUG>_searxng/settings.yml
```

Edit it via the HA File Editor add-on. Changes apply after restarting the add-on.

Full reference: <https://docs.searxng.org/admin/settings/index.html>

---

## 🪝 custom.sh hook

Place a `custom.sh` in the config directory to run shell commands before SearXNG starts — useful for patching settings or activating plugins:

```text
addon_configs/<SLUG>_searxng/custom.sh
```

Example:

```bash
#!/bin/sh
# Patch a setting after the config is written
sed -i 's/safe_search: 0/safe_search: 1/' /etc/searxng/settings.yml
```

---

## 🌐 JSON API

SearXNG exposes a JSON API for automations and integrations:

```
http://homeassistant.local:8080/search?q=your+query&format=json
```

Example in a HA automation:

```yaml
action: rest_command.searxng_search
data:
  query: "current weather Berlin"
```

```yaml
# configuration.yaml
rest_command:
  searxng_search:
    url: "http://localhost:8080/search?q={{ query }}&format=json"
    method: GET
```

---

## ⚡ Valkey / Redis (optional)

For caching and improved performance, add Redis/Valkey to `settings.yml`:

```yaml
redis:
  url: "valkey://SLUG-valkey:6379/0"
```

---

## 💾 Data persistence

```text
addon_configs/<SLUG>_searxng/
├── settings.yml    ← SearXNG configuration
└── custom.sh       ← Optional pre-start hook
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| Sidebar shows blank page | Use the direct URL: `http://[HA-IP]:8080` |
| Settings not applied | Restart the add-on after editing `settings.yml` |
| Search returns no results | Check engine list in `settings.yml` — some engines may be rate-limited |
| Ingress URL wrong | Set `set_base_url_for_ingress: true` in add-on options |

---

## 📜 License

The Home Assistant add-on wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream SearXNG project is not relicensed by this repository and
remains under its upstream license.

Upstream:

- SearXNG: https://github.com/searxng/searxng
- Upstream license: AGPL-3.0, see upstream repository

Third-party trademarks, logos, names and assets remain the property of
their respective owners.

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)