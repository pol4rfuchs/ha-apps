# Signal Bridge (mautrix)

Application service bridge that connects Signal to a self-hosted Matrix Synapse homeserver via
[mautrix-signal](https://github.com/mautrix/signal). Runs as a standalone,
isolated add-on (no shared container with other bridges — see the isolation philosophy).

## Installation

1. Install and start the add-on.
2. Set options: `homeserver_address` / `homeserver_domain` (address of the Matrix Synapse
   add-on), `db_type` (SQLite or Postgres).
3. On the first start the bridge generates automatically:
   - `config.yaml` (from the options you set)
   - `registration.yaml`, copied to `/share/signal_bridge_registration.yaml`
4. In the **Matrix Synapse add-on** enable the option `signal_bridge_enabled` and restart
   Synapse (Synapse only reads the appservice registration then).
5. In any Matrix client send a DM to `@signalbot:<your-domain>`,
   send `login` and scan the QR code with Signal (Linked devices).

## Links

- Upstream: https://github.com/mautrix/signal
- Docs: https://docs.mau.fi/bridges/go/signal/index.html
- Repo: https://github.com/pol4rfuchs/ha-apps
