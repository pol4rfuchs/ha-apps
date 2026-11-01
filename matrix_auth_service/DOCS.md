# Matrix Auth Service (MAS)

Next-gen authentication for Matrix Synapse via OIDC/OAuth2. Prerequisite
for Element X QR code login, MFA and further "Matrix 2.0" client features.

## Status

The app is built and published (see CHANGELOG). The items below are still
open, above all AppArmor: `apparmor.txt` is missing and `apparmor: false`
is set.

## Requirements

- An already running Matrix Synapse add-on with **Simplified Sliding
  Sync** support (natively available since Synapse 1.114)
- Own subdomain for the account UI (e.g. `account.example.org`)
- A fresh start is recommended: existing accounts are **not** migrated
  automatically (no `syn2mas` step is built into this add-on)

## Setup

1. Install the add-on, set `mas_domain`, `synapse_server_name`,
   `synapse_endpoint`
2. Leave `synapse_secret` empty → it is generated automatically on the first
   start (the value appears in the log and under `/data/mas/.synapse_secret`)
3. Copy the generated secret value into the Synapse add-on:
   `mas_enabled: true`, `mas_secret: <value>`, `mas_endpoint: http://[HA-IP]:8082`
4. Restart both add-ons

## Open items (before production use)

- [ ] First build + test run (Postgres init, `mas-cli database migrate`,
      `mas-cli config sync`)
- [x] `icon.png` / `logo.png` (icon derived from the logo, replace if needed)
- [ ] `apparmor.txt`
- [x] Reverse proxy route for `mas_domain` in NPM: see the section *Local and external access*
- [ ] Check: is `password_login_enabled: true` enough as a fallback, or should
      MAS run with an upstream OIDC provider only from the start?

## Local and external access

**Local (LAN):** The account UI runs on port `8082` (`http://<HA-Host>:8082`). MAS uses `https://<mas_domain>/` as its public address (issuer). The login flow therefore only works through this HTTPS domain, not through the bare LAN IP. It becomes usable locally with a DNS rewrite on the local DNS server pointing to the HA host, plus a reverse proxy with a certificate.

**Reverse proxy route (e.g. Nginx Proxy Manager):** new proxy host with domain = `mas_domain`, scheme `http`, forward host = HA host, port `8082`. Request a certificate and enable "Force SSL". Port `8083` (health check only) does not belong in the proxy.

**External (internet):** Recommendation: **OK, but only through the reverse proxy with TLS** (Matrix clients need the public address). Never expose ports `8082` and `8083` directly. `password_registration_enabled` stays off (default).
