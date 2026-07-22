# Unbound — Advanced Documentation

This document covers persistent data, backup, and advanced configuration
details beyond the installation/quickstart steps in the README.

## Persistent Data

All runtime configuration lives in `/data/config.json`, managed exclusively
through the add-on's web UI. This includes:

- Blocklists, whitelist entries, local DNS records
- Server settings (network, performance, cache, security tabs)
- Query log data

`/data` is the add-on's own persistent storage and survives add-on
restarts, updates, and container recreation automatically — no extra `map:`
entry is required for it.

## Backup

Back up `/data/config.json` if you want to restore your DNS configuration
(blocklists, local records, server settings) onto a fresh install. A
Home Assistant full backup (which includes add-on data by default) already
covers this — no addon-specific backup hooks are configured.

There are no secrets to manage for this add-on: Unbound itself doesn't
require credentials, and the web UI has no separate authentication beyond
what Ingress/HA already provides.

## Custom `unbound.conf` and Overlay Files

See the README's "Custom Configuration" and "Overlay Files" sections for the
full mechanism (`unbound-overlay.conf` / `unbound-extra.conf` under
`/addon_configs/<slug>_unbound/`). In short:

- **Full custom config**: enable "Custom Config" in the web UI, then place a
  complete `unbound.conf` at the addon config path. When enabled, all GUI
  settings are ignored.
- **Overlay files**: keep GUI-managed settings but inject a few extra
  `server:` directives or whole top-level sections (`auth-zone:`, `view:`)
  that the GUI doesn't expose.

If the combined configuration fails `unbound-checkconf` validation, the
add-on automatically falls back to GUI-only settings and surfaces the
validation error in the **Advanced** tab, so a bad snippet never takes DNS
resolution down.

## Log Level

The only option exposed in the HA add-on panel (`log_level`) controls the
verbosity of the add-on's own supervisor process log — it does not affect
what's recorded in the web UI's query log, which is controlled separately
via the **Logging** section in the web UI's Server Settings.
