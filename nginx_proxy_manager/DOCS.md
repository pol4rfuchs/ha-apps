# Nginx Proxy Manager – Add-on Dokumentation

Vollwertige HA-Integration des offiziellen [Nginx Proxy Managers](https://nginxproxymanager.com).

---

## Erststart

1. Add-on installieren und starten
2. UI über `http://<HA-Host>:81` öffnen (Button „Web-UI öffnen“ der App; es gibt kein Ingress)
3. Beim ersten Öffnen zeigt NPM den Einrichtungsassistenten („Welcome! Get started by creating your admin account.“). Dort Name, E-Mail und Passwort für das Admin-Konto festlegen. Ein Standard-Login (`admin@example.com` / `changeme`) gibt es seit NPM 2.13 nicht mehr.
4. **Den Assistenten sofort abschließen.** Bis dahin kann jeder im LAN, der Port 81 erreicht, das Admin-Konto selbst anlegen und die Proxy-Konfiguration übernehmen. Bestehende Installationen behalten nach einem Update ihre Zugangsdaten.
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
mariadb_password: "dein_passwort"
```

Das Passwort ist als Passwortfeld deklariert und wird in der Oberfläche
maskiert. Wer die Werte aus der HA-`secrets.yaml` beziehen will, trägt sie dort
mit `!secret` ein, das löst der Supervisor beim Speichern auf.

Die Sitzungsschlüssel (JWT) erzeugt NPM selbst und legt sie unter
`/data/keys.json` ab. Dafür gibt es keine Option.

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
disable_ipv6: false   # IPv6 deaktivieren
log_level: info       # info | warning | error | debug
```

---

## Problembehandlung

**UI nicht erreichbar:**
→ Add-on neu starten, Host-Port 81 in der Netzwerk-Konfiguration der App prüfen

**MariaDB Verbindungsfehler:**
→ MariaDB Add-on läuft? User/DB existiert? `mariadb_password` korrekt?

**Zertifikat-Erneuerung schlägt fehl:**
→ Logs prüfen unter: **NPM UI → Logs → Access/Error**

## Lokaler und externer Zugriff

**Lokal (LAN):** Die Admin-Oberfläche läuft direkt auf Port `81` (`http://<HA-Host>:81`), nicht über Ingress. Der Port ist auf dem Host gemappt und im ganzen LAN erreichbar. Direkt nach dem ersten Start den Einrichtungsassistenten abschließen und das Admin-Konto anlegen, vorher ist die Oberfläche ungeschützt.

**Extern (Internet):** Die Ports `80` und `443` sind der Eingang für den Proxy-Traffic und dürfen am Router weitergeleitet werden, das ist der Zweck der App. Port `81` **nie** ins Internet, nur LAN oder VPN.
