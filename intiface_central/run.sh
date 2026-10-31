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

# ── intiface-engine arguments ─────────────────────────────────────────────────
# --log accepts error|warn|info|debug|trace (intiface-engine --help)
case "$LOG_LEVEL" in
  error|warn|info|debug|trace) ;;
  *) echo "WARN: Unknown log_level '$LOG_LEVEL' - using info"; LOG_LEVEL=info ;;
esac

ENGINE_ARGS=(
  --websocket-port "$ENGINE_PORT"
  --websocket-use-all-interfaces
  --log "$LOG_LEVEL"
)
[ "$USE_BLE"    = "true" ] && ENGINE_ARGS+=(--use-bluetooth-le)
[ "$USE_HID"    = "true" ] && ENGINE_ARGS+=(--use-hid)
[ "$USE_SERIAL" = "true" ] && ENGINE_ARGS+=(--use-serial)

# ── D-Bus setup ───────────────────────────────────────────────────────────────
echo "INFO: D-Bus Socket: $(ls -la /run/dbus/system_bus_socket 2>/dev/null || echo 'MISSING!')"
echo "INFO: BT Adapter: $(ls /sys/class/bluetooth/ 2>/dev/null || echo 'not visible')"
echo "INFO: Engine Args: ${ENGINE_ARGS[*]}"

if [ -S /run/dbus/system_bus_socket ]; then
  export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
  echo "INFO: DBUS set: $DBUS_SYSTEM_BUS_ADDRESS"
fi

# ── Lovense BLE Auto-Trust ────────────────────────────────────────────────────
# Scans briefly and trusts all LVS-* devices found so BlueZ can
# establish stable connections without null-byte paths.
bt_trust_lovense() {
  echo "INFO: Starting BLE scan for Lovense devices (10s)..."
  if ! command -v bluetoothctl &>/dev/null; then
    echo "WARN: bluetoothctl not available – no auto-trust"
    return
  fi

  # Start the scan, wait 10s, then evaluate
  local found
  found=$(timeout 12s bluetoothctl --timeout 10 scan on 2>/dev/null || true)

  # Extract and trust all LVS-* MACs
  echo "$found" | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | sort -u | while read -r mac; do
    local name
    name=$(bluetoothctl info "$mac" 2>/dev/null | grep "Name:" | awk '{print $2}' || true)
    if echo "$name" | grep -q "^LVS-"; then
      echo "INFO: Trusting Lovense $name ($mac)"
      bluetoothctl trust "$mac" 2>/dev/null || true
    fi
  done

  # Alternatively: take all new devices straight from the scan output
  echo "$found" | grep -E 'NEW.*Device.*LVS-' | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | while read -r mac; do
    echo "INFO: Trusting LVS-Device $mac"
    bluetoothctl trust "$mac" 2>/dev/null || true
  done

  echo "INFO: Auto-trust finished"
}

# Only run if BLE is enabled
if [ "$USE_BLE" = "true" ]; then
  bt_trust_lovense &
fi

# ── Start intiface-engine ───────────────────────────────────────────────────
ENGINE_VERSION="$(/usr/local/bin/intiface-engine --version 2>/dev/null | head -1 || true)"
echo "INFO: Starting intiface-engine ${ENGINE_VERSION:-?} on port $ENGINE_PORT (log: $LOG_LEVEL)..."
/usr/local/bin/intiface-engine "${ENGINE_ARGS[@]}" &
ENGINE_PID=$!

# ── Node.js web GUI + MQTT bridge ──────────────────────────────────────────────
sleep 1
echo "INFO: Starting web server (port 8199)..."
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

echo "INFO: All processes started (engine PID=$ENGINE_PID, node PID=$NODE_PID)"
wait -n "$ENGINE_PID" "$NODE_PID"
echo "WARN: A process has exited – the add-on will be restarted"
