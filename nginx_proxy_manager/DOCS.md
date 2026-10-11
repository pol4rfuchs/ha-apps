# Nginx Proxy Manager – Add-on Dokumentation

Vollwertige HA-Integration des offiziellen [Nginx Proxy Managers](https://nginxproxymanager.com).

---

## Erststart

1. Add-on installieren und starten
2. UI über `http://<HA-Host>:81` öffnen (Button „Web-UI öffnen“ der App; es gibt kein Ingress)
3. Standard-Login des Upstream-Images: `admin@example.com` / `changeme`
4. **Sofort E-Mail und Passwort ändern.** Bis dahin kann jeder im LAN, der Port 81 erreicht, die Proxy-Konfiguration übernehmen.
5. Port `81` **nie** am Router weiterleiten (nur `80` und `443`).

---

## Konfiguration

### SQLite (Standard)

Keine weiteren Einstellungen nötig. Daten liegen unter `/data/npm/`.

### MariaDB (empfohlen für Produktivbetrieb)

1. HA **MariaDB Add-on** installieren und starten
2. Datenbank + User in MariaDB anlegen
3. Add-on konfigurieren:

```yaml
db_type: mariadb
mariadb_host: core-mariadb
mariadb_port: 3306
mariadb_name: npm
mariadb_user: npm
```

4. Passwort in `secrets.yaml`:

```yaml
mariadb_password: "dein_passwort"
```

---

## Secrets (`secrets.yaml`)

| Key                | Beschreibung                          |
|--------------------|---------------------------------------|
| `mariadb_password` | Passwort für MariaDB-Verbindung       |
| `npm_jwt_secret`   | Eigener JWT-Secret (optional)         |

Beispiel `secrets.yaml`:

```yaml
mariadb_password: "supergeheim123"
npm_jwt_secret: "einlangesrandommjwtsecret"
```

---

## Ports

| Port | Funktion                  |
|------|---------------------------|
| 80   | HTTP (Proxy-Traffic)      |
| 443  | HTTPS (Proxy-Traffic)     |
| 81   | NPM Admin-UI (direkt, nur LAN) |

> Port 81 ist auf dem Host gemappt und im LAN erreichbar (kein Ingress). Er darf **nie** ins Internet weitergeleitet werden, siehe *Lokaler und externer Zugriff*.

---

## SSL / Let's Encrypt

NPM bringt Let's Encrypt vollständig mit. Unterstützte Challenge-Typen:

- HTTP-01 (Standard)
- DNS-01 (z. B. Cloudflare, erfordert API-Token)
- Wildcard-Zertifikate via DNS-01

### Cloudflare DNS-01 einrichten

1. Cloudflare API-Token erstellen (Zone → DNS → Edit)
2. In NPM unter **SSL Certificates → Add Certificate → DNS Challenge**
3. Provider: Cloudflare, Token eingeben

---

## Backup & Restore

Alle persistenten Daten liegen unter `/data/npm/`:

```
/data/npm/
├── data/          # Datenbank, Konfiguration, Proxy-Hosts
├── letsencrypt/   # Zertifikate
└── logs/          # Access/Error Logs (von Backup ausgeschlossen)
```

HA-Snapshots sichern `/data/npm/data` und `/data/npm/letsencrypt` automatisch.

---

## Dark Mode

NPM unterstützt Dark Mode nativ. Aktivierung in der UI:
**Account → Appearance → Dark**

---

## Optionale Einstellungen

```yaml
http_port: 80         # HTTP-Port (Standard: 80)
https_port: 443       # HTTPS-Port (Standard: 443)
disable_ipv6: false   # IPv6 deaktivieren
log_level: info       # info | warning | error | debug
```

---

## Problembehandlung

**UI nicht erreichbar:**
→ Add-on neu starten, Host-Port 81 in der Netzwerk-Konfiguration der App prüfen

**MariaDB Verbindungsfehler:**
→ MariaDB Add-on läuft? User/DB existiert? Passwort in secrets.yaml korrekt?

**Zertifikat-Erneuerung schlägt fehl:**
→ Logs prüfen unter: **NPM UI → Logs → Access/Error**

## Lokaler und externer Zugriff

**Lokal (LAN):** Die Admin-Oberfläche läuft direkt auf Port `81` (`http://<HA-Host>:81`), nicht über Ingress. Der Port ist auf dem Host gemappt und im ganzen LAN erreichbar. Das Standardlogin (`admin@example.com` / `changeme`) sofort nach dem ersten Start ändern.

**Extern (Internet):** Die Ports `80` und `443` sind der Eingang für den Proxy-Traffic und dürfen am Router weitergeleitet werden, das ist der Zweck der App. Port `81` **nie** ins Internet, nur LAN oder VPN.
