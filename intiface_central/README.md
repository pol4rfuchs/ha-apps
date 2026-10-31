<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/intiface_central/icon.png" alt="Intiface Central Icon" width="256">

# 🎛️ Intiface Central / Lovense Control — Home Assistant App

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Intiface Engine](https://img.shields.io/badge/Intiface%20Engine-4.0.2-8E44AD?style=for-the-badge&logoColor=white)](https://github.com/intiface/intiface-engine)
[![Home Assistant App](https://img.shields.io/badge/Home%20Assistant-App-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Buttplug/Intiface Central with browser WebGUI, MQTT bridge and Home Assistant entity auto-discovery — no VNC, no X11.**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Engine** | `intiface-engine`, compiled from source for the target architecture |
| **Engine version** | `4.0.2` |
| **Web UI port** | `8199` |
| **Intiface port** | `12345` (option `engine_ws_port`) |
| **Arch** | `amd64`, `aarch64` (both native) |
| **Bluetooth** | Host BLE passthrough (D-Bus) |
| **USB/HID** | Host kernel passthrough |

> **Status:** experimental and frozen. The app has no login and is meant for your LAN or a VPN only. See the *Local and external access* section in [DOCS.md](DOCS.md).

---

## ✨ Features

- **Browser WebGUI** — no VNC, no X11, no noVNC overhead
- **Device control** directly in the browser with vibration sliders
- **Pattern Editor** — create, save and play vibration patterns (patterns are stored in the browser)
- **MQTT Bridge** — each device/motor available as an MQTT topic
- **Home Assistant MQTT Discovery** — automatic entities without YAML (opt-in)
- **Bluetooth LE + USB/HID** via host passthrough
- **Native `aarch64` build**, no emulation

---

## 🏗️ Architecture

```
Browser  ←──── WebGUI (/api/*, SSE) ─────────────────┐
                                                        │
HA Automation ←── MQTT ──→ mqtt-bridge ──→ Node.js ──→ intiface-engine :12345
                                                        │
External clients (games, etc.) ───────────────────────►┘
```

---

## 🚀 Installation

### Step 1 — Add the repository

```text
Settings → Add-ons → Add-on Store → ⋮ → Repositories
```

Add:

```text
https://github.com/pol4rfuchs/ha-apps
```

### Step 2 — Install & configure

Install **Intiface Central**. If you want MQTT integration, set the broker options in the Configuration tab.

### Step 3 — Start

Click **Open Web UI** — the browser interface opens on port `8199`.

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `engine_ws_port` | `12345` | Port of the Buttplug WebSocket server (external clients connect here). |
| `use_bluetooth_le` | `true` | Enable Bluetooth LE devices. |
| `use_hid` | `true` | Enable USB/HID devices (e.g. Lovense dongle). |
| `use_serial` | `false` | Enable serial-port devices. |
| `log_level` | `info` | Log level of the engine: `error` / `warn` / `info` / `debug`. |
| `mqtt_host` | — | MQTT broker hostname or IP. Leave empty to disable the MQTT bridge. |
| `mqtt_port` | `1883` | MQTT broker port. |
| `mqtt_user` | — | MQTT username. |
| `mqtt_pass` | — | MQTT password. |
| `mqtt_topic_prefix` | `buttplug` | Prefix of all MQTT topics. |
| `ha_discovery` | `false` | Create Home Assistant entities through MQTT discovery. |
| `ha_discovery_prefix` | `homeassistant` | Discovery prefix of your MQTT integration. |

---

## 🌐 Ports

| Port | Protocol | Purpose |
|---|---|---|
| `12345` | TCP | Intiface Engine WebSocket (external clients) |
| `8199` | TCP | WebGUI |

---

## 🔵 Bluetooth & USB

Bluetooth LE and USB/HID devices are accessed directly through the host (D-Bus and kernel) — no additional configuration required. The engine is built natively for your architecture, so Raspberry Pi (`aarch64`) and x86 behave the same.

---

## 🏠 MQTT topics

With `mqtt_host` set, devices are available under the configured prefix (default `buttplug`):

| Topic | Description |
|---|---|
| `buttplug/<idx>/motor/<m>/set` | Set vibration intensity (`0.0`–`1.0`) |
| `buttplug/<idx>/motor/<m>/state` | Current state |
| `buttplug/<idx>/stop` | Stop the device |
| `buttplug/<idx>/vibrate` | JSON array of motor intensities |
| `buttplug/<idx>/availability` | `online` / `offline` |
| `buttplug/scan/start`, `buttplug/scan/stop` | Start / stop scanning |
| `buttplug/stop_all` | Stop all devices |

With `ha_discovery: true`, Home Assistant creates a number entity per motor, a stop button and a connection sensor automatically.

---

## 💾 Data persistence

```text
/data/home/    ← intiface-engine data
```

Vibration patterns are saved in your browser (localStorage), not on the server.

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| Web UI not opening | Check port `8199` in the Network tab |
| Device not found | Ensure Bluetooth is enabled on the host; restart the add-on |
| Engine does not start with `use_serial: true` | Update to a version of the add-on that passes `--use-serial` (older versions passed an argument the engine rejects) |
| MQTT entities not appearing | Verify broker hostname, that the MQTT integration is configured in HA, and that `ha_discovery` is `true` |
| Need more detail in the log | Set `log_level: debug` |

---

## 🏗️ Supported architectures

| Arch | Support |
|---|---|
| `amd64` | ✅ Native |
| `aarch64` | ✅ Native |

---

## 📜 License

The Home Assistant app wrapper, metadata, Dockerfile, scripts,
workflows and documentation in this directory are licensed under the
Apache License 2.0.

The upstream Intiface / Buttplug components are not relicensed by this
repository and remain under their respective upstream licenses.

Upstream projects:

- Intiface Engine: https://github.com/intiface/intiface-engine
- Intiface / Buttplug ecosystem: https://github.com/intiface

See also:

- [`../LICENSE`](../LICENSE)
- [`../NOTICE`](../NOTICE)
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)
