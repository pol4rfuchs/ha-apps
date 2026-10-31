# Extended Documentation — WhatsApp Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` are generated automatically at the
initial registration and **must not** be changed afterwards — otherwise Synapse loses the
link to the appservice and all rooms/users that have already been bridged break.

## Appservice registration (shared volume)

This bridge writes its `registration.yaml` to `/share/whatsapp_bridge_registration.yaml`.
The Matrix Synapse add-on only reads this file if the option
`whatsapp_bridge_enabled` is enabled there (a Synapse restart is needed afterwards).

If anything changes on this bridge that affects the appservice registration
(`appservice_id`, bot username, namespaces), `/data/registration.yaml` must be deleted
so that it is regenerated on the next start — Synapse must be restarted afterwards as well.

## Backup

- `/data` contains `config.yaml`, `registration.yaml` and, with SQLite, the complete
  bridge database (session state, message mapping) — it **must** be backed up,
  otherwise WhatsApp has to be linked again after a restore.
- `/share/whatsapp_bridge_registration.yaml` can be reproduced from `/data/registration.yaml`
  (it is copied again automatically on the next start if missing) — it is not strictly
  part of the backup.

## Switching the database (SQLite → Postgres)

There is no automatic migration path. Changing `db_type` after the first start results
in an empty database (all links/history are lost) — cleanly disconnect the `login` state beforehand
(`logout` in the bridge chat) and link again afterwards.

## Local and external access

**Local (LAN):** The bridge has no web interface and publishes no host port. The appservice port `29318` is only reachable in Home Assistant's internal network, so that the Matrix Synapse add-on can reach the bridge (`appservice_address`). The link is protected by `as_token`/`hs_token` in `/data/registration.yaml`; treat `/data` and `/share/whatsapp_bridge_registration.yaml` like a secret.

**External (internet):** Recommendation: **forward nothing.** The bridge connects outbound to WhatsApp; only Synapse needs to be reachable from outside (see its documentation), never the bridge itself.

## Known limitations

- One bridge instance per WhatsApp account is needed (no multi-account
  within a single bridge instance is intended).
- Encryption (Megolm) must be enabled on both sides (bridge option `encryption` + Matrix client)
  to get encrypted portal rooms.
