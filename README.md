# Pol4rFuchs Home Assistant Apps

[![HA App Repository](https://img.shields.io/badge/HA%20App-Repository-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![HA App Wikis](https://img.shields.io/badge/WIKI-HA%20App%20Wikis-2ea44f?style=for-the-badge&logo=githubpages&logoColor=white)](https://pol4rfuchs.github.io/ha-apps/)
![aarch64](https://img.shields.io/badge/aarch64-supported-41BDF5?style=for-the-badge&logo=arm&logoColor=white)
![amd64](https://img.shields.io/badge/amd64-supported-41BDF5?style=for-the-badge&logo=amd&logoColor=white)

![Unsupported architectures](https://img.shields.io/badge/no%20support-armhf%20%7C%20armv7%20%7C%20i386-lightgrey?style=for-the-badge&logo=homeassistant&logoColor=white)


Custom Home Assistant apps (add-ons), prebuilt as multi-arch container images (`aarch64` + `amd64`).

## Apps

> Production-oriented Home Assistant app catalog.

| App | Status | Runtime / Upstream | Category | Description |
|---|---|---|---|---|
| [TS6 Manager](ts6_manager/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `custom build` | Management | Web management interface for TeamSpeak 6 servers |
| [TeamSpeak 6 Server](teamspeak6/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `teamspeaksystems/teamspeak6-server` ![Docker Tag](https://img.shields.io/docker/v/teamspeaksystems/teamspeak6-server?style=flat-square&logo=docker&label=) | Voice | TeamSpeak 6 self-hosted voice server |
| [ntfy](ntfy/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `binwiederhier/ntfy` [![GitHub Release](https://img.shields.io/github/v/release/binwiederhier/ntfy?style=flat-square&logo=github&label=)](https://github.com/binwiederhier/ntfy/releases) | Notifications | Lightweight pub/sub push notification server |
| [ntfy HAOS Admin Panel](ntfy_manager/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `custom build` | Management | Full-featured HAOS admin console for ntfy |
| [Navidrome](navidrome/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `deluan/navidrome` [![GitHub Release](https://img.shields.io/github/v/release/deluan/navidrome?style=flat-square&logo=github&label=)](https://github.com/deluan/navidrome/releases) | Media | Self-hosted music server with Subsonic API support |
| [Nextcloud](nextcloud/) | ![wip](https://img.shields.io/badge/-wip-FFA500?style=flat-square) | `nextcloud:X.X.X-apache` ![Docker Tag](https://img.shields.io/docker/v/_/nextcloud?style=flat-square&logo=docker&label=) | Storage | Self-hosted cloud platform for files, calendar, and collaboration |
| [Matrix Synapse](matrix_synapse/) | ![experimental](https://img.shields.io/badge/-experimental-9B59B6?style=flat-square) | `ghcr.io/element-hq/synapse` [![GitHub Release](https://img.shields.io/github/v/release/element-hq/synapse?style=flat-square&logo=github&label=)](https://github.com/element-hq/synapse/releases) | Messaging | Matrix homeserver for secure messaging |
| [SearXNG](searxng/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `searxng/searxng` [![Last Commit](https://img.shields.io/github/last-commit/searxng/searxng?style=flat-square&logo=github&label=)](https://github.com/searxng/searxng/commits/master/) | Search | Privacy-respecting metasearch engine |
| [Nginx Proxy Manager](nginx_proxy_manager/) | ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | `jc21/nginx-proxy-manager` [![GitHub Release](https://img.shields.io/github/v/release/NginxProxyManager/nginx-proxy-manager?style=flat-square&logo=github&label=)](https://github.com/NginxProxyManager/nginx-proxy-manager/releases) | Proxy | Reverse proxy management UI with SSL support |
| [Intiface Central](intiface_central/) | ![wip](https://img.shields.io/badge/-wip-FFA500?style=flat-square) | `custom build` | GUI | Intiface Central GUI application for device control |
| [Forgejo](forgejo/) | ![wip](https://img.shields.io/badge/-wip-FFA500?style=flat-square) | `forgejo/forgejo` [![Codeberg Release](https://img.shields.io/gitea/v/release/forgejo/forgejo?gitea_url=https%3A%2F%2Fcodeberg.org&style=flat-square&label=)](https://codeberg.org/forgejo/forgejo/releases) <!-- forge-check:allow: legitimate Forgejo upstream is hosted on Codeberg --> | Git | Self-hosted Git platform — free GitHub alternative with repos, issues, CI/CD and package registry |
| [Unbound](unbound/) | ![experimental](https://img.shields.io/badge/-experimental-9B59B6?style=flat-square) | `custom build` | DNS | Validating, recursive DNS resolver with DNSSEC support |
| [Restic Backup](restic_backup/) | ![wip](https://img.shields.io/badge/-wip-FFA500?style=flat-square) | `custom build` | Backup | Scheduled restic backups of HA config/media/add-on data with ntfy alerting on failure |

## Pipeline

> Planned add-ons currently in the pipeline — not yet released.

| App | Status | Runtime / Upstream | Category | Description |
|---|---|---|---|---|
| Matrix Auth Service (MAS) | ![planned](https://img.shields.io/badge/-planned-6C757D?style=flat-square) | `ghcr.io/element-hq/matrix-authentication-service` [![GitHub Release](https://img.shields.io/github/v/release/element-hq/matrix-authentication-service?style=flat-square&logo=github&label=)](https://github.com/element-hq/matrix-authentication-service/releases) | Messaging | Next-gen OIDC/OAuth2 auth delegation for Matrix Synapse — required for Element X QR-code login |
| LPI | ![planned](https://img.shields.io/badge/-planned-6C757D?style=flat-square) | `custom build` | Privacy | Live Privacy Inspector — scans and reports privacy-sensitive exposure across the stack |
| UCCM | ![planned](https://img.shields.io/badge/-planned-6C757D?style=flat-square) | `custom build` | Network | UniFi Control Center/Manager — HAOS-integrated management UI for UniFi controllers |

### Status

| Badge | Meaning |
|---|---|
| ![stable](https://img.shields.io/badge/-stable-2ea44f?style=flat-square) | Production-ready and actively used |
| ![ready](https://img.shields.io/badge/-ready-41BDF5?style=flat-square) | Functional, but not yet production-validated |
| ![experimental](https://img.shields.io/badge/-experimental-9B59B6?style=flat-square) | Experimental implementation — expect breaking changes and incomplete functionality |
| ![wip](https://img.shields.io/badge/-wip-FFA500?style=flat-square) | Work in progress — not yet validated on HAOS |
| ![planned](https://img.shields.io/badge/-planned-6C757D?style=flat-square) | Planned — in pipeline, not yet started or in early scaffolding |
| ![deprecated](https://img.shields.io/badge/-deprecated-D73A49?style=flat-square) | Deprecated — no longer recommended and may be removed in a future release |

## Installation

[![Add Repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpol4rfuchs%2Fha-apps)


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
