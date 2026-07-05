# Restic Backup

Scheduled [restic](https://restic.net/) backups for Home Assistant, with [ntfy](https://ntfy.sh/) alerting on success or failure.

## What it does

- Runs `restic backup` on a cron schedule against a configurable set of mapped folders (defaults: `/homeassistant`, `/addon_configs`, `/ssl`).
- Initializes the restic repository automatically on first start if it doesn't exist yet.
- Applies retention (`forget --prune`) after each successful backup.
- Sends an ntfy notification after every run — success or failure — if `ntfy_url`/`ntfy_topic` are configured. Failures go out as `urgent` priority.
- Supports both local repositories (default: `/share/restic-backup/repo`) and S3/MinIO/B2-compatible remote repositories.

## Quick start

1. Set `restic_password` to something strong and **back it up somewhere outside this add-on**. Without it, the repository is unrecoverable.
2. Leave `repository` as the local default, or point it at a remote (e.g. `s3:https://minio.local/bucket-name`) and fill in `aws_access_key_id` / `aws_secret_access_key` if required.
3. Optionally set `ntfy_url` + `ntfy_topic` to get notified. Fits naturally into an existing `ha-system`-style topic.
4. Start the add-on. Check the log for `Repository initialized.` on first run.
5. Enable `run_on_start` once to verify the config, then turn it back off and let `cron_schedule` handle it.

## Notes

- `backup_paths` must be covered by the add-on's `map:` config — adding a path here without also mapping it (e.g. `media:ro`) does nothing.
- This add-on only handles the backup side. Restoring is a manual `restic restore` from a shell with the same `RESTIC_REPOSITORY` / `RESTIC_PASSWORD` — intentionally not automated inside the add-on to avoid an accidental one-click data-loss button.
- `apparmor: true` is enabled but this add-on currently ships without a dedicated `apparmor.txt` profile (default HA base profile applies). Follows the same backlog pattern as the other add-ons pending a hardening pass.
