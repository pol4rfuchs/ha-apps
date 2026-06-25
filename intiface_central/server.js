'use strict';

const express = require('express');
const { WebSocket } = require('ws');
const mqtt    = require('mqtt');
const http    = require('http');
const path    = require('path');
const fs      = require('fs');

// ─── Config laden ─────────────────────────────────────────────────────────────
const OPT_FILE = process.env.OPTIONS_FILE || '/data/options.json';
let opt = {};
try { opt = JSON.parse(fs.readFileSync(OPT_FILE, 'utf8')); }
catch (_) { console.log('options.json nicht vorhanden – nutze Defaults'); }

const ENGINE_PORT  = opt.engine_ws_port   || 12345;
const WEB_PORT     = parseInt(process.env.WEB_PORT || '8099', 10);
const MQTT_HOST    = opt.mqtt_host        || '';
const MQTT_PORT    = opt.mqtt_port        || 1883;
const MQTT_USER    = opt.mqtt_user        || '';
const MQTT_PASS    = opt.mqtt_pass        || '';
const TOPIC_PFX    = opt.mqtt_topic_prefix || 'buttplug';
const HA_DISC      = opt.ha_discovery     !== false;
const HA_PFX       = opt.ha_discovery_prefix || 'homeassistant';

// ─── App-State ────────────────────────────────────────────────────────────────
let engineWs    = null;
let engineReady = false;
let serverInfo  = null;
let devices     = {};
let msgId       = 1;
let scanning    = false;
let mqttClient  = null;
let mqttReady   = false;
let sseClients  = [];
const batteryTimers = {};
const keepaliveTimers = {};

const nextId = () => msgId++;

// ─── SSE broadcast ───────────────────────────────────────────────────────────
function broadcast(event, data) {
  const chunk = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  sseClients = sseClients.filter(r => !r.writableEnded);
  for (const r of sseClients) { try { r.write(chunk); } catch (_) {} }
}

// ─── Device model ─────────────────────────────────────────────────────────────
function parseDevice(raw) {
  const msgs = raw.DeviceMessages || {};
  // Log raw messages for debugging
  console.log(`[parseDevice] ${raw.DeviceName} msgs:`, JSON.stringify(Object.keys(msgs)));
  console.log(`[parseDevice] ${raw.DeviceName} full:`, JSON.stringify(msgs).slice(0, 500));

  let vibCount = 0, rotCount = 0;

  if (msgs.ScalarCmd?.Attributes) {
    for (const a of msgs.ScalarCmd.Attributes) {
      if (a.ActuatorType === 'Vibrate') vibCount++;
      else if (a.ActuatorType === 'Rotate') rotCount++;
    }
  }
  // v2 fallback
  vibCount = vibCount || msgs.VibrateCmd?.FeatureCount || 0;
  rotCount  = rotCount  || msgs.RotateCmd?.FeatureCount  || 0;

  // Battery: Buttplug v3 SensorReadCmd OR v2 BatteryLevelCmd
  // SensorReadCmd is an array directly (not {Attributes:[...]})
  const hasBattery = !!(
    (Array.isArray(msgs.SensorReadCmd) &&
     msgs.SensorReadCmd.some(a => a.SensorType === 'Battery')) ||
    msgs.BatteryLevelCmd !== undefined
  );

  const motorCount = Math.max(vibCount, 1);
  return {
    index:        raw.DeviceIndex,
    name:         raw.DeviceName,
    address:      raw.DeviceAddress || '',
    vibrateCount: motorCount,   // use motorCount so UI always shows ≥1
    rotateCount:  rotCount,
    linearCount:  msgs.LinearCmd?.FeatureCount || 0,
    motorStates:  new Array(motorCount).fill(0),
    msgVersion:   msgs.ScalarCmd ? 3 : 2,
    hasBattery,
    battery:      null,
    _rawMsgs:     Object.keys(msgs), // for /bp/debug
  };
}

// ─── Buttplug commands ────────────────────────────────────────────────────────
function bpSend(messages) {
  if (!engineWs || engineWs.readyState !== WebSocket.OPEN) return;
  engineWs.send(JSON.stringify(messages));
}

function cmdReadBattery(index) {
  const dev = devices[index];
  if (!dev) return;
  if (dev.msgVersion >= 3) {
    bpSend([{ SensorReadCmd: { Id: nextId(), DeviceIndex: index, SensorIndex: 0, SensorType: 'Battery' } }]);
  } else {
    bpSend([{ BatteryLevelCmd: { Id: nextId(), DeviceIndex: index } }]);
  }
}

function cmdReadBattery(index) {
  const dev = devices[index];
  if (!dev) return;
  if (dev.msgVersion >= 3) {
    bpSend([{ SensorReadCmd: { Id: nextId(), DeviceIndex: index, SensorIndex: 0, SensorType: 'Battery' } }]);
  } else {
    bpSend([{ BatteryLevelCmd: { Id: nextId(), DeviceIndex: index } }]);
  }
}

function cmdVibrate(index, speeds) {
  const dev = devices[index];
  if (!dev) return;
  speeds.forEach((s, i) => { if (i < dev.motorStates.length) dev.motorStates[i] = Math.max(0, Math.min(1, s)); });
  const id = nextId();
  if (dev.msgVersion >= 3) {
    bpSend([{ ScalarCmd: {
      Id: id, DeviceIndex: index,
      Scalars: speeds.map((Scalar, Index) => ({ Index, Scalar: Math.max(0, Math.min(1, Scalar)), ActuatorType: 'Vibrate' })),
    }}]);
  } else {
    bpSend([{ VibrateCmd: {
      Id: id, DeviceIndex: index,
      Speeds: speeds.map((Speed, Index) => ({ Index, Speed: Math.max(0, Math.min(1, Speed)) })),
    }}]);
  }
  if (mqttReady) {
    speeds.forEach((v, i) => {
      mqttClient.publish(`${TOPIC_PFX}/${index}/motor/${i}/state`, String(Math.max(0, Math.min(1, v))), { retain: true });
    });
  }
  broadcast('device_update', dev);
}

function cmdStop(index) {
  const dev = devices[index];
  if (dev) dev.motorStates.fill(0);
  bpSend([{ StopDeviceCmd: { Id: nextId(), DeviceIndex: index } }]);
  if (mqttReady && dev) {
    dev.motorStates.forEach((_, i) => mqttClient.publish(`${TOPIC_PFX}/${index}/motor/${i}/state`, '0', { retain: true }));
  }
  if (dev) broadcast('device_update', dev);
}

function cmdStopAll() {
  Object.values(devices).forEach(d => d.motorStates.fill(0));
  bpSend([{ StopAllDevices: { Id: nextId() } }]);
  Object.values(devices).forEach(d => {
    if (mqttReady) d.motorStates.forEach((_, i) => mqttClient.publish(`${TOPIC_PFX}/${d.index}/motor/${i}/state`, '0', { retain: true }));
    broadcast('device_update', d);
  });
}

function cmdScan(start) {
  scanning = start;
  broadcast('scanning', { scanning });
  bpSend([start ? { StartScanning: { Id: nextId() } } : { StopScanning: { Id: nextId() } }]);
}

// ─── Engine message handler ───────────────────────────────────────────────────
function handleEngine(messages) {
  for (const msg of messages) {
    const type = Object.keys(msg)[0];
    const data = msg[type];

    switch (type) {
      case 'ServerInfo':
        serverInfo  = data;
        engineReady = true;
        console.log(`[engine] verbunden: ${data.ServerName}`);
        broadcast('status', { connected: true, serverName: data.ServerName });
        bpSend([{ RequestDeviceList: { Id: nextId() } }]);
        break;

      case 'DeviceList':
        devices = {};
        for (const d of (data.Devices || [])) {
          devices[d.DeviceIndex] = parseDevice(d);
          onDeviceAdded(devices[d.DeviceIndex]);
        }
        broadcast('devices', Object.values(devices));
        break;

      case 'DeviceAdded':
        devices[data.DeviceIndex] = parseDevice(data);
        onDeviceAdded(devices[data.DeviceIndex]);
        broadcast('devices', Object.values(devices));
        break;

      case 'DeviceRemoved': {
        const dev = devices[data.DeviceIndex];
        if (dev) { onDeviceRemoved(dev); delete devices[data.DeviceIndex]; }
        broadcast('devices', Object.values(devices));
        break;
      }

      case 'SensorReading': {
        const dev = devices[data.DeviceIndex];
        if (dev && data.SensorType === 'Battery' && Array.isArray(data.Data) && data.Data.length > 0) {
          dev.battery = data.Data[0]; // 0-100
          console.log(`[battery] ${dev.name}: ${dev.battery}%`);
          if (mqttReady) mqttClient.publish(`${TOPIC_PFX}/${dev.index}/battery`, String(dev.battery), { retain: true });
          broadcast('device_update', dev);
        }
        break;
      }

      case 'BatteryLevelReading': {
        const dev = devices[data.DeviceIndex];
        if (dev) {
          dev.battery = Math.round(data.BatteryLevel * 100);
          console.log(`[battery v2] ${dev.name}: ${dev.battery}%`);
          if (mqttReady) mqttClient.publish(`${TOPIC_PFX}/${dev.index}/battery`, String(dev.battery), { retain: true });
          broadcast('device_update', dev);
        }
        break;
      }

      case 'SensorReading': {
        const dev = devices[data.DeviceIndex];
        if (dev && data.SensorType === 'Battery' && Array.isArray(data.Data) && data.Data.length > 0) {
          dev.battery = data.Data[0];
          console.log(`[battery] ${dev.name}: ${dev.battery}%`);
          broadcast('device_update', dev);
        }
        break;
      }

      case 'BatteryLevelReading': {
        const dev = devices[data.DeviceIndex];
        if (dev) {
          dev.battery = Math.round(data.BatteryLevel * 100);
          console.log(`[battery v2] ${dev.name}: ${dev.battery}%`);
          broadcast('device_update', dev);
        }
        break;
      }

      case 'ScanningFinished':
        scanning = false;
        broadcast('scanning', { scanning: false });
        break;

      case 'Error':
        console.error(`[engine] Fehler [${data.ErrorCode}]: ${data.ErrorMessage}`);
        break;
    }
  }
}

// ─── Engine WebSocket Verbindung ──────────────────────────────────────────────
let reconnectTimer = null;

function connectEngine() {
  if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
  console.log(`[engine] Verbinde ws://localhost:${ENGINE_PORT}…`);

  const ws = new WebSocket(`ws://localhost:${ENGINE_PORT}`);
  engineWs = ws;

  ws.on('open', () => {
    console.log('[engine] WS offen → Handshake');
    ws.send(JSON.stringify([{
      RequestServerInfo: { Id: nextId(), ClientName: 'HA Addon', MessageVersion: 3 }
    }]));
  });

  ws.on('message', raw => {
    try { handleEngine(JSON.parse(raw.toString())); }
    catch (e) { console.error('[engine] Parse-Fehler:', e.message); }
  });

  ws.on('close', code => {
    engineReady = false; serverInfo = null; devices = {}; scanning = false;
    Object.keys(batteryTimers).forEach(k => { clearInterval(batteryTimers[k]); delete batteryTimers[k]; });
    Object.keys(keepaliveTimers).forEach(k => { clearInterval(keepaliveTimers[k]); delete keepaliveTimers[k]; });
    Object.keys(batteryTimers).forEach(k => { clearInterval(batteryTimers[k]); delete batteryTimers[k]; });
    Object.keys(keepaliveTimers).forEach(k => { clearInterval(keepaliveTimers[k]); delete keepaliveTimers[k]; });
    broadcast('status', { connected: false });
    broadcast('devices', []);
    console.log(`[engine] WS geschlossen (${code}), reconnect in 3s`);
    reconnectTimer = setTimeout(connectEngine, 3000);
  });

  ws.on('error', err => console.error('[engine] WS Fehler:', err.message));
}

// ─── HA MQTT Discovery ────────────────────────────────────────────────────────
function devId(d) {
  return `bp_${d.index}_${d.name.replace(/\W+/g, '_').toLowerCase().slice(0, 24)}`;
}

function publishDiscovery(dev) {
  if (!mqttReady || !HA_DISC) return;
  const id  = devId(dev);
  const haD = {
    identifiers:  [`buttplug_${dev.index}`],
    name:         dev.name,
    manufacturer: 'Buttplug',
    model:        dev.name,
    via_device:   'intiface_ha',
  };
  const avail = { topic: `${TOPIC_PFX}/${dev.index}/availability` };

  for (let i = 0; i < dev.vibrateCount; i++) {
    const uid = `${id}_m${i}`;
    mqttClient.publish(`${HA_PFX}/number/${uid}/config`, JSON.stringify({
      name:          dev.vibrateCount > 1 ? `${dev.name} Motor ${i + 1}` : `${dev.name} Vibration`,
      unique_id:     uid,
      command_topic: `${TOPIC_PFX}/${dev.index}/motor/${i}/set`,
      state_topic:   `${TOPIC_PFX}/${dev.index}/motor/${i}/state`,
      min: 0, max: 1, step: 0.05, mode: 'slider',
      icon: 'mdi:vibrate',
      device: haD,
      availability: [avail],
    }), { retain: true });
  }

  if (dev.hasBattery) {
    mqttClient.publish(`${HA_PFX}/sensor/${id}_bat/config`, JSON.stringify({
      name:                `${dev.name} Batterie`,
      unique_id:           `${id}_bat`,
      state_topic:         `${TOPIC_PFX}/${dev.index}/battery`,
      unit_of_measurement: '%',
      device_class:        'battery',
      icon:                'mdi:battery',
      device:              haD,
      availability:        [avail],
    }), { retain: true });
  }

  mqttClient.publish(`${HA_PFX}/button/${id}_stop/config`, JSON.stringify({
    name:          `${dev.name} Stop`,
    unique_id:     `${id}_stop`,
    command_topic: `${TOPIC_PFX}/${dev.index}/stop`,
    payload_press: 'stop',
    icon: 'mdi:stop',
    device: haD,
    availability: [avail],
  }), { retain: true });

  mqttClient.publish(`${HA_PFX}/binary_sensor/${id}_conn/config`, JSON.stringify({
    name:         `${dev.name} Connected`,
    unique_id:    `${id}_conn`,
    state_topic:  `${TOPIC_PFX}/${dev.index}/availability`,
    payload_on:   'online',
    payload_off:  'offline',
    device_class: 'connectivity',
    icon: 'mdi:bluetooth-connect',
    device: haD,
  }), { retain: true });

  mqttClient.publish(`${TOPIC_PFX}/${dev.index}/availability`, 'online', { retain: true });
}

function removeDiscovery(dev) {
  if (!mqttReady) return;
  mqttClient.publish(`${TOPIC_PFX}/${dev.index}/availability`, 'offline', { retain: true });
}

function onDeviceAdded(dev) {
  console.log(`[device] +  [${dev.index}] ${dev.name} (${dev.vibrateCount}M, battery:${dev.hasBattery})`);
  publishDiscovery(dev);
  if (dev.hasBattery) {
    // Read battery immediately, then every 60s
    setTimeout(() => cmdReadBattery(dev.index), 1000);
    batteryTimers[dev.index] = setInterval(() => {
      if (devices[dev.index]) cmdReadBattery(dev.index);
    }, 60000);
  }
  startKeepalive(dev);
}

function onDeviceRemoved(dev) {
  console.log(`[device] -  [${dev.index}] ${dev.name}`);
  removeDiscovery(dev);
  if (batteryTimers[dev.index]) {
    clearInterval(batteryTimers[dev.index]);
    delete batteryTimers[dev.index];
  }
  if (keepaliveTimers[dev.index]) {
    clearInterval(keepaliveTimers[dev.index]);
    delete keepaliveTimers[dev.index];
  }
}

// ─── Keepalive ────────────────────────────────────────────────────────────────
// Lovense trennt die Verbindung nach ~60s Inaktivität.
// Alle 20s einen StopDeviceCmd senden um die Verbindung offen zu halten.
function startKeepalive(dev) {
  if (keepaliveTimers[dev.index]) return;
  keepaliveTimers[dev.index] = setInterval(() => {
    if (!devices[dev.index] || !engineReady) return;
    // Nur senden wenn alle Motoren auf 0 (Gerät inaktiv) – sonst nicht nötig
    const allStopped = dev.motorStates.every(v => v === 0);
    if (allStopped) {
      bpSend([{ StopDeviceCmd: { Id: nextId(), DeviceIndex: dev.index } }]);
    }
  }, 20000);
  console.log(`[keepalive] gestartet für ${dev.name}`);
}

// ─── MQTT Bridge ──────────────────────────────────────────────────────────────
function setupMqtt() {
  if (!MQTT_HOST) { console.log('[mqtt] Kein Host – Bridge deaktiviert'); return; }

  const opts = { reconnectPeriod: 5000, clientId: 'intiface_ha_' + Date.now() };
  if (MQTT_USER) { opts.username = MQTT_USER; opts.password = MQTT_PASS; }

  mqttClient = mqtt.connect(`mqtt://${MQTT_HOST}:${MQTT_PORT}`, opts);

  mqttClient.on('connect', () => {
    mqttReady = true;
    console.log(`[mqtt] verbunden ${MQTT_HOST}:${MQTT_PORT}`);
    broadcast('mqtt', { connected: true });
    mqttClient.subscribe([
      `${TOPIC_PFX}/scan/start`,
      `${TOPIC_PFX}/scan/stop`,
      `${TOPIC_PFX}/stop_all`,
      `${TOPIC_PFX}/+/stop`,
      `${TOPIC_PFX}/+/vibrate`,
      `${TOPIC_PFX}/+/motor/+/set`,
    ]);
    Object.values(devices).forEach(publishDiscovery);
  });

  mqttClient.on('offline', () => { mqttReady = false; broadcast('mqtt', { connected: false }); });
  mqttClient.on('error',   err => console.error('[mqtt] Fehler:', err.message));

  mqttClient.on('message', (topic, payload) => {
    const parts = topic.split('/');
    const str   = payload.toString().trim();

    if (topic === `${TOPIC_PFX}/scan/start`)  { cmdScan(true);  return; }
    if (topic === `${TOPIC_PFX}/scan/stop`)   { cmdScan(false); return; }
    if (topic === `${TOPIC_PFX}/stop_all`)    { cmdStopAll();   return; }

    const idx = parseInt(parts[1], 10);
    if (isNaN(idx)) return;

    if (parts[2] === 'stop') { cmdStop(idx); return; }

    if (parts[2] === 'vibrate') {
      try {
        const v = JSON.parse(str);
        cmdVibrate(idx, Array.isArray(v) ? v : [parseFloat(str)]);
      } catch (_) {
        const v = parseFloat(str);
        if (!isNaN(v)) cmdVibrate(idx, [v]);
      }
      return;
    }

    if (parts[2] === 'motor' && parts[4] === 'set') {
      const mi    = parseInt(parts[3], 10);
      const speed = parseFloat(str);
      const dev   = devices[idx];
      if (!dev || isNaN(mi) || isNaN(speed)) return;
      const speeds       = [...dev.motorStates];
      speeds[mi]         = Math.max(0, Math.min(1, speed));
      cmdVibrate(idx, speeds);
    }
  });
}

// ─── Express API ──────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());


const INDEX_HTML = "<!DOCTYPE html>\n<html lang=\"de\">\n<head>\n<meta charset=\"UTF-8\">\n<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n<title>Intiface \u00b7 HA</title>\n<style>\n:root{\n  --bg:#09090f;--surf:#12121c;--card:#181825;--bord:#272740;\n  --acc:#7c3aed;--acc2:#a855f7;--acc3:#c084fc;\n  --green:#22c55e;--red:#ef4444;--amber:#f59e0b;\n  --text:#e2e8f0;--muted:#64748b;\n}\n*{box-sizing:border-box;margin:0;padding:0}\nbody{background:var(--bg);color:var(--text);font:13px/1.4 'Segoe UI',system-ui,sans-serif;display:flex;flex-direction:column;height:100vh;overflow:hidden}\nheader{background:var(--surf);border-bottom:1px solid var(--bord);padding:8px 14px;display:flex;align-items:center;gap:10px;flex-shrink:0}\nheader h1{font-size:14px;font-weight:700;color:var(--acc3);flex:1}\n.badge{display:inline-flex;align-items:center;gap:5px;padding:3px 9px;border-radius:20px;font-size:11px;font-weight:600;background:var(--card);border:1px solid var(--bord)}\n.badge .dot{width:6px;height:6px;border-radius:50%;background:var(--muted)}\n.badge.on .dot{background:var(--green);box-shadow:0 0 5px var(--green)}\n.badge.off .dot{background:var(--red)}\n.tb{background:var(--surf);border-bottom:1px solid var(--bord);padding:6px 14px;display:flex;align-items:center;gap:6px;flex-wrap:wrap;flex-shrink:0}\nbutton{cursor:pointer;border:none;border-radius:6px;padding:5px 12px;font-size:12px;font-weight:500;transition:.15s}\n.bp{background:var(--acc);color:#fff}.bp:hover{background:var(--acc2)}\n.bs{background:var(--card);color:var(--text);border:1px solid var(--bord)}.bs:hover{background:var(--bord)}\n.bd{background:#450a0a;color:#fca5a5;border:1px solid var(--red)}.bd:hover{background:var(--red);color:#fff}\n.bsm{padding:3px 9px;font-size:11px}\nbutton:disabled{opacity:.35;cursor:default}\n.sw{display:none;align-items:center;gap:5px;font-size:11px;color:var(--amber)}.sw.vis{display:flex}\n@keyframes spin{to{transform:rotate(360deg)}}\n.sp2{width:11px;height:11px;border:2px solid var(--amber);border-top-color:transparent;border-radius:50%;animation:spin .7s linear infinite}\n.main{display:flex;flex:1;overflow:hidden}\n.devp{width:268px;min-width:190px;border-right:1px solid var(--bord);overflow-y:auto;padding:10px;flex-shrink:0}\n.ptitle{font-size:10px;text-transform:uppercase;letter-spacing:1px;color:var(--muted);font-weight:700;margin-bottom:8px}\n.nodev{text-align:center;padding:30px 12px;color:var(--muted);line-height:1.8}\n.nodev big{font-size:28px;display:block}\n.dcard{background:var(--card);border:1px solid var(--bord);border-radius:10px;padding:10px;margin-bottom:8px;transition:border-color .2s}\n.dcard:hover{border-color:var(--acc)}\n.dname{font-weight:600;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}\n.dsub{font-size:10px;color:var(--muted);margin-bottom:8px;margin-top:2px;display:flex;align-items:center;gap:6px}\n.bat{display:inline-flex;align-items:center;gap:3px;font-size:10px;padding:1px 5px;border-radius:4px;font-weight:600}\n.bat.high{color:#22c55e;background:#052e16}.bat.mid{color:#f59e0b;background:#1c1500}.bat.low{color:#ef4444;background:#1c0000;animation:pulse .8s infinite}\n@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}\n.mrow{display:flex;align-items:center;gap:6px;margin-bottom:5px}\n.ml{font-size:10px;color:var(--acc3);width:48px;flex-shrink:0}\ninput[type=range].msl{flex:1;-webkit-appearance:none;height:3px;border-radius:2px;background:var(--bord);outline:none;cursor:pointer}\ninput[type=range].msl::-webkit-slider-thumb{-webkit-appearance:none;width:12px;height:12px;border-radius:50%;background:var(--acc2);cursor:pointer}\ninput[type=range].msl::-moz-range-thumb{width:12px;height:12px;border-radius:50%;background:var(--acc2);border:none;cursor:pointer}\n.mv{font-size:10px;width:30px;text-align:right;font-variant-numeric:tabular-nums}\n.dfoot{display:flex;gap:5px;margin-top:8px}\n.seqp{flex:1;display:flex;flex-direction:column;overflow:hidden}\n.seqtb{padding:7px 12px;border-bottom:1px solid var(--bord);display:flex;align-items:center;gap:7px;flex-wrap:wrap;flex-shrink:0;background:var(--surf)}\nselect.sel,input.it{background:var(--card);border:1px solid var(--bord);color:var(--text);border-radius:6px;padding:4px 8px;font-size:12px;outline:none}\nselect.sel:focus,input.it:focus{border-color:var(--acc)}\ninput.inn{background:var(--card);border:1px solid var(--bord);color:var(--text);border-radius:5px;padding:3px 6px;font-size:12px;width:58px;outline:none}\ninput.inn:focus{border-color:var(--acc)}\n.div{width:1px;height:18px;background:var(--bord);margin:0 2px}\n.cwrap{flex:1;overflow:auto;padding:10px;display:flex;flex-direction:column;gap:6px}\n#cv{display:block;cursor:crosshair}\n.cinfo{font-size:11px;color:var(--muted);display:flex;gap:12px;flex-wrap:wrap;align-items:center}\n.cinfo .l{color:var(--acc3)}\n.prog{height:3px;background:var(--bord);flex-shrink:0}\n.progb{height:100%;background:var(--acc2);width:0%;transition:width .1s linear}\n.prebar{padding:7px 12px;border-top:1px solid var(--bord);display:flex;align-items:center;gap:5px;flex-wrap:wrap;flex-shrink:0;background:var(--surf)}\n.prbt{font-size:11px;padding:3px 9px;background:var(--card);border:1px solid var(--bord);color:var(--acc3);border-radius:20px;cursor:pointer;transition:.15s}\n.prbt:hover{background:var(--acc);color:#fff;border-color:var(--acc)}\n#tst{position:fixed;bottom:14px;right:14px;background:var(--card);border:1px solid var(--bord);border-radius:8px;padding:7px 14px;font-size:12px;opacity:0;transform:translateY(8px);transition:.25s;z-index:99;pointer-events:none}\n#tst.vis{opacity:1;transform:translateY(0)}\n#tst.ok{border-color:var(--green)}\n#tst.er{border-color:var(--red)}\n::-webkit-scrollbar{width:5px;height:5px}::-webkit-scrollbar-track{background:transparent}::-webkit-scrollbar-thumb{background:var(--bord);border-radius:3px}\n</style>\n</head>\n<body>\n\n<header>\n  <h1>\u26a1 Intiface \u00b7 Buttplug</h1>\n  <span class=\"badge\" id=\"be\"><span class=\"dot\"></span>Engine</span>\n  <span class=\"badge\" id=\"bm\"><span class=\"dot\"></span>MQTT</span>\n</header>\n\n<div class=\"tb\">\n  <button class=\"bp\"  id=\"bsc\"  onclick=\"scan(true)\"  disabled>\u25b6 Scan</button>\n  <button class=\"bs\"  id=\"bscs\" onclick=\"scan(false)\" disabled>\u25fc Stop Scan</button>\n  <button class=\"bd\"  id=\"bsa\"  onclick=\"stopAll()\"   disabled>\u23f9 Alle stoppen</button>\n  <div class=\"sw\" id=\"scw\"><div class=\"sp2\"></div>Scanne\u2026</div>\n  <div style=\"flex:1\"></div>\n  <button class=\"bs bsm\" onclick=\"exportPat()\">\u2b07 Export</button>\n  <button class=\"bs bsm\" onclick=\"document.getElementById('fi').click()\">\u2b06 Import</button>\n  <input id=\"fi\" type=\"file\" accept=\".json\" style=\"display:none\" onchange=\"importPat(event)\">\n</div>\n\n<div class=\"main\">\n  <div class=\"devp\">\n    <div class=\"ptitle\">Ger\u00e4te</div>\n    <div id=\"dl\"><div class=\"nodev\"><big>📡</big>Keine Ger\u00e4te.<br>Scan starten.</div></div>\n  </div>\n  <div class=\"seqp\">\n    <div class=\"seqtb\">\n      <input class=\"it\" id=\"pn\" placeholder=\"Pattern-Name\" style=\"width:120px\">\n      <select class=\"sel\" id=\"ps\" onchange=\"loadPat()\" style=\"min-width:140px\">\n        <option value=\"\">\u2014 Pattern \u2014</option>\n      </select>\n      <button class=\"bs bsm\" onclick=\"newPat()\">+ Neu</button>\n      <button class=\"bs bsm\" onclick=\"savePat()\">💾</button>\n      <button class=\"bd bsm\" onclick=\"delPat()\">🗑</button>\n      <div class=\"div\"></div>\n      <label style=\"font-size:11px;color:var(--muted)\">s</label>\n      <input class=\"inn\" id=\"cd\" type=\"number\" min=\"1\" max=\"600\" value=\"10\" onchange=\"cfgChange()\">\n      <label style=\"font-size:11px;color:var(--muted)\">BPM</label>\n      <input class=\"inn\" id=\"cb\" type=\"number\" min=\"20\" max=\"300\" value=\"60\" onchange=\"cfgChange()\">\n      <label style=\"font-size:11px;color:var(--muted)\">Raster</label>\n      <select class=\"sel\" id=\"cg\" onchange=\"cfgChange()\">\n        <option value=\"4\">1/4</option>\n        <option value=\"8\" selected>1/8</option>\n        <option value=\"16\">1/16</option>\n        <option value=\"32\">1/32</option>\n      </select>\n      <div style=\"flex:1\"></div>\n      <select class=\"sel\" id=\"pd\" onchange=\"devChange()\"><option value=\"\">\u2014 Ger\u00e4t \u2014</option></select>\n      <button class=\"bp\" id=\"bpl\" onclick=\"playSeq()\" disabled>\u25b6 Play</button>\n      <button class=\"bd bsm\" id=\"bsp\" onclick=\"stopSeq()\" style=\"display:none\">\u25fc Stop</button>\n      <button class=\"bs bsm\" id=\"blp\" onclick=\"toggleLoop()\" title=\"Loop\">🔁</button>\n    </div>\n    <div class=\"cwrap\" id=\"cw\">\n      <canvas id=\"cv\"></canvas>\n      <div class=\"cinfo\">\n        <span><span class=\"l\">Cursor:</span><span id=\"ct\">\u2014</span></span>\n        <span><span class=\"l\">Motor:</span><span id=\"cm\">1</span></span>\n        <span id=\"php\" style=\"display:none;color:var(--amber)\">\u25b6 <span id=\"pht\">0.0s</span></span>\n        <span style=\"margin-left:auto;font-size:10px;color:#374151\">LMB=Zeichnen \u00b7 RMB=L\u00f6schen \u00b7 Scroll=Zoom \u00b7 Shift+Drag=Pan</span>\n      </div>\n    </div>\n    <div class=\"prog\"><div class=\"progb\" id=\"pb\"></div></div>\n    <div class=\"prebar\">\n      <span style=\"font-size:10px;color:var(--muted);font-weight:700;text-transform:uppercase;letter-spacing:.5px;margin-right:4px\">Presets:</span>\n      <button class=\"prbt\" onclick=\"preset('pulse')\">💓 Pulse</button>\n      <button class=\"prbt\" onclick=\"preset('escalate')\">📈 Eskalierend</button>\n      <button class=\"prbt\" onclick=\"preset('wave')\">🌊 Welle</button>\n      <button class=\"prbt\" onclick=\"preset('heartbeat')\">\u2764\ufe0f Heartbeat</button>\n      <button class=\"prbt\" onclick=\"preset('zigzag')\">\u26a1 Zigzag</button>\n      <button class=\"prbt\" onclick=\"preset('staccato')\">🎵 Staccato</button>\n      <button class=\"prbt\" onclick=\"preset('breath')\">🫁 Atem</button>\n      <button class=\"prbt\" onclick=\"clearMot()\">🗑 Clear</button>\n      <button class=\"prbt\" onclick=\"addLane()\">\u2795 Motor</button>\n    </div>\n  </div>\n</div>\n\n<div id=\"tst\"></div>\n\n<script>\n'use strict';\n\nlet devs={}, engOk=false, looping=false, playing=false, aborted=false;\n\nconst cv=document.getElementById('cv');\nconst cx=cv.getContext('2d');\nconst COLS=['#a855f7','#22c55e','#f59e0b','#3b82f6','#ef4444','#ec4899','#06b6d4','#84cc16'];\n\nlet cfg={dur:10,bpm:60,grid:8};\nlet motors=[[]];\nlet curM=0;\nlet zoom=1, panX=0, ph=-1;\nlet drawing=false,erasing=false,panning=false,panSX=0,panSPX=0;\nlet pats={};\ntry{pats=JSON.parse(localStorage.getItem('bp_seq')||'{}')}catch(_){}\n\nconst nL=()=>Math.max(motors.length,1);\nconst lH=()=>Math.max(60,(cv.height-30)/nL());\nconst tX=t=>70+(t*zoom)-panX;\nconst xT=x=>((x-70)+panX)/zoom;\nconst vY=(v,y0)=>y0+lH()*.1+(1-v)*lH()*.8;\nconst yV=(y,y0)=>1-(y-y0-lH()*.1)/(lH()*.8);\nconst lyY=m=>30+m*lH();\nconst snapT=t=>{const s=(60/cfg.bpm)/(cfg.grid/4);return Math.round(t/s)*s;};\n\nfunction resize(){\n  const w=document.getElementById('cw');\n  cv.width=Math.max(400,w.clientWidth-24);\n  cv.height=Math.max(150,w.clientHeight-52);\n  fitZ();draw();\n}\nfunction fitZ(){const mz=(cv.width-72)/cfg.dur;if(zoom<mz)zoom=mz;}\n\nfunction draw(){\n  const W=cv.width,H=cv.height,_lh=lH(),_nl=nL();\n  cx.clearRect(0,0,W,H);\n  for(let m=0;m<_nl;m++){\n    const y0=lyY(m);\n    cx.fillStyle=m%2?'#0d0d17':'#12121c';cx.fillRect(70,y0,W-70,_lh);\n    if(m===curM){cx.fillStyle='rgba(124,58,237,.07)';cx.fillRect(70,y0,W-70,_lh);}\n    cx.strokeStyle='#2a2a40';cx.lineWidth=.5;cx.setLineDash([]);\n    for(const f of[.1,.5,.9]){cx.beginPath();cx.moveTo(70,y0+_lh*f);cx.lineTo(W,y0+_lh*f);cx.stroke();}\n  }\n  const bd=60/cfg.bpm,sd=bd/(cfg.grid/4);\n  for(let t=Math.floor(Math.max(0,xT(70))/sd)*sd;t<=cfg.dur+.001;t+=sd){\n    const x=tX(t);if(x<70||x>W)continue;\n    const iM=t%(bd*4)<sd*.1,iB=t%bd<sd*.1;\n    cx.strokeStyle=iM?'#4a4a70':iB?'#2f2f50':'#1e1e2e';\n    cx.lineWidth=iM?1.5:1;cx.setLineDash([]);\n    cx.beginPath();cx.moveTo(x,30);cx.lineTo(x,H);cx.stroke();\n    if(iB){cx.fillStyle='#4a5568';cx.font='9px monospace';cx.textAlign='center';cx.fillText(t.toFixed(1)+'s',x,20);}\n  }\n  cx.setLineDash([]);\n  const xe=tX(cfg.dur);\n  if(xe>=70&&xe<=W){cx.strokeStyle='#ef4444';cx.lineWidth=2;cx.beginPath();cx.moveTo(xe,30);cx.lineTo(xe,H);cx.stroke();}\n  for(let m=0;m<_nl;m++){\n    const y0=lyY(m),pts=(motors[m]||[]).slice().sort((a,b)=>a.t-b.t);\n    if(!pts.length)continue;\n    const col=COLS[m%COLS.length];\n    cx.beginPath();cx.moveTo(tX(pts[0].t),vY(0,y0));\n    for(const p of pts)cx.lineTo(tX(p.t),vY(p.v,y0));\n    cx.lineTo(tX(pts[pts.length-1].t),vY(0,y0));\n    cx.closePath();cx.fillStyle=col+'20';cx.fill();\n    cx.beginPath();cx.strokeStyle=col;cx.lineWidth=2;\n    pts.forEach((p,i)=>{const x=tX(p.t),y=vY(p.v,y0);i?cx.lineTo(x,y):cx.moveTo(x,y);});\n    cx.stroke();\n    pts.forEach(p=>{\n      const x=tX(p.t);if(x<70||x>W)return;\n      cx.beginPath();cx.arc(x,vY(p.v,y0),4,0,Math.PI*2);\n      cx.fillStyle=col;cx.fill();cx.strokeStyle='#fff4';cx.lineWidth=1;cx.stroke();\n    });\n  }\n  if(playing&&ph>=0){\n    const xp=tX(ph);cx.strokeStyle='#f59e0b';cx.lineWidth=2;cx.setLineDash([4,3]);\n    cx.beginPath();cx.moveTo(xp,30);cx.lineTo(xp,H);cx.stroke();cx.setLineDash([]);\n    cx.fillStyle='#f59e0b';cx.beginPath();cx.moveTo(xp-6,30);cx.lineTo(xp+6,30);cx.lineTo(xp,40);cx.closePath();cx.fill();\n    document.getElementById('pht').textContent=ph.toFixed(2)+'s';\n    document.getElementById('php').style.display='inline';\n  }else{document.getElementById('php').style.display='none';}\n  cx.fillStyle='#09090f';cx.fillRect(0,0,70,H);\n  cx.strokeStyle='#272740';cx.lineWidth=1;cx.setLineDash([]);\n  cx.beginPath();cx.moveTo(70,0);cx.lineTo(70,H);cx.stroke();\n  for(let m=0;m<_nl;m++){\n    const y0=lyY(m),col=COLS[m%COLS.length];\n    if(m===curM){cx.fillStyle=col+'22';cx.fillRect(0,y0,68,_lh);}\n    cx.strokeStyle=m===curM?col:'#272740';cx.lineWidth=1;cx.strokeRect(1,y0,66,_lh);\n    cx.fillStyle=m===curM?col:'#64748b';cx.font='bold 10px sans-serif';cx.textAlign='center';\n    cx.fillText('M'+(m+1),34,y0+_lh/2+4);\n  }\n  cx.fillStyle='#12121c';cx.fillRect(0,0,W,30);\n  cx.strokeStyle='#272740';cx.lineWidth=1;cx.beginPath();cx.moveTo(0,30);cx.lineTo(W,30);cx.stroke();\n}\n\nfunction cp(e){const r=cv.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};}\nfunction lAt(y){return Math.max(0,Math.min(nL()-1,Math.floor((y-30)/lH())));}\nfunction paint(x,y,erase){\n  if(x<70)return;\n  const t=Math.max(0,Math.min(cfg.dur,xT(x))),ts=snapT(t);\n  const m=lAt(y),y0=lyY(m),v=Math.max(0,Math.min(1,yV(y,y0)));\n  if(!motors[m])motors[m]=[];\n  if(erase){motors[m]=motors[m].filter(p=>Math.abs(tX(p.t)-x)>7);}\n  else{const ni=motors[m].findIndex(p=>Math.abs(tX(p.t)-x)<=6);ni>=0?motors[m][ni].v=v:motors[m].push({t:ts,v});}\n  draw();\n}\ncv.addEventListener('mousedown',e=>{\n  const{x,y}=cp(e);\n  if(e.shiftKey||e.button===1){panning=true;panSX=e.clientX;panSPX=panX;cv.style.cursor='grabbing';return;}\n  if(x<70){curM=lAt(y);document.getElementById('cm').textContent=curM+1;draw();return;}\n  e.button===2?(erasing=true,paint(x,y,true)):(drawing=true,paint(x,y,false));\n});\ncv.addEventListener('mousemove',e=>{\n  const{x,y}=cp(e);\n  if(panning){panX=Math.max(0,panSPX-(e.clientX-panSX));draw();return;}\n  if(drawing)paint(x,y,false);\n  if(erasing)paint(x,y,true);\n  if(x>=70)document.getElementById('ct').textContent=Math.max(0,xT(x)).toFixed(2)+'s';\n});\ncv.addEventListener('mouseup',  ()=>{drawing=erasing=panning=false;cv.style.cursor='crosshair';});\ncv.addEventListener('mouseleave',()=>{drawing=erasing=panning=false;cv.style.cursor='crosshair';});\ncv.addEventListener('contextmenu',e=>e.preventDefault());\ncv.addEventListener('wheel',e=>{\n  e.preventDefault();\n  const{x}=cp(e),tC=xT(x);\n  if(!e.shiftKey){\n    zoom=Math.max((cv.width-72)/cfg.dur,zoom*(e.deltaY<0?1.15:1/1.15));\n    panX=Math.max(0,tC*zoom-(x-70));\n  }else{panX=Math.max(0,panX+e.deltaY*2);}\n  draw();\n},{passive:false});\n\nfunction cfgChange(){\n  cfg.dur=parseFloat(document.getElementById('cd').value)||10;\n  cfg.bpm=parseFloat(document.getElementById('cb').value)||60;\n  cfg.grid=parseInt(document.getElementById('cg').value)||8;\n  fitZ();draw();\n}\nfunction clearMot(){motors=motors.map(()=>[]);draw();}\nfunction addLane(){\n  const d=devs[parseInt(document.getElementById('pd').value,10)];\n  if(d&&motors.length>=d.vibrateCount){toast('Ger\u00e4t hat nur '+d.vibrateCount+' Motor(en)','er');return;}\n  motors.push([]);draw();\n}\n\nconst PR={\n  pulse:     d=>step(d,[0,0,.01,.8,.44,.8,.45,0,.99,0,1,0]),\n  escalate:  d=>rng(40,i=>({t:(i/39)*d,v:i/39})),\n  wave:      d=>rng(80,i=>({t:(i/79)*d,v:.5+.5*Math.sin(2*Math.PI*i/79*2)})),\n  heartbeat: d=>step(d,[0,0,.01,.9,.09,.4,.1,.9,.18,0,.99,0,1,0]),\n  zigzag:    d=>{const n=10,r=[];for(let i=0;i<n;i++){const t=(i/n)*d,v=i%2?1:0;if(i>0)r.push({t:t-0.002,v:1-v});r.push({t,v});}r.push({t:d,v:r[r.length-1].v});return r;},\n  staccato:  d=>{const n=16,r=[];for(let i=0;i<n;i++){const t=(i/n)*d,on=i%2===0,v=on?(.55+Math.random()*.45):0;if(i>0)r.push({t:t-0.002,v:on?0:1});r.push({t,v});}r.push({t:d,v:0});return r;},\n  breath:    d=>rng(80,i=>({t:(i/79)*d,v:.5+.5*Math.sin(2*Math.PI*i/79*.5)})),\n};\nfunction rng(n,f){return Array.from({length:n},(_,i)=>f(i));}\nfunction pf(d,flat){const r=[];for(let i=0;i<flat.length;i+=2)r.push({t:flat[i]*d,v:flat[i+1]});return r;}\nfunction step(d,flat){const r=[];for(let i=0;i<flat.length;i+=2){const t=flat[i]*d,v=flat[i+1];if(i>0)r.push({t:t-0.002,v:flat[i-1]});r.push({t,v});}return r;}\nfunction preset(n){if(!PR[n])return;motors[curM]=PR[n](cfg.dur);draw();toast('Preset \"'+n+'\"','ok');}\n\nfunction toSteps(N=60){\n  const sd=cfg.dur/N;\n  return Array.from({length:N},(_,i)=>{\n    const t=(i+.5)*sd;\n    return{\n      duration:Math.round(sd*1000),\n      speeds:motors.map(pts=>{\n        const s=(pts||[]).slice().sort((a,b)=>a.t-b.t);\n        if(!s.length)return 0;\n        if(t<=s[0].t)return s[0].v;\n        if(t>=s[s.length-1].t)return s[s.length-1].v;\n        for(let j=0;j<s.length-1;j++){\n          if(t>=s[j].t&&t<=s[j+1].t){const f=(t-s[j].t)/(s[j+1].t-s[j].t);return s[j].v+f*(s[j+1].v-s[j].v);}\n        }\n        return 0;\n      }),\n    };\n  });\n}\n\nasync function playSeq(){\n  const idx=parseInt(document.getElementById('pd').value,10);\n  if(isNaN(idx)||!devs[idx]){toast('Kein Ger\u00e4t','er');return;}\n  const steps=toSteps(Math.max(20,Math.ceil(cfg.dur*20)));\n  if(!steps.length){toast('Pattern leer','er');return;}\n  playing=true;aborted=false;\n  document.getElementById('bpl').style.display='none';\n  document.getElementById('bsp').style.display='inline-block';\n  const total=steps.reduce((s,st)=>s+st.duration,0);\n  do{\n    ph=0;let el=0;\n    for(let si=0;si<steps.length;si++){\n      if(aborted)break;\n      await fetch(`/bp/devices/${idx}/vibrate`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({speeds:steps[si].speeds})}).catch(()=>{});\n      const t0=Date.now();\n      while(Date.now()-t0<steps[si].duration){\n        if(aborted)break;\n        el=steps.slice(0,si).reduce((s,st)=>s+st.duration,0)+(Date.now()-t0);\n        ph=el/1000;\n        document.getElementById('pb').style.width=Math.min(100,el/total*100)+'%';\n        draw();await slp(16);\n      }\n    }\n  }while(looping&&!aborted);\n  ph=-1;playing=false;\n  document.getElementById('pb').style.width='0%';draw();\n  if(!aborted)await fetch(`/bp/devices/${idx}/stop`,{method:'POST'}).catch(()=>{});\n  document.getElementById('bpl').style.display='inline-block';\n  document.getElementById('bsp').style.display='none';\n}\nfunction stopSeq(){\n  aborted=true;\n  const i=parseInt(document.getElementById('pd').value,10);\n  if(!isNaN(i))fetch(`/bp/devices/${i}/stop`,{method:'POST'}).catch(()=>{});\n}\nfunction toggleLoop(){\n  looping=!looping;\n  const b=document.getElementById('blp');b.style.background=looping?'var(--acc)':'';b.style.color=looping?'#fff':'';\n  toast(looping?'Loop AN':'Loop AUS','ok');\n}\n\nfunction savePat(){\n  const n=document.getElementById('pn').value.trim();if(!n){toast('Name fehlt','er');return;}\n  pats[n]={cfg:{...cfg},motors:motors.map(m=>[...m])};\n  localStorage.setItem('bp_seq',JSON.stringify(pats));updPS();\n  document.getElementById('ps').value=n;toast('\"'+n+'\" gespeichert','ok');\n}\nfunction loadPat(){\n  const n=document.getElementById('ps').value;if(!n||!pats[n]){newPat();return;}\n  const p=pats[n];cfg={...p.cfg};motors=p.motors.map(m=>[...m]);\n  document.getElementById('pn').value=n;\n  document.getElementById('cd').value=cfg.dur;\n  document.getElementById('cb').value=cfg.bpm;\n  document.getElementById('cg').value=cfg.grid;\n  fitZ();draw();\n}\nfunction delPat(){\n  const n=document.getElementById('ps').value;if(!n)return;\n  delete pats[n];localStorage.setItem('bp_seq',JSON.stringify(pats));updPS();newPat();toast('\"'+n+'\" gel\u00f6scht','ok');\n}\nfunction newPat(){\n  motors=[[]];cfg={dur:10,bpm:60,grid:8};\n  document.getElementById('pn').value='';document.getElementById('ps').value='';\n  document.getElementById('cd').value=cfg.dur;document.getElementById('cb').value=cfg.bpm;document.getElementById('cg').value=cfg.grid;\n  fitZ();draw();\n}\nfunction updPS(){\n  const sel=document.getElementById('ps'),cur=sel.value,keys=Object.keys(pats);\n  sel.innerHTML='<option value=\"\">\u2014 Pattern \u2014</option>';\n  keys.forEach(k=>{const o=document.createElement('option');o.value=k;o.textContent=k;sel.appendChild(o);});\n  if(keys.includes(cur))sel.value=cur;\n}\nfunction exportPat(){\n  const n=document.getElementById('pn').value.trim()||'pattern';\n  const a=document.createElement('a');\n  a.href=URL.createObjectURL(new Blob([JSON.stringify({name:n,cfg,motors,steps:toSteps(100)},null,2)],{type:'application/json'}));\n  a.download=n+'.json';a.click();\n}\nfunction importPat(e){\n  const f=e.target.files[0];if(!f)return;\n  const r=new FileReader();\n  r.onload=ev=>{\n    try{\n      const d=JSON.parse(ev.target.result);\n      if(d.cfg)cfg={...d.cfg};\n      motors=d.motors?d.motors.map(m=>[...m]):[[ ...(d.steps||[]).map((s,i)=>({t:i*(cfg.dur||10)/(d.steps.length||1),v:Array.isArray(s.speeds)?s.speeds[0]:(s.speed||0)}))]];\n      document.getElementById('pn').value=d.name||'';\n      document.getElementById('cd').value=cfg.dur;document.getElementById('cb').value=cfg.bpm;document.getElementById('cg').value=cfg.grid;\n      fitZ();draw();toast('Import OK','ok');\n    }catch(_){toast('Import fehlgeschlagen','er');}\n  };r.readAsText(f);e.target.value='';\n}\n\n// \u2500\u2500\u2500 Battery helper \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\nfunction batHtml(d){\n  if(!d.hasBattery)return '';\n  if(d.battery===null)return '<span class=\"bat mid\">🔋 \u2026</span>';\n  const v=d.battery;\n  const cls=v>=50?'high':v>=20?'mid':'low';\n  const icon=v>=80?'🔋':v>=20?'🪫':'🪫';\n  return `<span class=\"bat ${cls}\" id=\"bat-${d.index}\">${icon} ${v}%</span>`;\n}\n\nfunction renderDevs(){\n  const el=document.getElementById('dl'),list=Object.values(devs);\n  if(!list.length){el.innerHTML='<div class=\"nodev\"><big>📡</big>Keine Ger\u00e4te.<br>Scan starten.</div>';return;}\n  el.innerHTML=list.map(d=>`<div class=\"dcard\" id=\"dc-${d.index}\">\n    <div class=\"dname\">${esc(d.name)}</div>\n    <div class=\"dsub\"><span>${esc(d.address||'idx:'+d.index)} \u00b7 ${d.vibrateCount}M</span>${batHtml(d)}</div>\n    ${d.motorStates.map((v,i)=>`<div class=\"mrow\">\n      <span class=\"ml\">Motor ${i+1}</span>\n      <input type=\"range\" class=\"msl\" id=\"sl-${d.index}-${i}\" min=\"0\" max=\"1\" step=\"0.05\" value=\"${v}\">\n      <span class=\"mv\" id=\"mv-${d.index}-${i}\">${Math.round(v*100)}%</span>\n    </div>`).join('')}\n    <div class=\"dfoot\">\n      <button class=\"bd bsm\" onclick=\"fetch('/bp/devices/${d.index}/stop',{method:'POST'})\">\u23f9</button>\n      <button class=\"bs bsm\" onclick=\"selD(${d.index})\">📝 Sequencer</button>\n    </div>\n  </div>`).join('');\n  list.forEach(d=>d.motorStates.forEach((_,i)=>{\n    const sl=document.getElementById(`sl-${d.index}-${i}`);if(!sl)return;\n    sl.addEventListener('input',()=>{document.getElementById(`mv-${d.index}-${i}`).textContent=Math.round(sl.value*100)+'%';d.motorStates[i]=+sl.value;});\n    sl.addEventListener('change',()=>{clearTimeout(sl._t);sl._t=setTimeout(()=>vib(d.index,d.motorStates),50);});\n  }));\n  updPD();\n}\nfunction selD(i){document.getElementById('pd').value=i;devChange();}\nfunction updPD(){\n  const sel=document.getElementById('pd'),cur=sel.value;\n  sel.innerHTML='<option value=\"\">\u2014 Ger\u00e4t \u2014</option>';\n  Object.values(devs).forEach(d=>{const o=document.createElement('option');o.value=d.index;o.textContent=d.name;sel.appendChild(o);});\n  if(cur)sel.value=cur;devChange();\n}\nfunction devChange(){\n  const i=parseInt(document.getElementById('pd').value,10);\n  document.getElementById('bpl').disabled=isNaN(i)||!devs[i];\n}\nfunction vib(idx,speeds){\n  fetch(`/bp/devices/${idx}/vibrate`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({speeds})}).catch(()=>{});\n}\nfunction scan(s){fetch(`/bp/scan/${s?'start':'stop'}`,{method:'POST'}).catch(()=>{});}\nfunction stopAll(){fetch('/bp/stop_all',{method:'POST'}).catch(()=>{});}\n\nfunction sse(){\n  const es=new EventSource('/bp/events');\n  es.addEventListener('status',e=>{\n    const d=JSON.parse(e.data);engOk=d.connected;\n    document.getElementById('be').className='badge '+(d.connected?'on':'off');\n    ['bsc','bscs','bsa'].forEach(id=>document.getElementById(id).disabled=!d.connected);\n  });\n  es.addEventListener('mqtt',e=>{document.getElementById('bm').className='badge '+(JSON.parse(e.data).connected?'on':'off');});\n  es.addEventListener('devices',e=>{devs={};JSON.parse(e.data).forEach(d=>{devs[d.index]=d;});renderDevs();});\n  es.addEventListener('device_update',e=>{\n    const d=JSON.parse(e.data);devs[d.index]=d;\n    // Update motor sliders\n    d.motorStates.forEach((v,i)=>{\n      const s=document.getElementById(`sl-${d.index}-${i}`),m=document.getElementById(`mv-${d.index}-${i}`);\n      if(s)s.value=v;if(m)m.textContent=Math.round(v*100)+'%';\n    });\n    // Update battery\n    if(d.hasBattery){\n      const bc=document.getElementById(`bat-${d.index}`);\n      if(bc){\n        const v=d.battery;\n        if(v!==null){\n          const cls=v>=50?'high':v>=20?'mid':'low';\n          const icon=v>=80?'🔋':v>=20?'🪫':'🪫';\n          bc.className=`bat ${cls}`;\n          bc.textContent=`${icon} ${v}%`;\n        }\n      } else {\n        // card not rendered yet with battery \u2013 re-render\n        const dc=document.getElementById(`dc-${d.index}`);\n        if(dc){const sub=dc.querySelector('.dsub');if(sub)sub.innerHTML=`<span>${esc(d.address||'idx:'+d.index)} \u00b7 ${d.vibrateCount}M</span>${batHtml(d)}`;}\n      }\n    }\n  });\n  es.addEventListener('scanning',e=>{document.getElementById('scw').className='sw'+(JSON.parse(e.data).scanning?' vis':'');});\n  es.onerror=()=>{document.getElementById('be').className='badge off';setTimeout(sse,3000);es.close();};\n}\n\nconst slp=ms=>new Promise(r=>setTimeout(r,ms));\nconst esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');\nlet tt;\nfunction toast(m,t='ok'){const e=document.getElementById('tst');e.textContent=m;e.className='vis '+t;clearTimeout(tt);tt=setTimeout(()=>e.className='',2500);}\n\nwindow.addEventListener('resize',resize);\nresize();sse();updPS();\n</script>\n</body>\n</html>";

app.get('/', (_, res) => res.type('html').send(INDEX_HTML));

// SSE
app.get('/bp/events', (req, res) => {
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', 'X-Accel-Buffering': 'no' });
  res.flushHeaders();
  res.write(`event: status\ndata: ${JSON.stringify({ connected: engineReady })}\n\n`);
  res.write(`event: mqtt\ndata: ${JSON.stringify({ connected: mqttReady })}\n\n`);
  res.write(`event: devices\ndata: ${JSON.stringify(Object.values(devices))}\n\n`);
  res.write(`event: scanning\ndata: ${JSON.stringify({ scanning })}\n\n`);
  const hb = setInterval(() => { try { res.write(': hb\n\n'); } catch (_) {} }, 20000);
  sseClients.push(res);
  req.on('close', () => { clearInterval(hb); sseClients = sseClients.filter(c => c !== res); });
});

app.get('/bp/status', (_, res) => res.json({
  engineReady, serverInfo, mqttReady, scanning,
  deviceCount: Object.keys(devices).length,
  enginePort: ENGINE_PORT,
}));

app.get('/bp/devices', (_, res) => res.json(Object.values(devices)));

app.get('/bp/debug', (_, res) => res.json(
  Object.values(devices).map(d => ({ index: d.index, name: d.name, hasBattery: d.hasBattery, msgVersion: d.msgVersion, rawMsgs: d._rawMsgs }))
));

app.post('/bp/scan/start', (_, res) => {
  if (!engineReady) return res.status(503).json({ error: 'Engine nicht verbunden' });
  cmdScan(true);
  res.json({ ok: true });
});

app.post('/bp/scan/stop', (_, res) => {
  if (!engineReady) return res.status(503).json({ error: 'Engine nicht verbunden' });
  cmdScan(false);
  res.json({ ok: true });
});

app.post('/bp/devices/:idx/battery', (req, res) => {
  const idx = parseInt(req.params.idx, 10);
  if (!devices[idx]) return res.status(404).json({ error: 'Gerät nicht gefunden' });
  if (!devices[idx].hasBattery) return res.status(400).json({ error: 'Kein Batteriesensor' });
  cmdReadBattery(idx);
  res.json({ ok: true, battery: devices[idx].battery });
});

app.post('/bp/devices/:idx/vibrate', (req, res) => {
  const idx = parseInt(req.params.idx, 10);
  if (!devices[idx])        return res.status(404).json({ error: 'Gerät nicht gefunden' });
  if (!Array.isArray(req.body.speeds)) return res.status(400).json({ error: 'speeds[] fehlt' });
  cmdVibrate(idx, req.body.speeds);
  res.json({ ok: true });
});

app.post('/bp/devices/:idx/stop', (req, res) => {
  const idx = parseInt(req.params.idx, 10);
  if (!devices[idx]) return res.status(404).json({ error: 'Gerät nicht gefunden' });
  cmdStop(idx);
  res.json({ ok: true });
});

app.post('/bp/stop_all', (_, res) => {
  if (!engineReady) return res.status(503).json({ error: 'Engine nicht verbunden' });
  cmdStopAll();
  res.json({ ok: true });
});

app.post('/bp/devices/:idx/pattern', async (req, res) => {
  const idx   = parseInt(req.params.idx, 10);
  const steps = req.body.steps;
  const MAX_PATTERN_STEPS = 100;
  const MIN_STEP_DURATION_MS = 50;
  const MAX_STEP_DURATION_MS = 10000;

  if (!devices[idx])         return res.status(404).json({ error: 'Gerät nicht gefunden' });
  if (!Array.isArray(steps)) return res.status(400).json({ error: 'steps[] fehlt' });
  if (steps.length > MAX_PATTERN_STEPS) {
    return res.status(400).json({ error: `Zu viele steps (max ${MAX_PATTERN_STEPS})` });
  }

  const safeSteps = [];
  for (const rawStep of steps) {
    const duration = Number(rawStep && rawStep.duration != null ? rawStep.duration : 500);
    if (!Number.isFinite(duration) || duration < MIN_STEP_DURATION_MS || duration > MAX_STEP_DURATION_MS) {
      return res.status(400).json({
        error: `Ungültige step.duration (erlaubt ${MIN_STEP_DURATION_MS}-${MAX_STEP_DURATION_MS} ms)`
      });
    }

    safeSteps.push({
      duration,
      speeds: Array.isArray(rawStep && rawStep.speeds)
        ? rawStep.speeds
        : [rawStep && rawStep.speed != null ? rawStep.speed : 0]
    });
  }

  res.json({ ok: true, steps: safeSteps.length });
  (async () => {
    for (const step of safeSteps) {
      if (!engineReady || !devices[idx]) break;
      cmdVibrate(idx, step.speeds);
      await new Promise(r => setTimeout(r, step.duration));
    }
    if (devices[idx]) cmdStop(idx);
  })();
});

// ─── Server starten ───────────────────────────────────────────────────────────
const server = http.createServer(app);
server.listen(WEB_PORT, '0.0.0.0', () => {
  console.log(`[web] UI auf Port ${WEB_PORT}`);
  setTimeout(connectEngine, 2500);
  setupMqtt();
});

process.on('SIGTERM', () => { server.close(); process.exit(0); });
process.on('SIGINT',  () => { server.close(); process.exit(0); });
