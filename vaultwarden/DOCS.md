# Vaultwarden

Vaultwarden ist eine in Rust geschriebene, Bitwarden-kompatible Server-Implementierung. Diese App packt das offizielle Upstream-Image (`ghcr.io/dani-garcia/vaultwarden`, Alpine-Variante) in eine Home-Assistant-App.

## Voraussetzungen

- **HTTPS ist Pflicht.** Der Web Vault und alle Bitwarden-Clients funktionieren nur über HTTPS mit passender `domain`.
- **Kein Ingress.** Der Web Vault lässt sich nicht unter einem Unterpfad betreiben; die App ist über Port `7277` direkt erreichbar.
- Empfohlen: Reverse Proxy (z. B. Nginx Proxy Manager) vor der App, der HTTPS terminiert und die Domain (z. B. `vault.example.com`) auf `http://<HA-Host>:7277` weiterleitet. **WebSocket-Support im Proxy aktivieren.**
- Alternativ: `ssl: true` – die App liefert HTTPS selbst aus `/ssl` aus (von Upstream nicht empfohlen).

## Erststart

1. `domain` auf die öffentliche HTTPS-URL setzen (z. B. `https://vault.example.com`).
2. Admin-Token erzeugen (Argon2id-Hash, Klartext wird abgelehnt):
   ```
   docker run --rm -it ghcr.io/dani-garcia/vaultwarden:latest-alpine /vaultwarden hash
   ```
   Den ausgegebenen `$argon2id$...`-String als `admin_token` eintragen. Leer = Admin-Panel deaktiviert.
3. Für das erste Konto `signups_allowed` auf `true` stellen (Standard ist `false`) und die App starten.
4. Im Web Vault die Konten anlegen.
5. Danach `signups_allowed` wieder auf `false` stellen.

## Konfiguration

Alle Einstellungen sind App-Optionen. Leere optionale Felder (bei Zahlenfeldern `0`) werden nicht an Vaultwarden übergeben (Upstream-Default gilt). Secrets (Admin-Token, SMTP-Passwort, Push-Key, SSO-Secret, Yubico, Duo, HIBP) werden nicht als Umgebungsvariable, sondern über `*_FILE` aus einem tmpfs gelesen.

### `log_level`

Verbosität der Logs. debug nur zur Fehlersuche verwenden.

Default: `info`

### `domain`

Öffentliche HTTPS-URL, über die Clients Vaultwarden erreichen (DOMAIN). Nötig für Mail-Links, Anhänge, WebAuthn und SSO.

Default: –

### `ssl`

HTTPS direkt aus der App ausliefern (Zertifikat und Key aus /ssl). Hinter einem Reverse Proxy nicht nötig.

Default: `false`

### `certfile`

Name der Zertifikatsdatei in /ssl (nur bei aktiviertem HTTPS).

Default: `fullchain.pem`

### `keyfile`

Name der Key-Datei in /ssl (nur bei aktiviertem HTTPS).

Default: `privkey.pem`

### `admin_token`

Argon2id-PHC-Hash des Admin-Passworts. Leer = Admin-Panel aus. Klartext wird abgelehnt.

Default: –

### `signups_allowed`

Jeder mit Zugriff auf den Server darf sich registrieren. Standardmäßig aus; zum Anlegen der eigenen Konten kurz einschalten und danach wieder abschalten.

Default: `false`

### `signups_verify`

E-Mail-Verifikation für neue Konten verlangen (braucht SMTP).

Default: `false`

### `signups_domains_whitelist`

Kommagetrennte E-Mail-Domains, die sich trotz deaktivierter Registrierung anmelden dürfen.

Default: –

### `invitations_allowed`

Organisations-Admins dürfen Nutzer einladen, auch bei deaktivierter Registrierung.

Default: `true`

### `org_creation_users`

Leer oder all = alle, none = niemand, oder kommagetrennte E-Mail-Adressen.

Default: –

### `email_change_allowed`

Nutzer dürfen ihre E-Mail-Adresse ändern.

Default: `true`

### `emergency_access_allowed`

Nutzer dürfen einen Notfallzugriff auf ihr Konto einrichten.

Default: `true`

### `sends_allowed`

Nutzer dürfen Sends anlegen.

Default: `true`

### `password_hints_allowed`

Nutzer dürfen Passwort-Hinweise setzen und abrufen.

Default: `true`

### `show_password_hint`

Hinweis ohne SMTP direkt auf der Seite zeigen. Für erreichbare Instanzen nicht empfohlen.

Default: `false`

### `trash_auto_delete_days`

Gelöschte Einträge nach so vielen Tagen endgültig löschen. 0 = nie.

Default: `0`

### `enable_websocket`

Live-Sync-Benachrichtigungen für Web-, Desktop- und Browser-Clients.

Default: `true`

### `ip_header`

Header, mit dem dein Reverse Proxy die Client-IP übergibt. none nutzt die Verbindungsadresse.

Default: `X-Real-IP`

### `ip_header_trusted_proxies`

IPs oder CIDR-Bereiche, von denen der IP-Header akzeptiert wird. Leer = local (alle nicht-öffentlichen Adressen, Vaultwarden-Standard).

Default: –

### `icon_service`

internal lädt Favicons direkt von den Seiten, bitwarden leitet Clients auf den Icon-Dienst von Bitwarden um.

Default: `internal`

### `disable_icon_download`

Keine Favicon-Abrufe bei fremden Seiten (Datenschutz: sonst wäre sichtbar, welche Seiten im Tresor stehen). Bereits zwischengespeicherte Icons bleiben erhalten und laufen nicht ab. Auf `false` stellen, wenn Seiten-Icons angezeigt werden sollen.

Default: `true`

### `http_request_block_non_global_ips`

Ausgehende Anfragen (Icons, Webhooks) an nicht-öffentliche Adressen verweigern.

Default: `true`

### `login_ratelimit_seconds`

Durchschnittliche Sekunden zwischen Login-Anfragen je IP.

Default: `60`

### `login_ratelimit_max_burst`

Erlaubter Burst an Login-Anfragen (Login und 2FA, mindestens 2).

Default: `10`

### `admin_ratelimit_seconds`

Durchschnittliche Sekunden zwischen Admin-Login-Anfragen je IP.

Default: `300`

### `admin_ratelimit_max_burst`

Erlaubter Burst an Admin-Login-Anfragen.

Default: `3`

### `unauthenticated_ratelimit_seconds`

Durchschnittliche Sekunden zwischen Anfragen an Endpunkte ohne Login (Hinweise, Recovery-Mails, Sends) je IP.

Default: `60`

### `unauthenticated_ratelimit_max_burst`

Gemeinsames Burst-Budget für Endpunkte ohne Login.

Default: `50`

### `smtp_host`

SMTP-Server für E-Mails (Einladungen, Verifikation, 2FA-Codes).

Default: –

### `smtp_port`

0 = Standard des gewählten Modus (587, 465 oder 25).

Default: `0`

### `smtp_security`

starttls (587), force_tls (implizites TLS, 465) oder off (25).

Default: `starttls`

### `smtp_from`

Absenderadresse, zusammen mit dem SMTP-Server Pflicht.

Default: –

### `smtp_from_name`

Anzeigename des Absenders. Leer = Vaultwarden.

Default: –

### `smtp_username`

Für Server ohne Authentifizierung leer lassen.

Default: –

### `smtp_password`

Pflicht, sobald ein Benutzername gesetzt ist.

Default: –

### `smtp_auth_mechanism`

Kommagetrennt: Plain, Login, Xoauth2. Leer = automatisch.

Default: –

### `smtp_accept_invalid_certs`

GEFÄHRLICH: ermöglicht Man-in-the-Middle. Nur als letzter Ausweg.

Default: `false`

### `smtp_accept_invalid_hostnames`

GEFÄHRLICH: ermöglicht Man-in-the-Middle. Nur als letzter Ausweg.

Default: `false`

### `smtp_debug`

Sehr ausführliches SMTP-Logging, kann Zugangsdaten enthalten. Nur zur Fehlersuche.

Default: `false`

### `push_enabled`

Mobile Push über das Bitwarden-Relay (externer Dienst). Braucht Installations-ID und Key von bitwarden.com/host.

Default: `false`

### `push_region`

Datenregion, für die die Push-Keys ausgestellt wurden.

Default: `us`

### `push_installation_id`

Installations-ID von bitwarden.com/host.

Default: –

### `push_installation_key`

Installations-Key von bitwarden.com/host.

Default: –

### `sso_enabled`

Login über einen OpenID-Connect-Identity-Provider erlauben.

Default: `false`

### `sso_only`

Login mit E-Mail und Master-Passwort abschalten.

Default: `false`

### `sso_signups_allowed`

Der SSO-Ablauf darf Konten anlegen. Bei öffentlichen Providern abschalten.

Default: `true`

### `sso_signups_match_email`

SSO-Registrierung mit einem Konto gleicher E-Mail verknüpfen.

Default: `true`

### `sso_allow_unknown_email_verification`

Zusammen mit E-Mail-Zuordnung droht eine mögliche Kontoübernahme.

Default: `false`

### `sso_authority`

Basis-URL des OIDC-Servers, ohne /.well-known/... und genau wie vom Provider dokumentiert.

Default: –

### `sso_client_id`

Beim Identity-Provider registrierte Client-ID.

Default: –

### `sso_client_secret`

Beim Identity-Provider registriertes Client-Secret.

Default: –

### `sso_scopes`

Leerzeichengetrennte zusätzliche Scopes. Leer = email profile.

Default: –

### `sso_pkce`

PKCE für den Authorization-Code-Flow verwenden.

Default: `true`

### `sso_authorize_extra_params`

Zusätzliche URL-Parameter, z. B. um Refresh-Tokens zu erhalten.

Default: –

### `yubico_client_id`

Client-ID für YubiKey OTP.

Default: –

### `yubico_secret_key`

Secret Key für YubiKey OTP.

Default: –

### `duo_ikey`

Globaler Duo-Integration-Key (braucht auch Secret Key und API-Host).

Default: –

### `duo_skey`

Globaler Duo-Secret-Key.

Default: –

### `duo_host`

Duo-API-Hostname.

Default: –

### `hibp_api_key`

Aktiviert Leak-Prüfungen bei haveibeenpwned.com (externer Dienst).

Default: –

### `experimental_client_feature_flags`

Kommagetrennte Flags. In Vaultwarden 1.37.4 entfernte Flags werden automatisch verworfen.

Default: –

### `extra_env`

Weitere Vaultwarden-Einstellungen als Liste aus `name`/`value` (z. B. `ORG_EVENTS_ENABLED`). Geschützte Namen (`DATA_FOLDER`, `DATABASE_URL`, `WEB_VAULT_FOLDER`, `WEB_VAULT_ENABLED`, `ENV_FILE`, `ROCKET_*`, `RSA_KEY_FILENAME`) werden abgelehnt. Die Werte stehen im Klartext in der App-Konfiguration – Secrets daher nicht hier eintragen.

Default: `[]`

## Wichtige Hinweise

### Admin-Panel überschreibt App-Optionen

Speicherst du im Admin-Panel (`/admin`) Einstellungen, schreibt Vaultwarden eine `config.json` in den Datenordner. Deren Werte haben **Vorrang** vor den App-Optionen. Beim Start warnt die App im Log, wenn eine `config.json` existiert. Empfehlung: Konfiguration über die App-Optionen pflegen und das Admin-Panel nur zur Verwaltung nutzen.

### Reverse Proxy und Client-IP

Mit `ip_header` (Standard `X-Real-IP`) liest Vaultwarden die Client-IP aus dem Header deines Proxys; sie wird für Rate-Limits genutzt. Standardmäßig wird der Header von allen nicht-öffentlichen Adressen akzeptiert (`local`). Liegt dein Proxy auf einer öffentlichen Adresse oder willst du enger einschränken, trage in `ip_header_trusted_proxies` die Proxy-IPs bzw. CIDR-Bereiche ein. Ohne Proxy `ip_header: none` setzen.

### Lokaler und externer Zugriff

**Lokal (LAN):** Der Web Vault braucht einen sicheren Kontext (HTTPS). Über `http://<HA-Host>:7277` funktionieren Registrierung und Login im Browser nicht. Zwei Wege:

- **`ssl: true`:** Zertifikat und Schlüssel liegen in `/ssl`, der Zugriff läuft über `https://<HA-Host>:7277`. Bei einem selbstsignierten Zertifikat die Browser-Warnung bestätigen.
- **Reverse Proxy mit lokalem DNS-Rewrite:** Eine Domain wie `vault.example.com` zeigt im lokalen DNS auf den HA-Host. Der Proxy (z. B. Nginx Proxy Manager) terminiert HTTPS mit einem gültigen Zertifikat und leitet auf `http://<HA-Host>:7277` weiter, WebSocket-Support aktiv. `domain` auf `https://vault.example.com` setzen.

**Extern (Internet):** Empfehlung **ok, aber nur über den Reverse Proxy mit TLS.** Den App-Port `7277` nie direkt per Port-Forward freigeben. Dazu:

- `signups_allowed` abschalten, sobald die Konten angelegt sind.
- Das Admin-Panel (`/admin`) nicht öffentlich erreichbar machen: `admin_token` leer lassen, wenn es nicht gebraucht wird, oder `/admin` im Proxy auf LAN bzw. VPN beschränken.
- Zwei-Faktor-Anmeldung für alle Konten aktivieren.

### Datenschutz externer Dienste

- `push_enabled`: Push läuft über das Bitwarden-Relay (externer Dienst, Geräte-Metadaten gehen dorthin). Installations-ID und -Key kommen von bitwarden.com/host; `push_region` muss zur Region der Keys passen.
- `icon_service: bitwarden` leitet Clients an Bitwarden um; `internal` ruft Favicons direkt von den Seiten ab. `disable_icon_download` schaltet jeden Abruf ab.
- `hibp_api_key` aktiviert Leak-Prüfungen bei haveibeenpwned.com.

### Entfernte Feature-Flags

Vaultwarden 1.37.4 hat mehrere Einträge aus `experimental_client_feature_flags` entfernt; enthält die Liste sie noch, scheitert das Speichern im Admin-Panel. Die App filtert diese Flags beim Start heraus und schreibt eine Warnung ins Log.

### Daten, Backup und Restore

Alle Daten (SQLite-Datenbank, RSA-Schlüssel, Anhänge, Sends, `config.json`) liegen unter `/data/vaultwarden`. Die App nutzt ausschließlich SQLite. Home-Assistant-Backups sind als **cold** konfiguriert: Die App wird für das Backup kurz gestoppt, damit die Datenbank konsistent ist. Icon-Cache und Temp-Dateien sind vom Backup ausgenommen. Restore: Backup in Home Assistant einspielen und App starten.

### Sicherheit

- Die App läuft nach der Initialisierung als unprivilegierter Benutzer `vaultwarden` und ist durch ein AppArmor-Profil eingeschränkt.
- `smtp_accept_invalid_certs`, `smtp_accept_invalid_hostnames` und `sso_allow_unknown_email_verification` nur im Notfall aktivieren.
- Die Werte in `extra_env` sind im Klartext in der App-Konfiguration sichtbar – keine Secrets dort eintragen; dafür gibt es die Passwort-Felder.
