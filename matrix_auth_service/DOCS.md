# Matrix Auth Service (MAS)

Next-Gen-Authentifizierung für Matrix Synapse via OIDC/OAuth2. Voraussetzung
für Element X QR-Code-Login, MFA und weitere "Matrix 2.0"-Client-Features.

## Status

Die App wird gebaut und veröffentlicht (siehe CHANGELOG). Offen sind die
Punkte unten, vor allem AppArmor: `apparmor.txt` fehlt und `apparmor: false`
ist gesetzt.

## Voraussetzungen

- Ein bereits laufendes Matrix Synapse Add-on mit **Simplified Sliding
  Sync**-Unterstützung (ab Synapse 1.114 nativ vorhanden)
- Eigene Subdomain für die Account-UI (z.B. `account.example.org`)
- Fresh-Start empfohlen: bestehende Accounts werden **nicht** automatisch
  migriert (kein `syn2mas`-Schritt in diesem Add-on eingebaut)

## Einrichtung

1. Add-on installieren, `mas_domain`, `synapse_server_name`,
   `synapse_endpoint` setzen
2. `synapse_secret` leer lassen → wird beim ersten Start automatisch
   generiert (Wert erscheint im Log und unter `/data/mas/.synapse_secret`)
3. Generierten Secret-Wert ins Synapse-Add-on übertragen:
   `mas_enabled: true`, `mas_secret: <Wert>`, `mas_endpoint: http://[HA-IP]:8082`
4. Beide Add-ons neu starten

## Offene Punkte (vor Produktivbetrieb)

- [ ] Erster Build + Test-Lauf (Postgres-Init, `mas-cli database migrate`,
      `mas-cli config sync`)
- [x] `icon.png` / `logo.png` (Icon aus dem Logo abgeleitet, bei Bedarf ersetzen)
- [ ] `apparmor.txt`
- [x] Reverse-Proxy-Route für `mas_domain` in NPM: siehe Abschnitt *Lokaler und externer Zugriff*
- [ ] Prüfen: reicht `password_login_enabled: true` als Fallback, oder soll
      MAS von Anfang an nur mit einem Upstream-OIDC-Provider laufen?

## Lokaler und externer Zugriff

**Lokal (LAN):** Die Account-UI läuft auf Port `8082` (`http://<HA-Host>:8082`). MAS verwendet `https://<mas_domain>/` als öffentliche Adresse (Issuer). Der Login-Ablauf funktioniert deshalb nur über diese HTTPS-Domain, nicht über die reine LAN-IP. Lokal nutzbar wird es mit einem DNS-Rewrite im lokalen DNS-Server auf den HA-Host plus Reverse Proxy mit Zertifikat.

**Reverse-Proxy-Route (z. B. Nginx Proxy Manager):** neuer Proxy Host mit Domain = `mas_domain`, Scheme `http`, Forward-Host = HA-Host, Port `8082`. Zertifikat anfordern und „Force SSL“ aktivieren. Port `8083` (nur Health-Check) gehört nicht in den Proxy.

**Extern (Internet):** Empfehlung **ok, nur über den Reverse Proxy mit TLS** (Matrix-Clients brauchen die öffentliche Adresse). Die Ports `8082` und `8083` nie direkt freigeben. `password_registration_enabled` bleibt aus (Standard).
