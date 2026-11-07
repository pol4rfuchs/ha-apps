# Telegram Bridge (mautrix)

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![mautrix-telegram Version](https://img.shields.io/badge/mautrix--telegram-v0.2610.0-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://github.com/mautrix/telegram)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Application service bridge that connects Telegram to a self-hosted Matrix Synapse homeserver via
[mautrix-telegram](https://github.com/mautrix/telegram). Runs as a standalone,
isolated app (no shared container with other bridges — see the isolation philosophy).

## Installation

1. Install and start the app.
2. Register an app at https://my.telegram.org (free) and enter `telegram_api_id` +
   `telegram_api_hash` in the app options — **without these two values
   the bridge does not connect to Telegram.**
3. Set further options: `homeserver_address` / `homeserver_domain` (address of the
   Matrix Synapse app), `db_type` (SQLite or Postgres).
4. On the first start the bridge generates automatically:
   - `config.yaml` (from the options you set)
   - `registration.yaml`, copied to `/share/telegram_bridge_registration.yaml`
5. In the **Matrix Synapse app** enable the option `telegram_bridge_enabled` and restart
   Synapse (Synapse only reads the appservice registration then).
6. In any Matrix client send a DM to `@telegrambot:<your-domain>` and
   send `login` — unlike WhatsApp/Signal the login works via phone number +
   SMS/app code, not via QR scan.

## Links

- Upstream: https://github.com/mautrix/telegram
- Docs: https://docs.mau.fi/bridges/go/telegram/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
