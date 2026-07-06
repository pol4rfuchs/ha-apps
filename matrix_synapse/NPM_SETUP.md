# Nginx Proxy Manager — Setup Guide
# Nginx Proxy Manager — Einrichtungsanleitung

---

## Proxy Hosts Overview / Proxy Host Übersicht

| Domain | Port | Notes / Hinweise |
|--------|------|------------------|
| `matrix.deine-domain.duckdns.org` | 8008 | Synapse API + well-known |
| `element.deine-domain.duckdns.org` | 7080 | Element Web Client |
| `element-call.deine-domain.duckdns.org` | 7081 | Element Call (Voice/Video) |
| `livekit.deine-domain.duckdns.org` | 7880 | LiveKit SFU — **WebSocket required / WebSocket Pflicht!** |
| `livekit-jwt.deine-domain.duckdns.org` | 8089 | LiveKit JWT Token Bridge |
| `admin.deine-domain.duckdns.org` | 8090 | Ketesa (Admin UI) |

## Router Port Forwards (not via NPM / nicht über NPM)

| Port | Protocol | Target / Ziel | Purpose / Zweck |
|------|----------|---------------|-----------------|
| 3478 | **UDP** | Pi-IP | TURN Standard — Mobil + Heimnetz |
| 5349 | **TCP** | Pi-IP | TURN TLS Fallback — strict firewalls / strenge Firewalls |
| 30000-30020 | **UDP** | Pi-IP | TURN Relay Range — Media (Audio/Video) |

> EN: These ports go **directly** to the Pi — NPM cannot proxy UDP or raw WebRTC media traffic. Without the 30000-30020 relay range forwarded, calls will connect (signaling works) but carry no audio/video at all — even between two devices on the same LAN, since LiveKit always routes media through TURN by design. This range is deliberately kept small (21 ports) rather than LiveKit's 10,000-port default, since Home Assistant's add-on port schema requires each port to be listed individually — see the add-on's `config.yaml`.
> DE: Diese Ports gehen **direkt** zum Pi — NPM kann kein UDP und keinen rohen WebRTC-Medienverkehr proxyen. Ohne die weitergeleitete Relay-Range 30000-30020 verbindet sich der Call zwar (Signaling funktioniert), überträgt aber weder Ton noch Bild — auch zwischen zwei Geräten im selben LAN, da LiveKit Medien grundsätzlich über TURN routet. Die Range ist bewusst klein gehalten (21 Ports statt LiveKits 10.000-Port-Default), weil Home Assistants Add-on-Port-Schema jeden Port einzeln in der `config.yaml` auflisten muss.

---

## 1. Synapse API (matrix.*)

**Details Tab / Details-Tab:**
- Scheme: `http` | Forward Port: `8008`
- Cache Assets: OFF | Block Common Exploits: ON

**SSL Tab / SSL-Tab:**
- Let's Encrypt | Force SSL: ON | HTTP/2: ON

**Advanced → Custom Nginx Config:**
```nginx
location /.well-known/matrix/client {
    return 200 '{"m.homeserver":{"base_url":"https://matrix.deine-domain.duckdns.org"}}';
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
}
location /.well-known/matrix/server {
    return 200 '{"m.server":"matrix.deine-domain.duckdns.org:443"}';
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
}
```

---

## 2. Element Web (element.*)

EN: Standard HTTPS proxy — no custom config needed.
DE: Standard HTTPS Proxy — keine Custom Config nötig.

---

## 3. Element Call (element-call.*)

**Advanced → Custom Nginx Config:**
```nginx
add_header Access-Control-Allow-Origin * always;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
```

---

## 4. LiveKit SFU (livekit.*) — ⚠️ WebSocket required / WebSocket Pflicht

EN: Without WebSocket support enabled, signaling won't connect at all. Note that this is separate from the TURN/relay port forwards above — WebSocket gets you the signaling connection, the router forwards get you the actual audio/video.
DE: Ohne WebSocket-Support verbindet sich nicht mal die Signalisierung. Das ist unabhängig von den TURN/Relay-Portweiterleitungen oben — WebSocket sorgt für die Signalisierungsverbindung, die Router-Freigaben für Ton und Bild.

**Details Tab:** Websockets Support → **ON / AN**

**Advanced → Custom Nginx Config:**
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400;
proxy_send_timeout 86400;
```

---

## 5. lk-jwt-service (livekit-jwt.*) — Port 8089

**Advanced → Custom Nginx Config:**
```nginx
add_header Access-Control-Allow-Origin * always;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
if ($request_method = OPTIONS) {
    return 204;
}
```

---

## 6. Ketesa / Admin UI (admin.*) — Port 8090

**Access List:** must be set to **Publicly Accessible** — authentication comes from Matrix login itself, not NPM.

---

## Addon Config / Addon-Konfiguration

```yaml
server_name: "deine-domain.duckdns.org"
element_web_url: "https://element.deine-domain.duckdns.org"
enable_voice_calls: true
livekit_secret: ""
element_call_url: "https://element-call.deine-domain.duckdns.org"
livekit_url: "wss://livekit.deine-domain.duckdns.org"
livekit_jwt_url: "https://livekit-jwt.deine-domain.duckdns.org"
```

> EN: Leave `livekit_secret` empty — auto-generated on first start and stored in `/data/matrix/.livekit_secret`.
> DE: `livekit_secret` leer lassen — wird beim ersten Start automatisch generiert und in `/data/matrix/.livekit_secret` gespeichert.

---

## TLS Certificate for TURN 5349 / TLS-Zertifikat für TURN 5349

EN: LiveKit TURN TLS needs a certificate directly — not via NPM proxy. Copy after NPM has issued one:
DE: LiveKit TURN TLS braucht ein Zertifikat direkt — nicht über NPM Proxy. Nach NPM-Zertifikat-Ausstellung kopieren:

```bash
mkdir -p /data/matrix/tls
cp /ssl/livekit.deine-domain.duckdns.org/fullchain.pem /data/matrix/tls/livekit.crt
cp /ssl/livekit.deine-domain.duckdns.org/privkey.pem   /data/matrix/tls/livekit.key
# Addon neu starten / restart addon
```

> EN: TURN UDP 3478 + relay range 30000-30020 work without TLS and cover home + mobile networks.
> TCP 5349 (TLS) is only needed for colleagues behind very strict corporate firewalls.
> DE: TURN UDP 3478 + Relay-Range 30000-30020 funktionieren ohne TLS und decken Heimnetz + Mobilnetz ab.
> TCP 5349 (TLS) nur für Kollegen hinter sehr strikten Firmen-Firewalls nötig.
