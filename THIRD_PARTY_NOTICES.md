# Third-Party Notices

This repository contains Home Assistant add-on wrappers and integration
metadata for third-party applications.

The code, Dockerfiles, scripts, workflows and documentation maintained
directly in this repository are licensed under the Apache License 2.0,
unless stated otherwise.

Third-party applications, container images, logos, trademarks and assets
remain under their respective upstream licenses.

## Included / Referenced Upstream Projects

| Add-on | Upstream Project | Upstream Source | License |
|---|---|---|---|
| TeamSpeak 6 Server | TeamSpeak 6 Server | https://www.teamspeak.com/ | See upstream/vendor terms |
| TS6 Manager | TS6 Manager | https://github.com/clusterzx/ts6-manager | See upstream license |
| ntfy | ntfy | https://github.com/binwiederhier/ntfy | See upstream license |
| ntfy Manager | ntfy / custom manager wrapper | https://github.com/binwiederhier/ntfy | See upstream license |
| Matrix Synapse | Synapse | https://github.com/element-hq/synapse | See upstream license |
| SearXNG | SearXNG | https://github.com/searxng/searxng | See upstream license |
| Navidrome | Navidrome | https://github.com/navidrome/navidrome | See upstream license |
| Nginx Proxy Manager | Nginx Proxy Manager | https://github.com/NginxProxyManager/nginx-proxy-manager | See upstream license |
| Intiface Central | Intiface / Buttplug ecosystem | https://github.com/intiface | See upstream license |
| Forgejo | Forgejo | https://forgejo.org | GPL-3.0-or-later (versions before 9.0: MIT) |
| Nextcloud | Nextcloud Server | https://github.com/nextcloud/server | AGPL-3.0 |
| Unbound | Unbound (NLnet Labs) | https://github.com/NLnetLabs/unbound | BSD-3-Clause |
| Restic Backup | restic | https://github.com/restic/restic | BSD-2-Clause |
| Matrix Authentication Service | Matrix Authentication Service | https://github.com/element-hq/matrix-authentication-service | AGPL-3.0 |
| Matrix Ketesa (Admin UI) | Ketesa (formerly Synapse Admin) | https://github.com/etkecc/ketesa | See upstream license |
| Matrix WhatsApp Bridge | mautrix-whatsapp | https://github.com/mautrix/whatsapp | AGPL-3.0 |
| Matrix Signal Bridge | mautrix-signal | https://github.com/mautrix/signal | AGPL-3.0 |
| Matrix Telegram Bridge | mautrix-telegram | https://github.com/mautrix/telegram | AGPL-3.0 |
| UniFi Toolkit | UniFi Toolkit (Crosstalk Solutions), bundled Alpine.js and Chart.js | https://github.com/Crosstalk-Solutions/unifi-toolkit, https://github.com/alpinejs/alpine, https://github.com/chartjs/Chart.js | MIT |
| UniFi OS Control Center | Original application of this repository | https://github.com/pol4rfuchs/ha-apps | Apache-2.0 (its third-party libraries keep their own licenses) |
| Vaultwarden | Vaultwarden | https://github.com/dani-garcia/vaultwarden | AGPL-3.0 |
| CortenDesk | CortenDesk (console) and CortenDesk Server (rustdesk-server fork) | https://github.com/marcpope/cortendesk, https://github.com/marcpope/cortendesk-server | AGPL-3.0 |

## Trademarks and Logos

Names, logos and trademarks such as Home Assistant, TeamSpeak, ntfy,
Matrix, SearXNG, Navidrome, Nginx Proxy Manager, Intiface, Forgejo,
Nextcloud, Unbound, restic, WhatsApp, Signal, Telegram, UniFi (Ubiquiti),
Vaultwarden, Bitwarden, CortenDesk, RustDesk and other third-party marks belong to their respective owners.

Use of those names or logos in this repository is for identification,
compatibility and documentation purposes only.

## Scope of This Repository License

The Apache License 2.0 applies to repository-owned material such as:

- Home Assistant add-on metadata
- Dockerfiles
- shell scripts
- helper scripts
- GitHub Actions workflows
- documentation
- README files
- wrapper code
- ingress glue code
- repository structure

It does not override or replace upstream licenses.

**Exception:** the wrapper files in `cortendesk/` are licensed under the GNU AGPL-3.0 (see `cortendesk/LICENSE`),
like the upstream CortenDesk projects and as agreed with the upstream author. The Apache License 2.0 applies to
the rest of the repository.
