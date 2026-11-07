# Signal Bridge (mautrix)

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![mautrix-signal Version](https://img.shields.io/badge/mautrix--signal-v0.2610.0-3A76F0?style=for-the-badge&logo=signal&logoColor=white)](https://github.com/mautrix/signal)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Application service bridge that connects Signal to a self-hosted Matrix Synapse homeserver via
[mautrix-signal](https://github.com/mautrix/signal). Runs as a standalone,
isolated app (no shared container with other bridges — see the isolation philosophy).

## Installation

1. Install and start the app.
2. Set options: `homeserver_address` / `homeserver_domain` (address of the Matrix Synapse
   app), `db_type` (SQLite or Postgres).
3. On the first start the bridge generates automatically:
   - `config.yaml` (from the options you set)
   - `registration.yaml`, copied to `/share/signal_bridge_registration.yaml`
4. In the **Matrix Synapse app** enable the option `signal_bridge_enabled` and restart
   Synapse (Synapse only reads the appservice registration then).
5. In any Matrix client send a DM to `@signalbot:<your-domain>`,
   send `login` and scan the QR code with Signal (Linked devices).

## Links

- Upstream: https://github.com/mautrix/signal
- Docs: https://docs.mau.fi/bridges/go/signal/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
