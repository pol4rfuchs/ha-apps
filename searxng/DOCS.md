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
| `enable_tor` | `false` | Starts a Tor client in the app and enables the onion engines `ahmia` and `torch`. See "Onion search (Tor)". |

---

## Settings File

After the first start, the settings file is created at:

```
addon_configs/<SLUG>_searxng/settings.yml
```

Edit with the HA File Editor add-on. Restart the add-on after changes.

Full reference: <https://docs.searxng.org/admin/settings/index.html>

---

## Onion search (Tor)

The engines `ahmia` and `torch` search `.onion` sites. SearXNG keeps them inactive unless they use Tor, which is why a
normal start logs `ahmia: can't register engine` and `torch: can't register engine`. Those two lines are harmless.

To use them, turn on `enable_tor` and restart:

- The app starts a Tor client (SOCKS on `127.0.0.1:9050`, inside the container only) and waits up to 2 minutes for it
  to connect. If Tor does not connect, SearXNG starts without it and logs a warning.
- Only `ahmia` and `torch` send their requests through Tor. All other engines keep their direct connection.
- Your own `settings.yml` is not changed. The app writes a runtime copy (`.settings.runtime.yml`, mode 600) next to it
  and points SearXNG at it. This needs `use_default_settings: true` in your `settings.yml` (the default file has it).
  Engine settings you made for `ahmia` or `torch` are kept; the Tor proxy is added on top.
- Tor is slow. The `ahmia` timeout is already high; `torch` uses the global timeout and may often time out. You can set
  a larger `timeout` for it in `settings.yml`.
- The `apparmor.txt` draft is not extended for Tor. The profile is not enforced (`apparmor: false`).

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
| Log shows `ahmia` / `torch` `can't register engine` | Expected without Tor. Turn on `enable_tor` or ignore it |
| Search returns no results | Check engine list in `settings.yml` — some engines may be rate-limited |

## Local and external access

**Local (LAN):** open it from the sidebar (Ingress) or on `http://<ha-host>:8080`. Neither has a login: a search engine used as the browser's default search cannot sit behind a login (exception class "no login by design"). Ingress and the host port share port 8080, so the app cannot restrict the port to the Ingress gateway. If you only want the sidebar, clear the host port under the add-on's **Network** tab.

**External (internet):** recommendation **not recommended, VPN only.** A public SearXNG without authentication turns into an open search proxy that others can abuse in your name. If you publish it anyway, add authentication at the reverse proxy and set `set_base_url_for_ingress` to `false`. Your search queries leave the network to the search engines by design (exception).
