# NetBox

[NetBox](https://github.com/netbox-community/netbox) as a Home Assistant app – the open source IPAM and DCIM tool to document your network: IP addresses, prefixes, VLANs, racks, devices, cables. PostgreSQL and Valkey are built in, nothing else has to be set up.

**Status:** wip

Important: the first start applies the database migrations and takes several minutes on a Raspberry Pi. The first admin password is written to the app's configuration folder, see [DOCS.md](DOCS.md).

## Installation

1. Open **Settings → Apps → App Store** in Home Assistant.
2. In the menu at the top right choose **Repositories** and add `https://github.com/pol4rfuchs/ha-apps`.
3. Select **NetBox** in the list and click **Install**.
4. Set `allowed_hosts` to the address you will open NetBox with, start the app and wait until the log says `Starting NetBox`.
5. Open `http://<ha-host>:8001` and log in (see [DOCS.md](DOCS.md), section *First start*).

See [DOCS.md](DOCS.md) for configuration details.

## Links

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Repository ha-apps](https://github.com/pol4rfuchs/ha-apps)
- [NetBox (Upstream)](https://github.com/netbox-community/netbox)
- [NetBox documentation](https://netboxlabs.com/docs/netbox/)
- [netbox-docker (the image this app is built on)](https://github.com/netbox-community/netbox-docker)
