# Forgejo — Advanced Documentation

This document covers persistent data, backup, secrets, and advanced
configuration beyond the quick-start steps in the README.

## Persistent Data / Backup

Everything lives under the add-on's own config mount:

```
/addon_configs/local_forgejo/   (host path)
/config/                        (inside the container)
├── conf/app.ini                ← Forgejo configuration (editable directly)
├── data/                       ← SQLite DB, packages, sessions
├── repositories/                ← Git repositories
├── ssh/                          ← SSH host keys
└── log/                           ← logs
```

A Home Assistant full backup (which includes `addon_configs` by default)
already covers all of this — no add-on-specific backup hooks are
configured. If you only want to back up Forgejo on its own, back up the
entire `/addon_configs/local_forgejo/` folder.

## Secrets

There's no dedicated `password`-type secret in this add-on's own
`options`/`schema` — Forgejo manages its own admin account and user
credentials internally (created via its own setup wizard on first start,
stored in `data/`, not exposed through the HA options UI). SSH host keys
under `ssh/` are generated on first start and should be treated as
sensitive if you ever copy the `/config/` folder elsewhere.

## Advanced Configuration (`app.ini`)

Any Forgejo setting not exposed in the HA options UI can be set directly in
`/config/conf/app.ini`:

```ini
[service]
DISABLE_REGISTRATION = true

[packages]
ENABLED = true

[actions]
ENABLED = true
```

Or via environment variables (applied automatically on start):
```
FORGEJO__service__DISABLE_REGISTRATION=true
FORGEJO__packages__ENABLED=true
```

See the [Forgejo configuration cheat sheet](https://forgejo.org/docs/latest/admin/config-cheat-sheet/)
for the full list of sections and keys.

## AppArmor

The add-on ships an `apparmor.txt` profile (s6-overlay baseline plus Forgejo's
own runtime paths), but `apparmor: false` is set in `config.yaml`, so the
profile is **not enforced** at the moment. If AppArmor is enabled later and you
use custom `app.ini` settings that make Forgejo read/write paths outside
`/config` (e.g. a custom hook script location), the profile needs a matching
rule for that path.

## Local and external access

**Local (LAN, default):** open Forgejo at `http://<ha-host>:3000`. There is no Ingress (assets break behind it). Set the option `domain` to the hostname or IP you use (for example the IP of your HA host). Without it Forgejo falls back to `localhost`, links and clone URLs then point to `localhost`, and the log shows a warning. For HTTPS inside the app set `ssl: true` with `certfile`/`keyfile` from `/ssl`; the root URL is then `https://<domain>/` without a port, so forward port 443 to 3000 or put a reverse proxy in front.

**External (internet):** recommendation **ok, but only through a reverse proxy with TLS** (for example Nginx Proxy Manager). Never forward port 3000 or the SSH port directly. Before exposing the instance:

- Disable open registration (`DISABLE_REGISTRATION = true`, see *Advanced Configuration*). It is **off by default**, so anyone who can reach the server can create an account.
- Create the admin account in the first-run wizard and protect it with a strong password.
- Keep SSH disabled (`ssh_enabled: false`) unless you need git over SSH; if you enable it, forward the port only deliberately.

