# Extended Documentation — Telegram Bridge (mautrix)

## Secrets

`as_token`/`hs_token` in `/data/registration.yaml` are generated automatically at the
initial registration and **must not** be changed afterwards — otherwise Synapse loses the
link to the appservice and all rooms/users that have already been bridged break.

`telegram_api_id`/`telegram_api_hash` are your own values issued by Telegram
(https://my.telegram.org) — not to be confused with as_token/hs_token. Without them the
bridge starts (log warning), but cannot establish a Telegram connection.

## Appservice registration (shared volume)

This bridge writes its `registration.yaml` to `/share/telegram_bridge_registration.yaml`.
The Matrix Synapse add-on only reads this file if the option
`telegram_bridge_enabled` is enabled there (a Synapse restart is needed afterwards).

## Backup

- `/data` contains `config.yaml`, `registration.yaml` and, with SQLite, the complete
  bridge database — it **must** be backed up, otherwise Telegram has to be linked again
  after a restore (phone number + code needed again).
- `telegram_api_id`/`telegram_api_hash` are plain config values, not a separate secret file.

## Login flow

Unlike WhatsApp/Signal, the login does **not** work via QR code but the classic way via
phone number + SMS/app confirmation code (Telegram's own login flow, MTProto protocol).
Send the `login` command to the bridge bot, enter the phone number, type in the code from the Telegram app
or SMS.

## Local and external access

**Local (LAN):** The bridge has no web interface and publishes no host port. The appservice port `29317` is only reachable in Home Assistant's internal network, so that the Matrix Synapse add-on can reach the bridge (`appservice_address`). The link is protected by `as_token`/`hs_token` in `/data/registration.yaml`; treat `/data` and `/share/telegram_bridge_registration.yaml` like a secret.

**External (internet):** Recommendation: **forward nothing.** The bridge connects outbound to Telegram; only Synapse needs to be reachable from outside (see its documentation), never the bridge itself.

## Known limitations / deliberate simplifications

- **LottieConverter is not included in the image** (saves resources, §12) — animated
  sticker/emoji packs may therefore not be bridged correctly. Can be added in the
  Dockerfile if needed.
- Encryption (Megolm) must be enabled on both sides (bridge option `encryption` + Matrix client)
  to get encrypted portal rooms.
- Go rewrite (April 2026): according to the upstream release notes the old Python relaybot mode
  is not migrated automatically — if needed, maintain `default_relays` manually in `config.yaml`
  (only affects anyone who already had a Python instance before, not us).
