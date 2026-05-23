# Intiface Central für Home Assistant

Vollwertiges Add-on mit eigener WebGUI, MQTT-Bridge und automatischen Home-Assistant-Entities.

## Zugriff

Nach dem Start → **Open Web UI** in der Add-on-Seite.

## Externe Clients (Spiele, Apps)

Standard Buttplug WebSocket: `ws://homeassistant.local:12345`

## MQTT Bridge

Wenn MQTT Host konfiguriert ist, werden Geräte automatisch als Topics verfügbar:

| Topic | Beschreibung |
|---|---|
| `buttplug/{idx}/motor/{m}/set` | Vibrationsstärke setzen (0.0–1.0) |
| `buttplug/{idx}/motor/{m}/state` | Aktueller Zustand |
| `buttplug/{idx}/stop` | Gerät stoppen |
| `buttplug/{idx}/vibrate` | JSON-Array mit Motorstärken |
| `buttplug/{idx}/availability` | `online`/`offline` |
| `buttplug/scan/start` | Scan starten |
| `buttplug/scan/stop` | Scan stoppen |
| `buttplug/stop_all` | Alle stoppen |

## Home Assistant Entities

Mit aktiviertem `ha_discovery` werden automatisch erstellt:
- **Number-Entity** pro Vibrations-Motor (Slider 0.0–1.0)
- **Button-Entity** zum Stoppen
- **Binary Sensor** für Verbindungsstatus

## Pattern Editor

Der eingebaute Pattern Editor erlaubt es, Vibrationsmuster zu erstellen:
- Beliebig viele Schritte mit Dauer und Intensität pro Motor
- Vorinstallierte Presets: Pulse, Eskalierend, Welle, Heartbeat, Zufall, Staccato
- Patterns werden im Browser (localStorage) gespeichert
- Server-seitiges Abspielen über REST API möglich

## Optionen

| Option | Beschreibung |
|---|---|
| `engine_ws_port` | WebSocket-Port (Standard: 12345) |
| `use_bluetooth_le` | Bluetooth LE aktivieren |
| `use_hid` | USB/HID aktivieren (Lovense-Dongle) |
| `use_serial` | Seriell aktivieren |
| `log_level` | Log-Stufe (error/warn/info/debug) |
| `mqtt_host` | MQTT Broker IP/Hostname |
| `mqtt_port` | MQTT Broker Port |
| `mqtt_user` | MQTT Benutzername |
| `mqtt_pass` | MQTT Passwort |
| `mqtt_topic_prefix` | MQTT Topic-Präfix (Standard: buttplug) |
| `ha_discovery` | HA MQTT Discovery aktivieren |
| `ha_discovery_prefix` | HA Discovery Präfix (Standard: homeassistant) |

## Persistenz

Einstellungen und intiface-engine-Daten werden unter `/data/home` gespeichert.
