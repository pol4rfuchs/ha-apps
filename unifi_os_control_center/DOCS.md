# UniFi OS Control Center – Documentation

This guide starts from zero and explains how to install, configure, connect, and troubleshoot the Home Assistant app.

> **Current status:** Experimental. Version 0.7.2 provides live UniFi inventory, device-health monitoring, persistent alerts, optional ntfy delivery, firewall capability detection, read-only firewall diagnostics and analysis, and local policy snapshots where Zone-Based Firewall is available. Firewall mutations remain safety-gated.

## 1. What you need

Before installation, make sure you have:

- Home Assistant OS with access to the Apps/Add-ons section.
- A supported `aarch64` or `amd64` host.
- A UniFi OS console or UniFi Network Server reachable from the Home Assistant host.
- The local HTTPS address of the UniFi console.
- A dedicated UniFi API key.
- Network routing and firewall rules that allow Home Assistant to reach the UniFi console over HTTPS.

Typical supported UniFi OS devices include Cloud Gateways such as UDM Pro/SE, UCG models, Cloud Gateway Max, and other consoles running the current UniFi Network application. Actual API coverage depends on the installed UniFi Network version.

## 2. Installation

### 2.1 Installation from the `ha-apps` repository

After the app has been published in the repository:

1. Open **Settings → Apps/Add-ons → App Store/Add-on Store**.
2. Add the `pol4rfuchs/ha-apps` repository if it is not already installed.
3. Reload the store.
4. Open **UniFi OS Control Center**.
5. Select **Install**.

### 2.2 Local installation for development or testing

For a local HAOS build, place the complete app directory here:

```text
/addons/unifi_os_control_center/
```

The files must be located directly inside that directory:

```text
/addons/unifi_os_control_center/config.yaml
/addons/unifi_os_control_center/Dockerfile
/addons/unifi_os_control_center/apparmor.txt
/addons/unifi_os_control_center/rootfs/
/addons/unifi_os_control_center/backend/
/addons/unifi_os_control_center/frontend/
```

Do not create an extra nested directory such as:

```text
/addons/unifi_os_control_center/unifi-os-control-center-v0.7.2/config.yaml
```

For a local source build, remove or comment out the `image:` line in `config.yaml`:

```yaml
# image: "ghcr.io/pol4rfuchs/unifi_os_control_center"
```

With `image:` enabled, Home Assistant expects a prebuilt image from GHCR. Without it, the Supervisor builds the app locally from the Dockerfile.

After copying the files:

1. Open the App/Add-on Store.
2. Open the three-dot menu.
3. Select **Check for updates** or reload the store.
4. Find **UniFi OS Control Center** under local apps/add-ons.
5. Select **Install**.

The frontend is shipped as a committed, prebuilt `frontend/dist/` artifact. The local HAOS build installs only the pinned Python runtime dependencies and copies the prepared frontend; it does not run npm on the HAOS host.

## 3. Find the local UniFi controller URL

Use the local HTTPS address that opens the UniFi OS console in your browser while you are connected to the same network.

Examples:

```text
https://192.0.2.10
https://unifi.example.internal
https://gateway.example.internal
```

Use your actual address. Do not append `/network`, `/manage`, `/proxy/network`, or an API path. The app adds the required API path itself.

Recommended:

```text
https://<local-console-hostname-or-IP>
```

Not recommended:

```text
https://unifi.ui.com
https://<console>/network/default/dashboard
https://<console>/proxy/network/integration/v1
```

### Reachability check

The Home Assistant host—not only your Windows PC—must be able to reach this URL. If Home Assistant and UniFi are in different VLANs, permit HTTPS traffic from the HAOS network to the UniFi console.

The current app connects to:

```text
<controller_url>/proxy/network/integration/v1/
```

Therefore, the local UniFi Network integration API must be available on the console.

## 4. Create a UniFi API key

The exact menu names can vary slightly with the installed UniFi Network version.

1. Sign in directly to the local UniFi console.
2. Open the **Network** application.
3. Open **Settings**.
4. Open **Integrations**. On some versions this appears under **Control Plane → Integrations**.
5. Open the local API documentation or API-key section.
6. Create a new API key dedicated to this app.
7. Give it a recognizable name, for example:

```text
Home Assistant – UniFi OS Control Center
```

8. Copy the generated key immediately.
9. Store it temporarily in a password manager until it has been entered into Home Assistant.

The app sends the key in the HTTP header:

```text
X-API-Key: <your-api-key>
```

Do not use your UniFi account password in the `api_key` field.

### Recommended key policy

- Create a separate key for this app.
- Do not reuse a key used by scripts or other integrations.
- Begin with the least privilege available.
- Revoke and replace the key if it appears in logs, screenshots, Git commits, or support bundles.
- Keep `read_only: true` until write functions are deliberately enabled and tested.

## 5. Configure the app

Open:

```text
Settings → Apps/Add-ons → UniFi OS Control Center → Configuration
```

A safe initial configuration is:

```yaml
controller_url: "https://your-unifi-console"
api_key: "paste-the-dedicated-api-key-here"
verify_tls: true
read_only: true
polling_interval: 15
history_retention_days: 30
max_history_rows: 100000
log_level: "INFO"
```

Save the configuration and restart the app after changing connection settings.

## 6. Configuration reference

### `controller_url`

The local HTTPS base URL of the UniFi OS console.

```yaml
controller_url: "https://your-unifi-console"
```

Rules:

- Use `https://`.
- Do not add a trailing slash.
- Do not add a dashboard or API path.
- Prefer a stable local DNS name or a fixed IP address.
- The address must be reachable from HAOS.

### `api_key`

A dedicated key generated by the UniFi Network integration API.

```yaml
api_key: "your-generated-key"
```

The field uses Home Assistant's protected `password` schema. The backend does not return the key through its configuration endpoint, and the frontend does not display it.

Changing or revoking the key requires updating this field and restarting the app.

### `verify_tls`

Controls HTTPS certificate verification.

```yaml
verify_tls: true
```

Keep this enabled when the console uses a certificate trusted by the app container.

Use this only for a controlled local test with an untrusted or self-signed certificate:

```yaml
verify_tls: false
```

Disabling verification removes protection against certificate impersonation. It should not be treated as the permanent solution. A trusted local certificate or internal CA is preferable.

### `read_only`

Controls whether potentially modifying API methods are allowed.

```yaml
read_only: true
```

When enabled, the backend rejects every outgoing method except:

```text
GET
HEAD
OPTIONS
```

This guard runs before the request reaches UniFi. Keep it enabled during initial setup and monitoring-only operation.

Setting the value to `false` only removes the local method guard. It does not automatically grant permissions that the API key or UniFi endpoint does not have. Version 0.7.2 exposes read endpoints and keeps all UniFi mutations behind explicit backend safety gates.

### `polling_interval`

Time in seconds between automatic site-data polls.

```yaml
polling_interval: 15
```

Allowed range:

```text
5–300 seconds
```

Recommendations:

- `15`: balanced default.
- `30–60`: lower resource and API usage.
- `5–10`: faster refresh, but more requests and CPU activity.

### `history_retention_days`

Maximum age of telemetry rows stored in the local SQLite database.

```yaml
history_retention_days: 30
```

Allowed range:

```text
1–365 days
```

Rows older than this limit are removed by the cleanup routine.

### `max_history_rows`

Hard upper limit for stored telemetry rows.

```yaml
max_history_rows: 100000
```

Allowed range:

```text
1,000–1,000,000 rows
```

Cleanup applies both limits:

1. Rows older than `history_retention_days` are deleted.
2. If the database still exceeds `max_history_rows`, the oldest remaining rows are deleted.

This prevents unlimited database growth.

### `log_level`

Controls application log verbosity.

```yaml
log_level: "INFO"
```

Available values:

```text
DEBUG
INFO
WARNING
ERROR
```

Use `DEBUG` only for troubleshooting. Debug logs can be significantly more verbose.

## 7. First start

Use this sequence after installation:

1. Configure `controller_url`.
2. Enter the dedicated `api_key`.
3. Leave `verify_tls: true` initially.
4. Leave `read_only: true`.
5. Save the configuration.
6. Start or restart the app.
7. Open the **Log** tab.
8. Confirm that the backend starts without a Python, permission, or AppArmor error.
9. Open the Web UI using **Open Web UI**.
10. Run the connection test from the dashboard.

A successful test should report that the connection worked and return the number of sites visible to the API key.

## 8. What a successful connection means

The connection test requests the site list from the local UniFi Network API.

Success confirms that:

- HAOS can resolve and reach the controller URL.
- HTTPS negotiation succeeded, or TLS verification was deliberately disabled.
- The API key was accepted.
- The local Network integration API exists on the installed UniFi version.
- The key can read at least the site endpoint.

It does not yet prove that every future Protect, Identity, firewall, firmware, or write endpoint is available. Those modules will require their own capability checks as they are implemented.

## 9. Current API endpoints

The app currently provides these internal endpoints:

```text
GET /api/health
GET /api/config/status
GET /api/unifi/test
GET /api/unifi/sites
GET /api/unifi/sites/{site_id}/devices
GET /api/unifi/sites/{site_id}/clients
```

These endpoints are consumed by the local web interface. They are not intended to expose the API key.

## 10. Storage and backups

Telemetry is stored in SQLite using WAL mode. The persistent app data is located in the Home Assistant app/add-on configuration data area mapped into the container.

The app declares hot-backup support. Home Assistant backups should include the persistent app data without requiring the app to be permanently stopped.

Before a restore or migration:

- Create a current Home Assistant backup.
- Record the controller URL.
- Ensure the API key can be recreated or securely recovered.
- After restoring, verify network routing and DNS from the new HAOS host.

API keys may need to be revoked and recreated after a security incident or environment migration.

## 11. Network and VLAN requirements

The app does not require host networking. It uses normal outbound HTTPS from its container.

If Home Assistant and the UniFi console are separated by VLAN rules, allow:

```text
Source:      Home Assistant OS / app network
Destination: UniFi OS console
Protocol:    TCP
Port:        HTTPS port used by the console, normally 443
Direction:   HAOS → UniFi console
```

Avoid opening the UniFi management interface to untrusted networks or the public internet only to make this app work.

When using a hostname, the app container must also be able to resolve it through the DNS service available to HAOS.

## 12. Troubleshooting

### App does not appear under local apps/add-ons

Check:

- The directory is exactly `/addons/unifi_os_control_center/`.
- `config.yaml` is directly inside that directory.
- The folder is not nested twice.
- The `image:` line was removed or commented for a local source build.
- The App/Add-on Store was reloaded.
- The architecture is `aarch64` or `amd64`.

### Local installation tries to pull from GHCR

Cause:

```yaml
image: "ghcr.io/pol4rfuchs/unifi_os_control_center"
```

is still active.

For a local source build, comment it out and reload the store:

```yaml
# image: "ghcr.io/pol4rfuchs/unifi_os_control_center"
```

### `401 Unauthorized` or `403 Forbidden`

Check:

- The API key was copied completely.
- No spaces or line breaks were added.
- The key was created for the correct UniFi account, organization, or console.
- The key has not been revoked.
- The local Network API allows access to the requested console and site.
- You entered an API key, not an account password.

Create a new dedicated key if the original key cannot be verified safely.

### `404 Not Found`

Likely causes:

- The URL includes an unnecessary path such as `/network` or `/manage`.
- The installed UniFi Network version does not expose the expected integration endpoint.
- `controller_url` points to the wrong host or reverse-proxy route.

Use only the console base URL and check **Network → Settings → Integrations** for the API documentation supplied by your installed version.

### `502 Bad Gateway` in the app UI

The app returns `502` when the request to UniFi failed. The response detail and app log should contain the underlying cause, such as DNS failure, refused connection, timeout, TLS error, or an upstream HTTP error.

### Certificate verification failed

Preferred fixes:

- Use a hostname matching the certificate.
- Install a certificate from a trusted CA.
- Use a properly configured internal CA.
- Correct the certificate chain on the UniFi console or reverse proxy.

Temporary diagnostic setting:

```yaml
verify_tls: false
```

Re-enable verification after the certificate issue is resolved.

### Connection timeout or refused connection

Check:

- The console is online.
- The URL and port are correct.
- HAOS can route to the UniFi VLAN.
- Firewall rules allow TCP/443 or the configured HTTPS port.
- DNS resolves the hostname from the HAOS network.
- No reverse proxy requires interactive login before forwarding API requests.

### Connection works from a PC but not from the app

A PC test does not prove container reachability. Common causes include:

- Different DNS servers.
- Inter-VLAN firewall rules.
- A hostname available only through the PC's local hosts file.
- Client-certificate requirements.
- A reverse proxy allowlist that excludes the HAOS address.

### No sites are returned

Check:

- The API key has access to the intended console/site.
- The Network application is installed and running.
- The account or organization associated with the key can see that site.
- The app log does not show a schema or API-version mismatch.

### App repeatedly logs polling failures

The background poller continues running after a failed request and retries at the configured interval. Fix the root connection or authentication error rather than reducing the interval.

For troubleshooting, use:

```yaml
log_level: "DEBUG"
polling_interval: 30
```

After diagnosis, return the log level to `INFO`.

### UI opens but values look incomplete

Version 0.7.2 is an experimental but functional monitoring milestone. Inventory, alerts, ntfy delivery, device-health transitions, and supported firewall read functions are live; destructive UniFi mutations are not enabled by default.

## 13. Security notes

- The app is designed for local operation.
- The web UI is only reachable through Home Assistant Ingress. The app has no login of its own and rejects every connection that does not come from the Home Assistant Ingress gateway, so no host port is published.
- Do not expose the app's ingress or UniFi management interface directly to the public internet.
- Keep `read_only: true` unless management actions are intentionally being tested.
- Keep `verify_tls: true` whenever possible.
- Use a unique API key.
- Never commit `options.json`, API keys, passwords, backups, or debug bundles containing credentials to Git.
- Revoke a key immediately if it has been disclosed.
- Review app permissions before enabling future management modules.

## 14. Privacy

The web interface uses locally bundled assets only:

- No Google Fonts.
- No external JavaScript CDN.
- No analytics.
- No tracking pixels.
- No cloud connection required for normal local operation.

Browser requests remain between Home Assistant, this app, and the configured local UniFi console unless you deliberately configure an external address.

## 15. Recommended initial settings

For a first installation:

```yaml
controller_url: "https://your-local-unifi-console"
api_key: "your-dedicated-api-key"
verify_tls: true
read_only: true
polling_interval: 15
history_retention_days: 30
max_history_rows: 100000
log_level: "INFO"
```

Only change one security-sensitive setting at a time. Test the connection before enabling additional functionality.

## 16. Information to include in a bug report

Provide:

- App version.
- HAOS and Supervisor versions.
- Host architecture: `aarch64` or `amd64`.
- UniFi OS console model.
- UniFi OS version.
- UniFi Network application version.
- Whether the controller URL is an IP, local DNS name, or reverse-proxy name.
- Whether `verify_tls` is enabled.
- Whether `read_only` is enabled.
- The relevant app log section.
- The exact action that failed.

Remove or mask:

- API keys.
- Passwords.
- Public and private hostnames that identify your deployment.
- Public IP addresses.
- Internal IP addresses when posting publicly.
- MAC addresses, device names, SSIDs, and client identities.


## Firewall analysis and snapshots (v0.4.0)

The analysis engine runs only when the selected site exposes the official Zone-Based Firewall API. It is conservative and advisory. Findings never trigger automatic changes.

Snapshots store the policies and zones returned by the official API in `/data/unifi_control_center.db` using SQLite WAL mode. Each snapshot records the site ID, policy and zone counts, an optional note, and a SHA-256 integrity hash. Snapshot comparison reports added, removed, and changed policy records.

On legacy firewall sites, analysis and snapshot creation remain unavailable until the site is migrated to Zone-Based Firewall. The app does not use undocumented legacy endpoints as a fallback.


## Firewall write-safety controls (v0.5.0)

The app now exposes separate safety gates for future Zone-Based Firewall mutations. Defaults remain conservative: global read-only mode is enabled and all mutation capabilities are disabled. The **Changes** tab explains every blocking condition. No undocumented legacy firewall endpoint is used.

```yaml
read_only: true
allow_firewall_write: false
allow_firewall_delete: false
allow_policy_reorder: false
require_change_confirmation: true
create_prechange_snapshot: true
```

Changing these options alone does not make legacy firewall sites writable. Official mutation forms remain hidden until a Zone-Based Firewall environment can be validated end-to-end.


## Notifications and ntfy

Version 0.6.0 can store runtime alerts in SQLite and optionally forward selected events to ntfy. Configure the following values in the Home Assistant app configuration:

```yaml
ntfy_enabled: true
ntfy_url: "https://your-ntfy-server.example"
ntfy_topic: "ha-alerts"
ntfy_token: ""
notify_on_connection_failure: true
notify_on_connection_recovery: true
notify_on_new_client: true
notification_cooldown: 900
```

The token is optional and uses the protected Home Assistant password field. The browser never receives the token. The cooldown applies per event key and prevents repeated notification storms. The first client inventory after app start establishes the baseline and does not send a notification for every existing client.

Use **Alerts → Test ntfy** after restarting the app. Persistent alerts remain available even when ntfy is disabled or temporarily unreachable.


## Alert exports

The Alerts page can export the bounded SQLite alert history as JSON or CSV. Exports contain event IDs, timestamps, severity, source, message, and acknowledgement state. They do not contain the UniFi API key, ntfy token, or app configuration secrets. The configured `max_history_rows` limit is applied to alerts as well as telemetry and firewall snapshots.


## Device health monitoring

Version 0.7.2 monitors only UniFi devices for which the official Network API returns an explicit online/offline state. Devices without an explicit state are not guessed and do not generate alerts.

```yaml
notify_on_device_offline: true
notify_on_device_recovery: true
device_offline_grace_polls: 2
```

`device_offline_grace_polls` requires the device to be reported offline for the configured number of consecutive polling cycles before an alert is created. With the default 15-second polling interval and two grace polls, the effective delay is approximately 30 seconds. Recovery is reported when the API explicitly reports the device online again. Alerts are stored in SQLite and optionally delivered through ntfy when enabled.
