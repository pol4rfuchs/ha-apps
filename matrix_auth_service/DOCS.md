# Matrix Auth Service (MAS)

Next-Gen-Authentifizierung für Matrix Synapse via OIDC/OAuth2. Voraussetzung
für Element X QR-Code-Login, MFA und weitere "Matrix 2.0"-Client-Features.

## Status

⚠️ **Ungetestet / Konzept-Skeleton.** Noch nicht gebaut, noch kein
Container-Start durchgeführt. Icon/Logo und apparmor.txt sind bewusst
zurückgestellt (gleiches Muster wie beim Technitium-Add-on).

## Voraussetzungen

- Ein bereits laufendes Matrix Synapse Add-on mit **Simplified Sliding
  Sync**-Unterstützung (ab Synapse 1.114 nativ vorhanden)
- Eigene Subdomain für die Account-UI (z.B. `account.deine-domain.eu.org`)
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
- [ ] `icon.png` / `logo.png`
- [ ] `apparmor.txt`
- [ ] Ingress-Route für `mas_domain` in NPM einrichten (analog Synapse)
- [ ] Prüfen: reicht `password_login_enabled: true` als Fallback, oder soll
      MAS von Anfang an nur mit einem Upstream-OIDC-Provider laufen?
