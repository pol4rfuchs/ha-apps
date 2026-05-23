# Intiface Central für Home Assistant

Vollwertiges Buttplug/Intiface-Add-on mit WebGUI, MQTT-Bridge und HA-Entities.

## Features

- **Keine noVNC** – eigene Browser-WebGUI (kein X11, kein VNC-Overhead)
- **Echte Gerätekontrolle** direkt im Browser mit Vibrations-Slidern
- **Pattern Editor** – erstelle, speichere und spiele Vibrationsmuster
- **MQTT Bridge** – jedes Gerät/Motor als MQTT-Topic verfügbar
- **Home Assistant MQTT Discovery** – automatische Entities ohne YAML
- **Bluetooth LE + USB/HID** Passthrough über Host-Kernel
- **aarch64** (Raspberry Pi 4/5) via box64

## Architektur

```
Browser  ←──── WebGUI (/api/*, SSE) ────────────────────┐
                                                          │
HA Automation ←── MQTT ──→ mqtt-bridge ──→ Node.js ──→ intiface-engine :12345
                                                          │
Externe Clients (Spiele etc.) ──────────────────────────►┘
```

## Installation

1. Repository in HA hinzufügen: **Settings → Add-ons → Store → ⋮ → Repositories**
2. **Intiface Central** installieren
3. MQTT-Host konfigurieren (optional)
4. Starten → **Open Web UI**

## Hinweis zum Binary-Download

Das Add-on lädt `intiface-engine` von GitHub herunter. Falls der Build fehlschlägt:
1. Prüfe die aktuelle Release-URL unter https://github.com/intiface/intiface-engine/releases
2. Passe `ENGINE_VERSION` im Dockerfile an

## aarch64 / Raspberry Pi

Die x64-Binary von intiface-engine wird via [box64](https://github.com/ptitSeb/box64) emuliert.
Bluetooth und USB laufen direkt über den Host-Kernel, keine Performance-Probleme erwartet.

## Unterstützte Architekturen

| Arch | Support |
|------|---------|
| amd64 | ✅ nativ |
| aarch64 | ✅ via box64 |
