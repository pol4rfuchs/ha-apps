# Restic Backup — Advanced Documentation

This document covers secrets, backup/restore, and advanced configuration
beyond the quick-start steps in the README.

## Secrets

- **`restic_password`** is the encryption password for the entire restic
  repository. There is no recovery mechanism if it's lost — restic
  repositories cannot be decrypted without it. Store a copy somewhere
  outside this add-on (a password manager, printed and stored physically,
  etc.) before relying on this add-on for real backups.
- **`aws_secret_access_key`** / **`aws_access_key_id`** are only needed for
  S3/MinIO/B2-compatible remote repositories. Leave both empty for the
  default local repository.
- **`ntfy_password`** is only needed if your ntfy topic requires
  authentication.

All three are declared as `password` schema types, so the Supervisor UI
masks them.

## Backup and Restore

This add-on only performs the **backup** side of the restic workflow.
Restoring is intentionally a manual, out-of-band step — there is no
one-click restore button, to avoid an accidental data-loss action.

To restore, open a shell with access to the same repository and run restic
directly, using the same repository location and password configured in
this add-on:

```bash
export RESTIC_REPOSITORY=/share/restic-backup/repo   # or your configured repository
export RESTIC_PASSWORD=your-restic-password
restic snapshots                 # list available snapshots
restic restore latest --target /path/to/restore/to
```

For remote (S3/MinIO/B2) repositories, also export the same
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_DEFAULT_REGION` used by
the add-on.

## backup_paths vs. map

`backup_paths` only lists which mounted folders restic should walk — it
does not mount anything itself. Each path listed here must already be
exposed via the add-on's own `map:` block in `config.yaml` (currently:
`homeassistant_config:ro`, `addon_configs:ro`, `media:ro`, `share:rw`,
`ssl:ro`). Adding a path to `backup_paths` that isn't mapped does nothing —
the directory simply won't exist inside the container.

## AppArmor

The bundled `apparmor.txt` profile covers:
- the s6-overlay baseline paths (required so a clean restart doesn't crash
  with a `/init: Permission denied` loop)
- the mapped read-only backup sources (`/homeassistant`, `/addon_configs`,
  `/media`, `/ssl`)
- the read-write repository target (`/share`)
- `dcron`'s crontab files and restic's own lock file under `/tmp`

If you add extra mapped folders beyond the current `map:` block, the
AppArmor profile needs a matching read (or read-write) rule added for that
path, or restic will silently fail to read/write it under enforcement.
