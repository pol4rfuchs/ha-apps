# Pol4rFuchs Home Assistant Add-ons

[![HA Add-on Repository](https://img.shields.io/badge/HA-Add--on%20Repository-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://codeberg.org/Pol4rFuchs/ha-apps)

Custom Home Assistant add-ons, prebuilt as multi-arch container images (`aarch64` + `amd64`).

## Add-ons

| Add-on | Status | Upstream Image | Description |
|--------|--------|----------------|-------------|
| [TS6 Manager](ts6_manager/) | stable | custom build | Web management interface for TeamSpeak 6 servers |
| [TeamSpeak 6 Server](teamspeak6/) | ready | `teamspeaksystems/teamspeak6-server` | TeamSpeak 6 voice server |
| [ntfy](ntfy/) | ready | `binwiederhier/ntfy` | ntfy push notification server |
| [Navidrome](navidrome/) | ready | `deluan/navidrome` | Self-hosted music server (Subsonic-compatible) |
| [Matrix Synapse](matrix_synapse/) | ready | `ghcr.io/element-hq/synapse` | Matrix homeserver for secure messaging |
| [SearXNG](searxng/) | ready | `searxng/searxng` | Privacy-respecting metasearch engine |
| [Nginx Proxy Manager](nginx_proxy_manager/) | ready | `jc21/nginx-proxy-manager` | Reverse proxy management UI |
| [Intiface Central](intiface_central/) | ready | custom build | Intiface Central GUI application |

## Installation

1. Open Home Assistant
2. Navigate to **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
3. Add this URL:
   ```
   https://codeberg.org/Pol4rFuchs/ha-apps
   ```
4. Reload the store — all available add-ons appear automatically

## Architecture

All add-ons are built for:

- `aarch64` (Raspberry Pi 4, etc.)
- `amd64` (x86-64 systems)

No `armhf`, `armv7`, or `i386` builds.

## Prebuilt Images

Add-ons are distributed as prebuilt multi-arch container images via Codeberg Container Registry.
Home Assistant pulls the finished image — no local build required on your device.

```
Codeberg (source + registry) ← images live here
GitHub Mirror (CI only)      ← builds via free GitHub Actions runners
```

## License

Each add-on may have its own license terms — see the respective add-on folder.
