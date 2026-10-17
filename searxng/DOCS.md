# SearXNG — Home Assistant Add-on

Privacy-respecting metasearch engine. No tracking, no profiles, fully self-hosted.

---

## Quick Start

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add: `https://github.com/pol4rfuchs/ha-apps`
3. Install **SearXNG** and click **Start**
4. Open via the **Open Web UI** button or the HA sidebar

No mandatory configuration — SearXNG starts with sensible defaults.

---

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `set_base_url_for_ingress` | `true` | Auto-sets the SearXNG base URL to the HA Ingress path. Disable only when using an external reverse proxy. |

---

## Settings File

After the first start, the settings file is created at:

```
addon_configs/<SLUG>_searxng/settings.yml
```

Edit with the HA File Editor add-on. Restart the add-on after changes.

Full reference: <https://docs.searxng.org/admin/settings/index.html>

---

## JSON API

```
http://homeassistant.local:8080/search?q=your+query&format=json
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Sidebar shows blank page | Use direct URL: `http://[HA-IP]:8080` |
| Settings not applied | Restart the add-on after editing `settings.yml` |
| Search returns no results | Check engine list in `settings.yml` — some engines may be rate-limited |

## Local and external access

**Local (LAN):** open it from the sidebar (Ingress) or on `http://<ha-host>:8080`. Neither has a login: a search engine used as the browser's default search cannot sit behind a login (exception class "no login by design"). Ingress and the host port share port 8080, so the app cannot restrict the port to the Ingress gateway. If you only want the sidebar, clear the host port under the add-on's **Network** tab.

**External (internet):** recommendation **not recommended, VPN only.** A public SearXNG without authentication turns into an open search proxy that others can abuse in your name. If you publish it anyway, add authentication at the reverse proxy and set `set_base_url_for_ingress` to `false`. Your search queries leave the network to the search engines by design (exception).
