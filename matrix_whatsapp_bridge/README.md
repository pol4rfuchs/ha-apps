# WhatsApp Bridge (mautrix)

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![mautrix-whatsapp Version](https://img.shields.io/badge/mautrix--whatsapp-v0.2610.0-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)](https://github.com/mautrix/whatsapp)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Application service bridge that connects WhatsApp to a self-hosted Matrix Synapse homeserver via
[mautrix-whatsapp](https://github.com/mautrix/whatsapp). Runs as a standalone,
isolated app (no shared container with other bridges — see the isolation philosophy).

## Installation

1. Install and start the app.
2. Set options: `homeserver_address` / `homeserver_domain` (address of the Matrix Synapse
   app), `db_type` (SQLite or Postgres).
3. On the first start the bridge generates automatically:
   - `config.yaml` (from the options you set)
   - `registration.yaml`, copied to `/share/whatsapp_bridge_registration.yaml`
4. In the **Matrix Synapse app** enable the option `whatsapp_bridge_enabled` and restart
   Synapse (Synapse only reads the appservice registration then).
5. In any Matrix client send a DM to `@whatsappbot:<your-domain>`,
   send `login` and scan the QR code with WhatsApp (Linked devices).

## Links

- Upstream: https://github.com/mautrix/whatsapp
- Docs: https://docs.mau.fi/bridges/go/whatsapp/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
