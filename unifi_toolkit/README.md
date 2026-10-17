# UniFi Toolkit

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
