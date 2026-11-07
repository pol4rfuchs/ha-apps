# UniFi Toolkit

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![UniFi Toolkit Version](https://img.shields.io/badge/UniFi%20Toolkit-1.13.3-0559C9?style=for-the-badge&logo=ubiquiti&logoColor=white)](https://github.com/Crosstalk-Solutions/unifi-toolkit)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

</div>

Experimental Home Assistant app that packages the open-source
[UniFi Toolkit](https://github.com/Crosstalk-Solutions/unifi-toolkit) by Crosstalk Solutions (MIT).

## Included tools

- **Dashboard** - gateway, WAN, clients and network health at a glance
- **Wi-Fi Stalker** - track devices, roaming history, block/unblock
- **Threat Watch** - IDS/IPS events with ignore rules and webhooks
- **Network Pulse** - live network and access point charts
- **House Arrest** - per-device and per-network lockdown via the UniFi zone-based firewall

## Installation

Add the `pol4rfuchs/ha-apps` repository to Home Assistant, install **UniFi Toolkit**,
start it and open the **UniFi Toolkit** panel. On first use, enter your controller URL
and a UniFi API key inside the Toolkit UI.

## Notes

- The UI is only reachable through Home Assistant Ingress; no host port is exposed.
- Upstream is pinned to a verified release and is not modified. Ingress support is a small wrapper in this app.
- Not affiliated with Ubiquiti Inc. or Crosstalk Solutions.

## Links

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Upstream project](https://github.com/Crosstalk-Solutions/unifi-toolkit)
- [Source](https://github.com/pol4rfuchs/ha-apps)
