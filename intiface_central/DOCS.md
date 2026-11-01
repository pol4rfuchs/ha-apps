# Intiface Central for Home Assistant

Full add-on with its own web GUI, MQTT bridge and automatic Home Assistant entities.

## Access

After starting → **Open Web UI** on the add-on page.

## External clients (games, apps)

Standard Buttplug WebSocket: `ws://homeassistant.local:12345`

## MQTT Bridge

If an MQTT host is configured, devices become available as topics automatically:

| Topic | Description |
|---|---|
| `buttplug/{idx}/motor/{m}/set` | Set the vibration strength (0.0–1.0) |
| `buttplug/{idx}/motor/{m}/state` | Current state |
| `buttplug/{idx}/stop` | Stop the device |
| `buttplug/{idx}/vibrate` | JSON array of motor strengths |
| `buttplug/{idx}/availability` | `online`/`offline` |
| `buttplug/scan/start` | Start a scan |
| `buttplug/scan/stop` | Stop a scan |
| `buttplug/stop_all` | Stop all |

## Home Assistant entities

With `ha_discovery` enabled, the following are created automatically:
- **Number entity** per vibration motor (slider 0.0–1.0)
- **Button entity** to stop
- **Binary sensor** for the connection status

## Pattern editor

The built-in pattern editor lets you create vibration patterns:
- Any number of steps with duration and intensity per motor
- Preinstalled presets: Pulse, Escalating, Wave, Heartbeat, Random, Staccato
- Patterns are stored in the browser (localStorage)
- Server-side playback via the REST API is possible

## Options

| Option | Description |
|---|---|
| `engine_ws_port` | WebSocket port (default: 12345) |
| `use_bluetooth_le` | Enable Bluetooth LE |
| `use_hid` | Enable USB/HID (Lovense dongle) |
| `use_serial` | Enable serial |
| `log_level` | Log level (error/warn/info/debug) |
| `mqtt_host` | MQTT broker IP/hostname |
| `mqtt_port` | MQTT broker port |
| `mqtt_user` | MQTT username |
| `mqtt_pass` | MQTT password |
| `mqtt_topic_prefix` | MQTT topic prefix (default: buttplug) |
| `ha_discovery` | Enable HA MQTT discovery |
| `ha_discovery_prefix` | HA discovery prefix (default: homeassistant) |

## Persistence

Settings and intiface-engine data are stored under `/data/home`.

## Local and external access

**Local (LAN):** The app runs with `host_network`. The web interface (`8199`) and the Buttplug WebSocket (`12345`) listen on **all interfaces**, both without login. This is intended for local clients.

**External (internet):** Recommendation: **LAN or VPN only, never the internet.** No port forward to `8199` or `12345`, not even through a reverse proxy, because there is no authentication. AppArmor is currently disabled (hardware/bus access).

**Status:** experimental and frozen. The app is no longer developed; it will not get a login. Use it only on the LAN or via VPN.
