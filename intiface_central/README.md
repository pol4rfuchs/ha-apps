<div align="center">
  

# 🎛️ Intiface Central / Lovense Control — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Intiface](https://img.shields.io/badge/Intiface-Engine-8E44AD?style=for-the-badge&logoColor=white)](https://github.com/intiface/intiface-engine)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Buttplug/Intiface Central with browser WebGUI, MQTT bridge and Home Assistant entity auto-discovery — no VNC, no X11.**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Engine** | `intiface-engine` (x64, via box64 on ARM) |
| **Web UI port** | `12346` |
| **Intiface port** | `12345` |
| **Arch** | `amd64`, `aarch64` (via box64) |
| **Bluetooth** | Host BLE passthrough |
| **USB/HID** | Host kernel passthrough |

---

## ✨ Features

- **Browser WebGUI** — no VNC, no X11, no noVNC overhead
- **Device control** directly in the browser with vibration sliders
- **Pattern Editor** — create, save and play vibration patterns
- **MQTT Bridge** — each device/motor available as an MQTT topic
- **Home Assistant MQTT Discovery** — automatic entities without YAML
- **Bluetooth LE + USB/HID** via host kernel passthrough
- **aarch64** support via [box64](https://github.com/ptitSeb/box64)

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

Click **Open Web UI** — the browser interface opens on port `12346`.

---

## ⚙️ Configuration

| Option | Default | Description |
|---|---|---|
| `mqtt_host` | — | MQTT broker hostname or IP. Leave empty to disable MQTT bridge. |
| `mqtt_port` | `1883` | MQTT broker port. |
| `mqtt_username` | — | MQTT username. |
| `mqtt_password` | — | MQTT password. |
| `mqtt_discovery` | `true` | Enable HA MQTT auto-discovery. |

---

## 🌐 Ports

| Port | Protocol | Purpose |
|---|---|---|
| `12345` | TCP | Intiface Engine WebSocket (external clients) |
| `12346` | TCP | WebGUI |

---

## 🔵 Bluetooth & USB

Bluetooth LE and USB/HID devices are accessed directly through the host kernel — no additional configuration required.

On aarch64 (Raspberry Pi), the x64 intiface-engine binary runs via box64. Bluetooth and USB are unaffected — they run natively through the host.

---

## 🏠 MQTT topics

Each device and motor is exposed as:

```
intiface/devices/<device_id>/motor/<motor_index>/vibrate
```

Publish a value between `0.0` and `1.0` to control intensity.

HA MQTT Discovery creates entities automatically when `mqtt_discovery: true`.

---

## 💾 Data persistence

```text
/data/
└── patterns/    ← Saved vibration patterns
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| Web UI not opening | Check port `12346` in the Network tab |
| Device not found | Ensure Bluetooth is enabled on the host; restart add-on |
| box64 error on ARM | Check add-on log; verify `ENGINE_VERSION` in Dockerfile matches a current release |
| MQTT entities not appearing | Verify broker hostname and that MQTT integration is configured in HA |
| Engine binary download fails | Check current release URL at [intiface-engine releases](https://github.com/intiface/intiface-engine/releases) and update `ENGINE_VERSION` in the Dockerfile |

---

## 🏗️ Supported architectures

| Arch | Support |
|---|---|
| `amd64` | ✅ Native |
| `aarch64` | ✅ via box64 |

---

## 📜 License

MIT — this add-on wrapper.  
intiface-engine is licensed under [BSD-3-Clause](https://github.com/intiface/intiface-engine/blob/main/LICENSE).
