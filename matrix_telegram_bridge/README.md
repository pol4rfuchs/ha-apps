# Telegram Bridge (mautrix)

Application service bridge that connects Telegram to a self-hosted Matrix Synapse homeserver via
[mautrix-telegram](https://github.com/mautrix/telegram). Runs as a standalone,
isolated add-on (no shared container with other bridges — see the isolation philosophy).

## Installation

1. Install and start the add-on.
2. Register an app at https://my.telegram.org (free) and enter `telegram_api_id` +
   `telegram_api_hash` in the add-on options — **without these two values
   the bridge does not connect to Telegram.**
3. Set further options: `homeserver_address` / `homeserver_domain` (address of the
   Matrix Synapse add-on), `db_type` (SQLite or Postgres).
4. On the first start the bridge generates automatically:
   - `config.yaml` (from the options you set)
   - `registration.yaml`, copied to `/share/telegram_bridge_registration.yaml`
5. In the **Matrix Synapse add-on** enable the option `telegram_bridge_enabled` and restart
   Synapse (Synapse only reads the appservice registration then).
6. In any Matrix client send a DM to `@telegrambot:<your-domain>` and
   send `login` — unlike WhatsApp/Signal the login works via phone number +
   SMS/app code, not via QR scan.

## Links

- Upstream: https://github.com/mautrix/telegram
- Docs: https://docs.mau.fi/bridges/go/telegram/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
