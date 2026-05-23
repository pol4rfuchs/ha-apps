# 🔷 Matrix Server Addon für Home Assistant
### Synapse + Element Web + Synapse Admin (etkecc) + PostgreSQL

> **Optimiert für:** Raspberry Pi 4 (aarch64) & amd64 | HA OS 17+ | nginx Proxy Manager

---

## 📦 Was ist drin?

| Komponente | Version | Zweck |
|---|---|---|
| **Synapse** | 1.148.0 (pip) | Matrix Homeserver |
| **PostgreSQL 15** | Debian pkg | Datenbank |
| **Element Web** | v1.12.11 | Web-Client |
| **Synapse Admin** | v0.10.3-etke32 (etkecc fork) | Admin UI |
| **S6-Overlay** | — | Multi-Service Orchestration |

> **Hinweis:** Synapse Admin verwendet den [etkecc Fork](https://github.com/etkecc/synapse-admin) — kompatibel mit Synapse 1.14x (react-admin v5). Der Original Awesome-Technologies Fork funktioniert **nicht** mit Synapse 1.14x.

---

## 🚀 Installation

### 1. ZIP hochladen
In HA → Einstellungen → Add-ons → Dreipunkt-Menü → Addon aus ZIP installieren.

### 2. Konfiguration anpassen
```yaml
server_name: "matrix.deine-domain.duckdns.org"   # OHNE trailing slash!
element_web_url: "https://matrix.deine-domain.duckdns.org"
enable_registration: false
registration_shared_secret: ""     # leer lassen → wird automatisch generiert
enable_federation: true
max_upload_size_mb: 50
enable_synapse_admin: true
postgres_password: "sicheresPasswort123!"
log_level: "WARNING"
```

> ⚠️ `server_name` darf **keinen** trailing slash haben (`matrix.example.org` ✅, `matrix.example.org/` ❌)

### 3. Addon starten
Erster Start dauert 2–3 Minuten — Element Web und Synapse Admin werden erst zur Laufzeit heruntergeladen (HA blockiert Netzwerk während dem Docker Build).

### 4. Admin User erstellen
```bash
docker exec -it addon_local_matrix_server \
  /opt/synapse/bin/register_new_matrix_user \
  -c /data/matrix/synapse/homeserver.yaml \
  --admin -u admin -p DeinSicheresPasswort! \
  http://localhost:8008
```

### 5. Nginx Proxy Manager konfigurieren
Siehe `NPM_SETUP.md` für die genaue Konfiguration.

---

## 🌐 Ports & URLs

| Port | Dienst | Zugriff |
|---|---|---|
| **7080** | Element Web | Via NPM → `element.deine-domain.duckdns.org` |
| **8008** | Synapse API | Via NPM → `matrix.deine-domain.duckdns.org` |
| **8090** | Synapse Admin UI | Via NPM → `admin.deine-domain.duckdns.org` |
| **8448** | Matrix Federation | Direkt (Router Port-Forwarding) |

---

## 🔧 Synapse Admin UI

### Zugriff
- Extern: `https://admin.deine-domain.duckdns.org`
- Lokal: `http://[HA-IP]:8090`

### Login
- **Homeserver URL:** `https://matrix.deine-domain.duckdns.org`
- **Benutzername:** `admin`

> ⚠️ NPM Access List für `admin.*` muss auf **Publicly Accessible** stehen — die Auth kommt vom Synapse Admin Login selbst.

### Token manuell holen (falls nötig)
```bash
curl -s -X POST http://[HA-IP]:8008/_matrix/client/v3/login \
  -H "Content-Type: application/json" \
  -d '{"type":"m.login.password","user":"admin","password":"DeinPasswort"}' \
  | grep access_token
```

### Admin-Status prüfen
```bash
docker exec -it addon_local_matrix_server \
  psql -U synapse -d synapse -c "SELECT name, admin FROM users;"
```

---

## 🌍 Element Web — Dual Config (Lokal + Extern)

Element Web lädt automatisch eine hostname-spezifische Config:

| Datei | Wird geladen von | Synapse URL |
|---|---|---|
| `config.json` | Fallback / extern | `https://matrix.deine-domain.duckdns.org` |
| `config.[HA-IP].json` | Browser im LAN | `http://[HA-IP]:8008` |
| `config.matrix.[domain].json` | `matrix.*` Subdomain | `https://matrix.deine-domain.duckdns.org` |

---

## 💾 Datenspeicherung (persistent)

```
/data/matrix/
├── postgresql/           # PostgreSQL Datenbank
├── synapse/
│   ├── homeserver.yaml   # Konfiguration
│   ├── signing.key       # Server Signing Key ⚠️ BACKUP!
│   └── media_store/      # Hochgeladene Medien
├── element-web/          # Element Web Dateien (persistent)
├── synapse-admin/        # Synapse Admin Dateien (persistent)
└── .webapps_downloaded   # Marker: Web-Apps bereits heruntergeladen
```

> ⚠️ `signing.key` unbedingt sichern — Verlust bedeutet Verlust der Federation-Identität.

### Web-Apps neu herunterladen erzwingen
```bash
docker exec addon_local_matrix_server rm /data/matrix/.webapps_downloaded
# dann Addon neu starten
```

---

## 📱 UnifiedPush (Android Push via ntfy)

Mit dem ntfy Add-on kann dieses Addon vollständiges **datenschutzfreundliches Push** für Element Android bieten — ohne Google Firebase, ohne externe Server.

### Wie es funktioniert

```
Element Android
  → wählt ntfy als UnifiedPush Distributor
  → registriert Push Gateway bei Synapse:
      https://ntfy.deine-domain.tld/_matrix/push/v1/notify
  → Synapse schickt Pushes an ntfy
  → ntfy liefert an dein Gerät
```

Synapse muss die ntfy-URL **nicht** in seiner Config kennen — der Client trägt alles selbst ein.

### Voraussetzungen

- **ntfy Add-on** läuft mit gesetzter `base_url` (ohne `base_url` kein Gateway-Endpoint)
- **ntfy App** aus F-Droid (Play Store Version hat kein UnifiedPush)
- ntfy-Server von extern erreichbar (via NPM)

### Einrichtung

**1. Addon-Config:** `ntfy_url` auf die externe ntfy-URL setzen:
```yaml
ntfy_url: "https://ntfy.deine-domain.tld"
```
Beim Start prüft das Addon die Erreichbarkeit und gibt Anweisungen im Log aus.

**2. ntfy App (F-Droid):** Installieren → Einstellungen → Server: `https://ntfy.deine-domain.tld`

**3. Element Android:** Einstellungen → Benachrichtigungen → UnifiedPush → ntfy auswählen

Fertig. Kein weiterer Eingriff in Synapse nötig.

---

## 🏠 Home Assistant Integration

```yaml
# configuration.yaml
notify:
  - platform: matrix
    name: matrix_notify
    homeserver: https://matrix.deine-domain.duckdns.org
    username: "@homeassistant:deine-domain.duckdns.org"
    password: "ha_user_passwort"
    default_room: "#homeassistant:deine-domain.duckdns.org"
```

---

## 🔍 Federation testen

```
https://federationtester.matrix.org/#deine-domain.duckdns.org
```

---

## 📊 Ressourcenverbrauch (Pi 4, 8GB RAM)

| Dienst | RAM | CPU (idle) |
|---|---|---|
| PostgreSQL | ~100MB | <1% |
| Synapse | ~300–500MB | 1–3% |
| Element Web (Python HTTP) | ~10MB | <1% |
| Synapse Admin (Python HTTP) | ~10MB | <1% |
| **Gesamt** | **~450–650MB** | **~3–5%** |

---

## 🐛 Troubleshooting

| Problem | Ursache | Lösung |
|---|---|---|
| `Server name has invalid format` | trailing slash in `server_name` | Slash entfernen |
| Admin Panel "Something went wrong" | alter Browser-Cache | F12 → Application → Clear Site Data |
| Admin Panel 401 | NPM Access List aktiv | Access List auf "Publicly Accessible" |
| Element Web falscher Server | falsches config.json | Browser-Cache leeren |
| Web-Apps 0 Dateien | Extraktion fehlgeschlagen | Marker löschen + Addon neu starten |
| Synapse Token ungültig | Addon neu installiert, DB leer | Admin User neu erstellen |
| Federation broken | Port 8448 nicht offen | Router: 8448 → HA-IP:8448 |
