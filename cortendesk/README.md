# CortenDesk

RustDesk console with built-in ID server (hbbs) and relay (hbbr) in one container.
Thin Home Assistant wrapper around the upstream image `ghcr.io/marcpope/cortendesk`.

**Status:** experimental. Unofficial community app: it is neither supported nor recommended by the upstream author.
Please report bugs in the package (wrapper, options, Home Assistant integration) in the repository
[pol4rfuchs/ha-apps](https://github.com/pol4rfuchs/ha-apps/issues), and bugs in CortenDesk itself at
[marcpope/cortendesk](https://github.com/marcpope/cortendesk/issues).

See [DOCS.md](DOCS.md) for configuration, ports and known limitations.

## Installation

1. Add the repository in Home Assistant under Settings → Apps → App Store.
2. Install **CortenDesk**.
3. Set `app_url` and `admin_password` in the configuration, start the app.
4. Open the console at `http://<ha-host>:21114`.

## Links

- Upstream (console): <https://github.com/marcpope/cortendesk>
- Upstream (server fork): <https://github.com/marcpope/cortendesk-server>

## License

Wrapper files of this app: AGPL-3.0, like the upstream projects. From 1.11.0 CortenDesk is
fully AGPL-3.0, or under the permissive licenses of the bundled libraries (Bootstrap,
Remix Icon, ApexCharts, Figtree); details in the `NOTICE` of the upstream repo and the `NOTICE` of this app. The upstream source code of the version in use is under the tag `v<version>` in `marcpope/cortendesk` (version see `CORTENDESK_VERSION` in the Dockerfile). The author
(Marc Pope) has explicitly allowed redistribution as an HA app (issue #89).
