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

`apparmor: true` is enabled with a profile covering the s6-overlay baseline
plus Forgejo's own runtime paths (`/config`, SSH host keys, git binaries).
If you add custom `app.ini` settings that make Forgejo read/write paths
outside `/config` (e.g. a custom hook script location), the AppArmor
profile needs a matching rule added for that path.
