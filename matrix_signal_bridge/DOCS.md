# Extended Documentation — Signal Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` are generated automatically at the
initial registration and **must not** be changed afterwards — otherwise Synapse loses the
link to the appservice and all rooms/users that have already been bridged break.

## Appservice registration (shared volume)

This bridge writes its `registration.yaml` to `/share/signal_bridge_registration.yaml`.
The Matrix Synapse add-on only reads this file if the option
`signal_bridge_enabled` is enabled there (a Synapse restart is needed afterwards).

## Backup

- `/data` contains `config.yaml`, `registration.yaml` and, with SQLite, the complete
  bridge database (session state, message mapping) — it **must** be backed up,
  otherwise Signal has to be linked again after a restore.
- `/share/signal_bridge_registration.yaml` can be reproduced from `/data/registration.yaml`
  (it is copied again automatically on the next start if missing) — it is not strictly
  part of the backup.

## Build specifics (Rust + Go)

Signal is the only one of the three bridges that needs a Rust build step in addition to Go
(`libsignal_ffi.a`, the official Signal protocol in Rust). The build follows the official
`mautrix/signal` Dockerfile exactly: stage 1 builds `libsignal_ffi.a` via `build-rust.sh`,
stage 2 links Go against it via `build-go.sh` (`LIBRARY_PATH`). As a result the build time is noticeably
longer than for WhatsApp/Telegram — a pure CI time effect with no impact on runtime RAM.

## Linking

Unlike WhatsApp, linking works through "Linked devices" in the Signal
settings, not through an in-app QR scanner. On the first login Signal asks whether the
message history should be transferred — optional, but recommended for full
context in Matrix.

## Local and external access

**Local (LAN):** The bridge has no web interface and publishes no host port. The appservice port `29328` is only reachable in Home Assistant's internal network, so that the Matrix Synapse add-on can reach the bridge (`appservice_address`). The link is protected by `as_token`/`hs_token` in `/data/registration.yaml`; treat `/data` and `/share/signal_bridge_registration.yaml` like a secret.

**External (internet):** Recommendation: **forward nothing.** The bridge connects outbound to Signal; only Synapse needs to be reachable from outside (see its documentation), never the bridge itself.

## Known limitations

- Registering as a Signal primary device is not supported by the bridge — only
  linking as a secondary device (official app or `signal-cli`).
- Encryption (Megolm) must be enabled on both sides (bridge option `encryption` + Matrix client)
  to get encrypted portal rooms.
