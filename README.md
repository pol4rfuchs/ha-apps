# Pol4rFuchs Home Assistant Apps

[![HA App Repository](https://img.shields.io/badge/HA%20App-Repository-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![HA App Wikis](https://img.shields.io/badge/WIKI-HA%20App%20Wikis-2ea44f?style=for-the-badge&logo=githubpages&logoColor=white)](https://pol4rfuchs.github.io/ha-appwikis/ha-appwikis/)
![aarch64](https://img.shields.io/badge/aarch64-supported-41BDF5?style=for-the-badge&logo=arm&logoColor=white)
![amd64](https://img.shields.io/badge/amd64-supported-41BDF5?style=for-the-badge&logo=amd&logoColor=white)

Custom Home Assistant apps (add-ons), prebuilt as multi-arch container images (`aarch64` + `amd64`).

## Apps

| Add-on | Status | Upstream Image | Description |
|--------|--------|----------------|-------------|
| [TS6 Manager](ts6_manager/) | stable | custom build | Web management interface for TeamSpeak 6 servers |
| [TeamSpeak 6 Server](teamspeak6/) | ready | `teamspeaksystems/teamspeak6-server` | TeamSpeak 6 voice server |
| [ntfy](ntfy/) | ready | `binwiederhier/ntfy` | ntfy push notification server |
| [ntfy HAOS Admin Panel](ntfy_manager/) | ready | custom build | Full-featured admin console for ntfy |
| [Navidrome](navidrome/) | ready | `deluan/navidrome` | Self-hosted music server (Subsonic-compatible) |
| [Matrix Synapse](matrix_synapse/) | ready | `ghcr.io/element-hq/synapse` | Matrix homeserver for secure messaging |
| [SearXNG](searxng/) | ready | `searxng/searxng` | Privacy-respecting metasearch engine |
| [Nginx Proxy Manager](nginx_proxy_manager/) | ready | `jc21/nginx-proxy-manager` | Reverse proxy management UI |
| [Intiface Central](intiface_central/) | ready | custom build | Intiface Central GUI application |


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
