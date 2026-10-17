# CortenDesk

Console (Geräte, Benutzer, Adressbücher, Gruppen) plus ID-Server und Relay in einer App.
Der enthaltene Server ist der CortenDesk-Server-Fork (rustdesk-server 1.1.16 plus Fix für
angemeldete Clients ab 1.4.1).

## Konfiguration

### Option: `app_url` (Pflicht)

Öffentliche Adresse der App, wie deine Clients sie erreichen, inklusive Schema und
Console-Port, z. B. `http://rd.example.com:21114`. Der Host-Teil wird den Clients als
ID-Server (`<host>:21116`) und Relay (`<host>:21117`) mitgeteilt. Ohne erreichbaren Host
hängen Sitzungen, die das Relay brauchen.

### Optionen: `id_server` / `relay_server` (optional)

Format `host:port`, z. B. `rd.example.com:21116` bzw. `rd.example.com:21117`. Leer = Host aus
`app_url` mit den Ports 21116 bzw. 21117. Nötig, wenn Clients im LAN und von außen dieselbe
Instanz nutzen: `hbbs` teilt **allen** Clients dieselbe Relay-Adresse mit. Steht dort eine
LAN-IP, hängen Relay-Sitzungen von außen. Mit einem Hostnamen, der intern und extern auflöst
(Split-DNS), funktioniert beides.

### Option: `admin_user` / `admin_password` (Pflicht)

Erster Administrator. **Wirkt nur beim allerersten Start** (solange kein Benutzer existiert).
Spätere Änderungen der Option ändern das Passwort nicht, das geschieht in der Console.

### Option: `native_webclient`

Aktiviert den Browser-Client. Standard: aus. Die WebSocket-Ports 21118/21119 werden nicht
auf den Host gemappt: Sie lauschen im Container auf allen Adressen und sind deshalb nur im internen Docker-Netz erreichbar.

### Option: `downloads_max_mb`

Upload-Limit für Client-Installer unter System → Client Downloads. Leer = Upstream-Standard (512 MB).

### Option: `log_level`

Steuert die Log-Verbosität von Console (Laravel) und ID-/Relay-Server (`RUST_LOG`).
Werte: `DEBUG`, `INFO`, `WARNING`, `ERROR`. Default: `INFO`.
Wird als `CORTENDESK_LOG_LEVEL` an Upstream gereicht, das daraus `LOG_LEVEL` und `RUST_LOG` ableitet.

## Ports

| Port | Zweck |
|---|---|
| 21114/tcp | Console (Container-Port 8080) |
| 21115/tcp | hbbs NAT-Typ-Test |
| 21116/tcp + udp | hbbs ID-Server |
| 21117/tcp | hbbr Relay |

Am Router nur 21115–21117/TCP und 21116/UDP freigeben. Die Console (21114) nur mit TLS
(z. B. über einen Reverse-Proxy) und nur bei Bedarf von außen erreichbar machen.

In den RustDesk-Clients: ID-Server = `<host>`, Relay-Server = `<host>`, API-Server =
`app_url`, Key = Public Key aus dem Log (`key …` in der Zeile `server …`) oder in der Console.

## Lokaler und externer Zugriff

**Lokal (LAN):** Die Console läuft direkt auf Port `21114` (`http://<ha-host>:21114`), nicht über Ingress. Sie hat eine eigene
Anmeldung (Administrator aus `admin_user` und `admin_password`); die App startet erst, wenn `app_url` und `admin_password`
gesetzt sind. RustDesk-Clients im LAN sprechen direkt mit ID-Server (`21115/21116`) und Relay (`21117`).

**Extern (Internet):** Empfehlung **eingeschränkt ok.** Für Clients von außen genügt die Freigabe von `21115–21117/TCP` und
`21116/UDP` am Router (siehe Ports); ID-Server und Relay sind dafür gedacht, die Clients prüfen den Server-Schlüssel. Die
**Console (`21114`) nicht direkt ins Internet stellen**, nur hinter einem Reverse-Proxy mit TLS oder per VPN. Die
WebSocket-Ports `21118/21119` nie freigeben: `hbbs`/`hbbr` vertrauen dort ungeprüften `X-Forwarded-For`-Headern, deshalb sind
sie nicht auf den Host gemappt. Andere Apps im internen Docker-Netz von Home Assistant können sie erreichen; mit
`host_network: true` wären sie im ganzen LAN offen.

## Daten und Backup

Alles liegt in `/data` (SQLite-Datenbank, Server-Schlüsselpaar, App-Key, Uploads) und ist im
App-Backup enthalten. Backup-Modus ist `cold` (App wird kurz gestoppt, damit die SQLite-Dateien
konsistent sind). **Das Schlüsselpaar nicht verlieren:** ohne `/data/rustdesk/id_ed25519` müssen alle Clients
neu eingerichtet werden.

## Bekannte Einschränkungen (Version 0.0.x)

- **AppArmor nur im Complain-Modus:** Das Image läuft nicht unter s6, sondern `supervisord` (root)
  mit `php-fpm`, `nginx`, `hbbs`, `hbbr`. Das mitgelieferte Profil ist ein Entwurf: Es protokolliert
  nur und blockiert nichts. Nach einem Testlauf Log auswerten und `complain` aus den `flags`
  der `apparmor.txt` entfernen (appbuildrules §8). Lädt der Supervisor das Profil nicht,
  `apparmor: false` setzen.
- **Update-Check abgeschaltet:** Die App setzt `CORTENDESK_UPDATE_CHECK=false` (Upstream ab 1.11.0),
  die Console fragt GitHub nicht mehr ab und zeigt kein Update-Badge. Updates kommen über die App-Version.
- **Datenbank-Pfad:** SQLite liegt in `/data/db/cortendesk.sqlite` (nicht `/data`), weil `/data`
  in HA root gehört und php-fpm als `www-data` läuft.
- **Bridge-Modus ungetestet für UDP:** Ob hbbs bei gemappten Ports die echte Client-IP sieht,
  ist offen. Zeigt das Log Adressen aus 172.30.x.x, scheitert P2P und alles läuft über das Relay.
  Dann auf `host_network: true` wechseln (siehe unten).
- **SQLite:** Für wenige Geräte ausreichend. MariaDB-Anbindung ist nicht umgesetzt.
- **Host-Netz:** Mit `host_network: true` lauscht nginx fest auf Port 8080 (Kollision mit
  anderen Apps möglich) und 21118/21119 sind im LAN erreichbar.
