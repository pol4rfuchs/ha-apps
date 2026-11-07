# UniFi OS Control Center

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![App Version](https://img.shields.io/badge/UniFi%20OS%20Control%20Center-0.7.11-0559C9?style=for-the-badge&logo=ubiquiti&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Experimental, local-first UniFi OS monitoring and management app for Home Assistant.

## Current scope

- Home Assistant Ingress UI with functional navigation and inventory detail views
- Local UniFi Network API connectivity using a dedicated API key
- Sites, gateways, access points, clients, firmware inventory, and raw API inspection
- Legacy-versus-Zone-Based Firewall capability detection
- Read-only firewall policies, zones, diagnostics, analysis, and local snapshots where supported
- Persistent SQLite WAL telemetry and alert history with retention and row limits
- Optional ntfy notifications for connection, new-client, and device-health events
- Explicit UniFi device offline/recovery monitoring with configurable grace polling
- Multi-architecture support for `aarch64` and `amd64`
- s6-overlay lifecycle handling; an AppArmor profile is shipped but not enforced (`apparmor: false`)

## Installation

Add the `pol4rfuchs/ha-apps` repository to Home Assistant, install **UniFi OS Control Center**, configure the local controller URL and API key, then open the Ingress panel.

For local HAOS testing, copy the complete app directory to `/addons/unifi_os_control_center/`. The committed `frontend/dist/` directory is required because local builds intentionally do not execute npm on the HAOS host.

## Security

Use a dedicated UniFi API key with the minimum required permissions. Keep `read_only: true` unless a future write module has been explicitly enabled and tested. The backend rejects non-read UniFi methods before contacting the controller while read-only mode is active.

## Links

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Source](https://github.com/pol4rfuchs/ha-apps)
