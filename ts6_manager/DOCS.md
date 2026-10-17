# TS6 Manager — Home Assistant Add-on

Web-based management interface für TeamSpeak 6 Server.  
Wraps [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) als Single-Image HA Add-on.

## Features

- Dashboard mit Live-Stats, Bandwidth-Graph, Channel-Tree
- Client-Verwaltung (kick, ban, move, poke)
- Permissions, Gruppen, Ban-List, Token-Verwaltung
- Music Bots (Radio, YouTube via yt-dlp, Local Library)
- Bot Flow Engine (visueller Node-Editor für Automations)
- Embeddable Server Widgets (SVG/PNG/JSON)
- Eigene Weboberfläche auf Port 8066 (kein Ingress), mit eigenem Login

## Voraussetzungen

- TeamSpeak 6 Server mit **WebQuery HTTP API** aktiviert
- WebQuery API-Key (via `apikeyadd` oder TS-Admin-Tools)
- Optional: SSH-Zugang zum TS-Server (für Bot Flow Event-Trigger)

## Installation

1. Repository zum Add-on Store hinzufügen:  
   **Einstellungen → Add-ons → Add-on Store → ⋮ → Repositories**  
   URL: `https://github.com/pol4rfuchs/ha-apps`

2. "TS6 Manager" installieren

3. Add-on starten

4. Weboberfläche öffnen (`http://<ha-host>:8066`, Button „Web-UI öffnen“) → `/setup` → Admin-Account anlegen

5. Unter **Settings → Connections** den TS6-Server eintragen  
   (Host, WebQuery-Port, API-Key)

## Persistente Daten (`/data`)

| Pfad | Inhalt |
|------|--------|
| `/data/ts6webui.db` | SQLite-Datenbank |
| `/data/secrets.env` | JWT_SECRET + ENCRYPTION_KEY (auto-generiert) |
| `/data/music/` | Heruntergeladene Musik (yt-dlp) |

Die Secrets werden beim ersten Start automatisch generiert.  
**Nicht löschen** — sonst werden alle gespeicherten Credentials ungültig.

## Architektur im Container

```
nginx :8066  (Host-Port, kein Ingress)
  ├── /          → React SPA (statisch aus /var/www/html)
  ├── /api/      → Node.js Backend :3001
  ├── /socket.io → WebSocket Backend :3001
  └── /widget/   → Public Widgets Backend :3001

s6-overlay Services:
  ts6-init    (oneshot) → Secrets generieren + Prisma migrate
  ts6-backend (longrun) → Node.js Express API
  ts6-nginx   (longrun) → nginx, startet nach ts6-backend
```

## Konfiguration

| Option | Standard | Beschreibung |
|--------|----------|--------------|
| `video_streaming` | `false` | Aktiviert den WebRTC-Medien-Sidecar zum Streamen von Video in TeamSpeak-Kanäle. Aus: der Sidecar läuft im Leerlauf und braucht kaum RAM/CPU. |
| `log_level` | `info` | Log-Level des Backends (trace/debug/info/notice/warning/error/fatal). Das Backend loggt über `console.*`, die Stufen werden dort gefiltert (`log`/`info` = info, `warn` = warning, `error` = error). nginx und der Video-Sidecar sind nicht betroffen. |

## Local and external access

**Local (LAN):** open `http://<ha-host>:8066`. There is no Ingress; the panel is protected by its own login only, not by Home Assistant authentication.

**External (internet):** recommendation **VPN or trusted access only** (a reverse proxy with TLS plus an access layer such as VPN or Cloudflare Access). Never expose the WebQuery port `10080`. The public server widgets under `/widget/` are intentionally unauthenticated status views; they are the only part meant to be public.
