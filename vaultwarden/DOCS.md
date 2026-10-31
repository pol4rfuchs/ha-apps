# Vaultwarden

Vaultwarden is a Bitwarden-compatible server implementation written in Rust. This app packages the official upstream image (`ghcr.io/dani-garcia/vaultwarden`, Alpine variant) as a Home Assistant app.

## Requirements

- **HTTPS is required.** The web vault and all Bitwarden clients only work over HTTPS with a matching `domain`.
- **No ingress.** The web vault cannot be served under a subpath; the app is directly reachable on port `7277`.
- Recommended: a reverse proxy (e.g. Nginx Proxy Manager) in front of the app that terminates HTTPS and forwards the domain (e.g. `vault.example.com`) to `http://<HA-Host>:7277`. **Enable WebSocket support in the proxy.**
- Alternatively: `ssl: true` – the app serves HTTPS itself from `/ssl` (not recommended by upstream).

## First start

1. Set `domain` to the public HTTPS URL (e.g. `https://vault.example.com`).
2. Generate an admin token (Argon2id hash, plain text is rejected):
   ```
   docker run --rm -it ghcr.io/dani-garcia/vaultwarden:latest-alpine /vaultwarden hash
   ```
   Enter the printed `$argon2id$...` string as `admin_token`. Empty = admin panel disabled.
3. For the first account set `signups_allowed` to `true` (the default is `false`) and start the app.
4. Create the accounts in the web vault.
5. Afterwards set `signups_allowed` back to `false`.

## Configuration

All settings are app options. Empty optional fields (`0` for number fields) are not passed on to Vaultwarden (the upstream default applies). Secrets (admin token, SMTP password, push key, SSO secret, Yubico, Duo, HIBP) are not read as environment variables but via `*_FILE` from a tmpfs.

### `log_level`

Verbosity of the log output. Use debug only for troubleshooting.

Default: `info`

### `domain`

Public HTTPS URL clients use to reach Vaultwarden (DOMAIN). Needed for e-mail links, attachments, WebAuthn and SSO.

Default: –

### `ssl`

Serve HTTPS directly from the app using the certificate and key from /ssl. Not needed behind a reverse proxy.

Default: `false`

### `certfile`

Certificate file name inside /ssl (only used when HTTPS is enabled).

Default: `fullchain.pem`

### `keyfile`

Private key file name inside /ssl (only used when HTTPS is enabled).

Default: `privkey.pem`

### `admin_token`

Argon2id PHC hash of the admin password. Empty disables the admin panel. Plain text values are refused.

Default: –

### `signups_allowed`

Anyone who can reach the server may register. Off by default; switch it on briefly to create your own accounts and then turn it off again.

Default: `false`

### `signups_verify`

Require e-mail verification for new accounts (needs SMTP).

Default: `false`

### `signups_domains_whitelist`

Comma-separated e-mail domains that may register even if sign-ups are disabled.

Default: –

### `invitations_allowed`

Allow organization admins to invite users, even if sign-ups are disabled.

Default: `true`

### `org_creation_users`

Empty or all = everyone, none = nobody, or a comma-separated list of e-mail addresses.

Default: –

### `email_change_allowed`

Allow users to change their e-mail address.

Default: `true`

### `emergency_access_allowed`

Allow users to set up emergency access to their account.

Default: `true`

### `sends_allowed`

Allow users to create Bitwarden Sends.

Default: `true`

### `password_hints_allowed`

Allow users to set and request password hints.

Default: `true`

### `show_password_hint`

Show hints directly on the web page when SMTP is not configured. Not recommended for reachable instances.

Default: `false`

### `trash_auto_delete_days`

Permanently delete trashed items after this many days. 0 = never.

Default: `0`

### `enable_websocket`

Live sync notifications for web, desktop and browser clients.

Default: `true`

### `ip_header`

Header your reverse proxy uses to pass the client IP. none uses the connection address.

Default: `X-Real-IP`

### `ip_header_trusted_proxies`

IPs or CIDR ranges the IP header is accepted from. Empty = local (any non-public address, Vaultwarden default).

Default: –

### `icon_service`

internal fetches favicons from the sites themselves, bitwarden redirects clients to Bitwarden's icon service.

Default: `internal`

### `disable_icon_download`

No favicon requests to third-party sites (privacy: otherwise it would be visible which sites are in the vault). Icons that are already cached are kept and do not expire. Set to `false` if site icons should be shown.

Default: `true`

### `http_request_block_non_global_ips`

Refuse outgoing requests (icons, webhooks) to non-public addresses.

Default: `true`

### `login_ratelimit_seconds`

Average seconds between login requests per IP.

Default: `60`

### `login_ratelimit_max_burst`

Allowed burst of login requests (login and 2FA, minimum 2).

Default: `10`

### `admin_ratelimit_seconds`

Average seconds between admin login requests per IP.

Default: `300`

### `admin_ratelimit_max_burst`

Allowed burst of admin login requests.

Default: `3`

### `unauthenticated_ratelimit_seconds`

Average seconds between requests to unauthenticated endpoints (hints, recovery mails, Sends) per IP.

Default: `60`

### `unauthenticated_ratelimit_max_burst`

Shared burst budget for unauthenticated endpoints.

Default: `50`

### `smtp_host`

SMTP server for e-mails (invitations, verification, 2FA codes).

Default: –

### `smtp_port`

0 = default of the chosen security mode (587, 465 or 25).

Default: `0`

### `smtp_security`

starttls (587), force_tls (implicit TLS, 465) or off (25).

Default: `starttls`

### `smtp_from`

Sender address, required together with the SMTP host.

Default: –

### `smtp_from_name`

Display name of the sender. Empty = Vaultwarden.

Default: –

### `smtp_username`

Leave empty for servers without authentication.

Default: –

### `smtp_password`

Required when a username is set.

Default: –

### `smtp_auth_mechanism`

Comma-separated: Plain, Login, Xoauth2. Empty = automatic.

Default: –

### `smtp_accept_invalid_certs`

DANGEROUS: allows man-in-the-middle attacks. Last resort only.

Default: `false`

### `smtp_accept_invalid_hostnames`

DANGEROUS: allows man-in-the-middle attacks. Last resort only.

Default: `false`

### `smtp_debug`

Very verbose SMTP logging, may contain credentials. Troubleshooting only.

Default: `false`

### `push_enabled`

Mobile push via the Bitwarden relay (external service). Needs installation ID and key from bitwarden.com/host.

Default: `false`

### `push_region`

Data region the push keys were issued for.

Default: `us`

### `push_installation_id`

Installation ID from bitwarden.com/host.

Default: –

### `push_installation_key`

Installation key from bitwarden.com/host.

Default: –

### `sso_enabled`

Allow login through an OpenID Connect identity provider.

Default: `false`

### `sso_only`

Disable login with e-mail and master password.

Default: `false`

### `sso_signups_allowed`

Let the SSO flow create accounts. Disable for public providers.

Default: `true`

### `sso_signups_match_email`

Link an SSO sign-up to an existing account with the same e-mail.

Default: `true`

### `sso_allow_unknown_email_verification`

Together with e-mail matching this opens a possible account takeover.

Default: `false`

### `sso_authority`

Base URL of the OIDC server, without /.well-known/... and exactly as your provider documents it.

Default: –

### `sso_client_id`

Client ID registered at your identity provider.

Default: –

### `sso_client_secret`

Client secret registered at your identity provider.

Default: –

### `sso_scopes`

Space-separated extra scopes. Empty = email profile.

Default: –

### `sso_pkce`

Use PKCE for the authorization code flow.

Default: `true`

### `sso_authorize_extra_params`

Additional URL parameters, for example to obtain refresh tokens.

Default: –

### `yubico_client_id`

Client ID for YubiKey OTP.

Default: –

### `yubico_secret_key`

Secret key for YubiKey OTP.

Default: –

### `duo_ikey`

Global Duo integration key (needs secret key and API host too).

Default: –

### `duo_skey`

Global Duo secret key.

Default: –

### `duo_host`

Duo API hostname.

Default: –

### `hibp_api_key`

Enables breach checks against haveibeenpwned.com (external service).

Default: –

### `experimental_client_feature_flags`

Comma-separated flags. Flags removed in Vaultwarden 1.37.4 are dropped automatically.

Default: –

### `extra_env`

Further Vaultwarden settings as a list of `name`/`value` (e.g. `ORG_EVENTS_ENABLED`). Protected names (`DATA_FOLDER`, `DATABASE_URL`, `WEB_VAULT_FOLDER`, `WEB_VAULT_ENABLED`, `ENV_FILE`, `ROCKET_*`, `RSA_KEY_FILENAME`) are refused. The values are visible in plain text in the app configuration – so do not enter secrets here.

Default: `[]`

## Important notes

### The admin panel overrides app options

If you save settings in the admin panel (`/admin`), Vaultwarden writes a `config.json` into the data folder. Its values take **precedence** over the app options. At startup the app warns in the log if a `config.json` exists. Recommendation: maintain the configuration through the app options and use the admin panel only for administration.

### Reverse proxy and client IP

With `ip_header` (default `X-Real-IP`) Vaultwarden reads the client IP from your proxy's header; it is used for rate limits. By default the header is accepted from all non-public addresses (`local`). If your proxy is on a public address or you want to restrict it more tightly, enter the proxy IPs or CIDR ranges in `ip_header_trusted_proxies`. Without a proxy set `ip_header: none`.

### Local and external access

**Local (LAN):** The web vault needs a secure context (HTTPS). Registration and login do not work in the browser via `http://<HA-Host>:7277`. Two ways:

- **`ssl: true`:** Certificate and key live in `/ssl`, access goes through `https://<HA-Host>:7277`. With a self-signed certificate, confirm the browser warning.
- **Reverse proxy with a local DNS rewrite:** A domain like `vault.example.com` points to the HA host in the local DNS. The proxy (e.g. Nginx Proxy Manager) terminates HTTPS with a valid certificate and forwards to `http://<HA-Host>:7277`, WebSocket support enabled. Set `domain` to `https://vault.example.com`.

**External (internet):** Recommendation: **OK, but only through the reverse proxy with TLS.** Never expose the app port `7277` directly via port forwarding. In addition:

- Turn `signups_allowed` off as soon as the accounts have been created.
- Do not make the admin panel (`/admin`) publicly reachable: leave `admin_token` empty if it is not needed, or restrict `/admin` in the proxy to LAN or VPN.
- Enable two-factor login for all accounts.

### Privacy of external services

- `push_enabled`: push runs through the Bitwarden relay (external service, device metadata goes there). Installation ID and key come from bitwarden.com/host; `push_region` must match the region of the keys.
- `icon_service: bitwarden` redirects clients to Bitwarden; `internal` fetches favicons directly from the sites. `disable_icon_download` switches off every fetch.
- `hibp_api_key` enables leak checks at haveibeenpwned.com.

### Removed feature flags

Vaultwarden 1.37.4 removed several entries from `experimental_client_feature_flags`; if the list still contains them, saving in the admin panel fails. The app filters these flags out at startup and writes a warning to the log.

### Data, backup and restore

All data (SQLite database, RSA keys, attachments, sends, `config.json`) lives under `/data/vaultwarden`. The app uses SQLite only. Home Assistant backups are configured as **cold**: the app is stopped briefly for the backup so the database is consistent. The icon cache and temp files are excluded from the backup. Restore: restore the backup in Home Assistant and start the app.

### Security

- After initialization the app runs as the unprivileged user `vaultwarden` and is restricted by an AppArmor profile.
- Enable `smtp_accept_invalid_certs`, `smtp_accept_invalid_hostnames` and `sso_allow_unknown_email_verification` only in an emergency.
- The values in `extra_env` are visible in plain text in the app configuration – do not enter secrets there; use the password fields for that.
