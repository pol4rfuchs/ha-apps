# Unbound — Advanced Documentation

This document covers persistent data, backup, and advanced configuration
details beyond the installation/quickstart steps in the README.

## Persistent Data

Everything lives in `/data`, which is the app's own persistent storage. It survives app
restarts, updates and container recreation; no extra `map:` entry is required. The web UI
keeps its state in several files:

| File | Content |
|---|---|
| `config.json` | Server settings (Network, Performance, Cache, Security, Advanced tabs) |
| `blocklists.json`, `whitelist.json` | Blocklist URLs and whitelisted domains |
| `local_records.json` | Local DNS records |
| `stub_zones.json` | Stub zones |
| `blocklist_cache/` | Last successful download of each blocklist (used when a refresh fails; excluded from backups because it is downloaded again) |
| `unbound-control/` | Keys for the control channel, generated on the first start |
| `unbound_queries.log` | Query log (capped at 50 MB, the previous part is kept as `.old`) |

## Backup

A Home Assistant backup includes `/data`, so a full or app backup restores all of the files above.
To copy your DNS setup by hand to another installation, take **all** of `config.json`,
`blocklists.json`, `whitelist.json`, `local_records.json` and `stub_zones.json`, not only
`config.json`.

There are no secrets to manage for this app: Unbound itself doesn't require credentials, and the
web UI has no separate authentication beyond what Ingress/HA already provides. The app has no
backup hooks of its own.

## Forwarding with DNS-over-TLS

Unbound resolves recursively by default. If you add forward servers and switch on
**DNS-over-TLS**, write each server as `IP[@port][#tls-name]`, for example
`1.1.1.1@853#cloudflare-dns.com`. Without the `#tls-name` the connection is encrypted, but
Unbound does not check the server certificate, and the web UI shows a note when you save such
a setup. This app does not offer a DNS-over-TLS **server** for clients: put that in front of it,
for example in AdGuard Home, and use `<ha-host>:5053` as its upstream.

## Hardening options (Security tab)

| Option | Default | Effect |
|---|---|---|
| Rebinding Protection | off | Removes private addresses from answers for public names. Stub zones are exempt automatically. Internal names that live in public DNS and point to a private address stop resolving, so switch it on only if you do not need that. |
| Refuse ANY Queries | off | Minimal answer to `ANY` queries (amplification abuse). |
| Harden Large Queries / Short Buffer Size | on | Refuse very large queries and ignore EDNS buffers below 512 bytes. |
| Rate Limit (per zone) | 0 (off) | Queries per second sent to the servers of one zone. |
| Rate Limit (per client IP) | 0 (off) | Queries per second accepted from one client. A forwarder such as AdGuard Home sends everything from one address, so keep this high or off in that setup. |
| Unwanted Reply Threshold | 10000000 | Flushes the cache after that many unsolicited replies (cache poisoning protection). 0 = off. |

**Listen on IPv6** (Network tab, restart required) also binds `::0`. Switch it on only if the app's
container network has IPv6; without it Unbound cannot bind the address and does not start.

## Custom `unbound.conf` and Overlay Files

See the README's "Custom Configuration" and "Overlay Files" sections for the
full mechanism (`unbound-overlay.conf` / `unbound-extra.conf` under
`/addon_configs/<slug>_unbound/`). In short:

- **Full custom config**: enable "Custom Config" in the web UI, then place a
  complete `unbound.conf` at the app config path. When enabled, all GUI
  settings are ignored.
- **Overlay files**: keep GUI-managed settings but inject a few extra
  `server:` directives or whole top-level sections (`auth-zone:`, `view:`)
  that the GUI doesn't expose.

In custom config mode your `unbound.conf` must keep a `remote-control:` section with the key and
certificate files from `/etc/unbound/` (see the generated config for the paths); otherwise the
statistics, cache flush and reload in the web UI do not work.

If the combined configuration fails `unbound-checkconf` validation, the
app automatically falls back to GUI-only settings and surfaces the
validation error in the **Advanced** tab, so a bad snippet never takes DNS
resolution down.

## Log Level

The only option exposed in the HA app panel (`log_level`) controls the
verbosity of the app's own supervisor process log — it does not affect
what's recorded in the web UI's query log, which is controlled separately
via the **Logging** section in the web UI's Server Settings.

## Local and external access

**Local (LAN):** DNS listens on `5053` (tcp/udp). Point your router, AdGuard upstream or clients at `<ha-host>:5053`. The web UI is Ingress-only (port 2137 is not mapped) and relies on the Home Assistant login; it has no login of its own, so the app rejects every request that does not come from the Ingress gateway. By default only private networks may query the resolver (access control).

**External (internet):** **never forward `5053`.** An open resolver can be abused for DNS amplification attacks. If your router can only forward port 53, use a NAT redirect inside the LAN only.
