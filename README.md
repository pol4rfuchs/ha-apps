# Pol4rFuchs Home Assistant Apps

[![HA App Repository](https://img.shields.io/badge/HA%20App-Repository-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![HA App Wikis](https://img.shields.io/badge/WIKI-HA%20App%20Wikis-2ea44f?style=for-the-badge&logo=githubpages&logoColor=white)](https://pol4rfuchs.github.io/ha-appwikis/ha-appwikis/)
![aarch64](https://img.shields.io/badge/aarch64-supported-41BDF5?style=for-the-badge&logo=arm&logoColor=white)
![amd64](https://img.shields.io/badge/amd64-supported-41BDF5?style=for-the-badge&logo=amd&logoColor=white)
![Unsupported architectures](https://img.shields.io/badge/no%20support-armhf%20%7C%20armv7%20%7C%20i386-lightgrey?style=for-the-badge&logo=homeassistant&logoColor=white)


Custom Home Assistant apps (add-ons), prebuilt as multi-arch container images (`aarch64` + `amd64`).

## Apps

> Production-oriented Home Assistant add-on catalog.

| App | Status | Runtime / Upstream | Category | Description |
|---|---|---|---|---|
| [TS6 Manager](ts6_manager/) | ![stable](https://img.shields.io/badge/stable-yes-2ea44f?style=flat-square) | `custom build` | Management | Web management interface for TeamSpeak 6 servers |
| [TeamSpeak 6 Server](teamspeak6/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `teamspeaksystems/teamspeak6-server` | Voice | TeamSpeak 6 self-hosted voice server |
| [ntfy](ntfy/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `binwiederhier/ntfy` | Notifications | Lightweight pub/sub push notification server |
| [ntfy HAOS Admin Panel](ntfy_manager/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `custom build` | Management | Full-featured HAOS admin console for ntfy |
| [Navidrome](navidrome/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `deluan/navidrome` | Media | Self-hosted music server with Subsonic API support |
| [Matrix Synapse](matrix_synapse/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `ghcr.io/element-hq/synapse` | Messaging | Matrix homeserver for secure messaging |
| [SearXNG](searxng/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `searxng/searxng` | Search | Privacy-respecting metasearch engine |
| [Nginx Proxy Manager](nginx_proxy_manager/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `jc21/nginx-proxy-manager` | Proxy | Reverse proxy management UI with SSL support |
| [Intiface Central](intiface_central/) | ![ready](https://img.shields.io/badge/ready-yes-41BDF5?style=flat-square) | `custom build` | GUI | Intiface Central GUI application for device control |

## Installation

1. Open Home Assistant
2. Navigate to **Settings → Apps → App Store → ⋮ → Repositories**
3. Add this URL:
   ```
   https://github.com/pol4rfuchs/ha-apps
   ```
4. Reload the store — all available add-ons appear automatically

## Architecture

All add-ons are built for:

- `aarch64` (Raspberry Pi 4, etc.)
- `amd64` (x86-64 systems)

No `armhf`, `armv7`, or `i386` builds.

## Prebuilt Images

Add-ons are distributed as prebuilt multi-arch container images via the GitHub Container Registry (GHCR).
Home Assistant pulls the finished image — no local build required on your device.

```
GitHub (source + CI)   → builds via GitHub Actions runners
GHCR (ghcr.io)         ← images live here
```

## License

Each add-on may have its own license terms — see the respective add-on folder.
