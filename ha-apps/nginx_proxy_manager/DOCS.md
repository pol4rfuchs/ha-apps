# Nginx Proxy Manager – Add-on Dokumentation

Vollwertige HA-Integration des offiziellen [Nginx Proxy Managers](https://nginxproxymanager.com).

---

## Erststart

1. Add-on installieren und starten
2. UI über **Ingress** (Seitenleiste) öffnen
3. Standard-Login: `admin@example.com` / `changeme`
4. **Sofort Passwort ändern!**

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
| 81   | NPM UI (via Ingress)      |

> Port 81 wird **nicht** nach außen exponiert – der Zugriff erfolgt ausschließlich über HA Ingress.

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

**UI nicht erreichbar über Ingress:**
→ Add-on neu starten, Ingress-Port 81 prüfen

**MariaDB Verbindungsfehler:**
→ MariaDB Add-on läuft? User/DB existiert? Passwort in secrets.yaml korrekt?

**Zertifikat-Erneuerung schlägt fehl:**
→ Logs prüfen unter: **NPM UI → Logs → Access/Error**
