#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
DATA_DIR="/data/home"
mkdir -p "$DATA_DIR"

read_opt() {
  local key="$1"
  local default="$2"
  python3 - <<PY 2>/dev/null || echo "$default"
import json
try:
    d = json.load(open("${OPTIONS_FILE}"))
    v = d.get("${key}")
    if v is None or v == "":
        print(${default@Q})
    else:
        print(str(v).lower() if isinstance(v, bool) else v)
except:
    print(${default@Q})
PY
}

ENGINE_PORT="$(read_opt engine_ws_port 12345)"
USE_BLE="$(read_opt use_bluetooth_le true)"
USE_HID="$(read_opt use_hid true)"
USE_SERIAL="$(read_opt use_serial false)"
LOG_LEVEL="$(read_opt log_level info)"

# ── intiface-engine Argumente ─────────────────────────────────────────────────
ENGINE_ARGS=(
  --websocket-port "$ENGINE_PORT"
  --websocket-use-all-interfaces
)
[ "$USE_BLE"    = "true" ] && ENGINE_ARGS+=(--use-bluetooth-le)
[ "$USE_HID"    = "true" ] && ENGINE_ARGS+=(--use-hid)
[ "$USE_SERIAL" = "true" ] && ENGINE_ARGS+=(--use-serial-port)

# ── D-Bus Setup ───────────────────────────────────────────────────────────────
echo "INFO: D-Bus Socket: $(ls -la /run/dbus/system_bus_socket 2>/dev/null || echo 'FEHLT!')"
echo "INFO: BT Adapter: $(ls /sys/class/bluetooth/ 2>/dev/null || echo 'nicht sichtbar')"
echo "INFO: Engine Args: ${ENGINE_ARGS[*]}"

if [ -S /run/dbus/system_bus_socket ]; then
  export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
  echo "INFO: DBUS gesetzt: $DBUS_SYSTEM_BUS_ADDRESS"
fi

# ── Lovense BLE Auto-Trust ────────────────────────────────────────────────────
# Scannt kurz und trusted alle gefundenen LVS-* Geräte damit BlueZ
# stabile Verbindungen ohne Null-Byte-Pfade aufbauen kann.
bt_trust_lovense() {
  echo "INFO: Starte BLE-Scan für Lovense-Geräte (10s)..."
  if ! command -v bluetoothctl &>/dev/null; then
    echo "WARN: bluetoothctl nicht verfügbar – kein Auto-Trust"
    return
  fi

  # Scan starten, 10s warten, dann auswerten
  local found
  found=$(timeout 12s bluetoothctl --timeout 10 scan on 2>/dev/null || true)

  # Alle LVS-* MACs extrahieren und trusten
  echo "$found" | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | sort -u | while read -r mac; do
    local name
    name=$(bluetoothctl info "$mac" 2>/dev/null | grep "Name:" | awk '{print $2}' || true)
    if echo "$name" | grep -q "^LVS-"; then
      echo "INFO: Trusting Lovense $name ($mac)"
      bluetoothctl trust "$mac" 2>/dev/null || true
    fi
  done

  # Alternativ: direkt alle neuen Devices aus dem Scan-Output
  echo "$found" | grep -E 'NEW.*Device.*LVS-' | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | while read -r mac; do
    echo "INFO: Trusting LVS-Device $mac"
    bluetoothctl trust "$mac" 2>/dev/null || true
  done

  echo "INFO: Auto-Trust abgeschlossen"
}

# Nur ausführen wenn BLE aktiv
if [ "$USE_BLE" = "true" ]; then
  bt_trust_lovense &
  BT_TRUST_PID=$!
fi

# ── intiface-engine starten ───────────────────────────────────────────────────
echo "INFO: Starte intiface-engine v${ENGINE_VERSION:-?} auf Port $ENGINE_PORT..."
/usr/local/bin/intiface-engine "${ENGINE_ARGS[@]}" &
ENGINE_PID=$!

# ── Node.js WebGUI + MQTT Bridge ──────────────────────────────────────────────
sleep 1
echo "INFO: Starte Web-Server (Port 8199)..."
export OPTIONS_FILE
export WEB_PORT=8199
node /opt/intiface-addon/server.js &
NODE_PID=$!

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  echo "INFO: Shutdown..."
  kill "$NODE_PID" "$ENGINE_PID" 2>/dev/null || true
  wait "$NODE_PID" "$ENGINE_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "INFO: Alle Prozesse gestartet (engine PID=$ENGINE_PID, node PID=$NODE_PID)"
wait -n "$ENGINE_PID" "$NODE_PID"
echo "WARN: Ein Prozess ist beendet – Add-on wird neu gestartet"
