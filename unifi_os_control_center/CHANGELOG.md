# Changelog


## 0.7.2

- Make the SPA entry point robust under Home Assistant Ingress on mobile and WebView clients.
- Read and validate the `X-Ingress-Path` header and inject a dynamic HTML `<base>` element.
- Remove dependency on trailing-slash normalization for JavaScript and CSS asset loading.
- Disable caching of the dynamically generated SPA entry document.
- Harden the SPA fallback against path traversal and return a clear error when the frontend bundle is missing.

## 0.7.1

- Re-enable and retain AppArmor confinement as the supported default.
- Fix English and German translation nesting for device offline/recovery options.
- Treat `frontend/dist/` as an intentional committed artifact for deterministic local HAOS builds.
- Add the formal `ARG BUILD_FROM` override pattern while retaining the multi-architecture Home Assistant base image.
- Pin all frontend dependencies and sanitize the lockfile registry metadata for reproducible public builds.
- Remove generated Python bytecode and cache directories from the release archive.
- Refresh README and DOCS for the actual v0.7 feature scope.
- Clean the frontend distribution before packaging and retain only the current hashed JS/CSS assets.

## 0.7.0

- Add read-only UniFi device health monitoring to the background poller.
- Detect explicit online-to-offline and offline-to-online device transitions.
- Add configurable offline grace polling to reduce transient false positives.
- Persist device offline and recovery events in the SQLite alert history.
- Add optional ntfy notifications for device offline and recovery events.
- Add a runtime operations status endpoint and device-health summary on the Overview page.
- Keep devices without an explicit API state out of transition monitoring.

## 0.6.3

- Add persistent alert statistics for open, acknowledged, severity, and source counts.
- Add JSON and CSV exports for the bounded alert history.
- Add an alert-source filter to the Alerts page.
- Apply the configured maximum-row limit to alerts as well as other SQLite histories.
- Keep alert exports local and exclude credentials or configuration secrets.

## 0.6.2

- Fix alert acknowledgement and deletion failures caused by temporary decimal frontend IDs.
- Persist manual connection-test results in SQLite and reload alerts from the backend after alert actions.
- Ensure every actionable alert uses a stable integer database ID.
- Refresh alert state after acknowledge, acknowledge-all, delete, and ntfy test operations.

## 0.6.1

- Add alert acknowledgement for individual events and all outstanding events.
- Add deletion of individual alert records without clearing the complete history.
- Sort unacknowledged alerts before acknowledged history entries.
- Add alert severity and acknowledgement filters to the Alerts page.
- Improve persistent alert lifecycle handling in SQLite.


## 0.6.0

- Add persistent runtime alerts stored in SQLite.
- Add optional ntfy delivery to the configured `ha-alerts` topic.
- Add notifications for UniFi connection failure, recovery, and newly detected clients.
- Add configurable cooldown and bounded in-memory de-duplication for repeated alerts.
- Add ntfy test actions to Alerts and Settings.
- Keep API keys and ntfy tokens masked and out of frontend responses.

## 0.5.0

- Add a controlled firewall write-safety framework without exposing unvalidated mutation forms.
- Add independent gates for global read-only mode, firewall writes, deletion, and policy reordering.
- Add mandatory confirmation and pre-change snapshot settings.
- Add a Firewall **Changes** page showing readiness, blocked reasons, and the required mutation workflow.
- Keep all official write operations unavailable on legacy firewall sites.

## 0.4.0

- Add conservative read-only firewall policy analysis with a transparent health score.
- Detect broad allow rules, Any-to-Any policies, duplicate definitions, missing descriptions, and allow rules without logging.
- Add local firewall policy snapshots stored in SQLite WAL mode.
- Add snapshot metadata, SHA-256 integrity hashes, optional notes, and snapshot-to-snapshot diffing.
- Keep all UniFi firewall write operations blocked.
- Degrade safely on legacy firewall sites where Zone-Based Firewall is not configured.

## 0.3.2

- Detect the UniFi legacy firewall model from `api.firewall.zone-based-firewall-not-configured`.
- Replace the generic red API failure with a clear legacy-firewall status message.
- Distinguish legacy, Zone-Based, and unknown firewall capability states.
- Explain why official Policies, Zones, and Ordering endpoints are unavailable on legacy sites.
- Keep technical diagnostics available but collapsed when the legacy condition is already understood.
- Avoid misleading empty-policy and empty-zone states when Zone-Based Firewall is not configured.
- Continue blocking all firewall write operations and undocumented legacy API fallbacks.

## 0.3.1

- Add read-only firewall API diagnostics for the reported UniFi Network API `10.4.57` and UniFi OS `5.1.15` environment.
- Preserve HTTP status, response body, selected response headers, request method, and sanitized request URL.
- Test paged and unpaged variants of the firewall policy and zone list endpoints.
- Add explicit `offset=0` and `limit=200` pagination to normal firewall list requests.
- Separate failed API requests from valid empty results in the firewall UI.
- Add a dedicated Diagnostics tab for copying and reviewing UniFi API responses.
- Keep all firewall write operations blocked.

## 0.3.0

- Add read-only firewall policy inventory through the official UniFi Network API.
- Add firewall zone inventory and capability detection.
- Add policy filtering, detail views, and raw API inspection.
- Detect policy, zone, and ordering read support without enabling write operations.
- Keep all create, update, delete, and reorder operations blocked for the v0.3.0 milestone.

## 0.2.3

- Fix client detail selection by adding an explicit **Details** button to every client inventory row.
- Preserve whole-row click behavior while providing a reliable dedicated click target.
- Improve keyboard accessibility for opening device and client detail views.

## 0.2.2

- Add clickable gateway, access point, client, firmware, and site inventory entries.
- Add side-panel detail views using fields returned by the UniFi API.
- Add a complete raw-data view with **Copy raw JSON** support.
- Add text and status filters to inventory pages.
- Add local alert history for connection tests, API errors, and site-loading failures.
- Add an alert counter in the sidebar and a **Clear all** action.
- Add dismissible success and error banners.
- Improve empty states, table handling, and mobile layouts.

## 0.2.1

- Expand the read-only category pages.
- Add explicit TP-Link and non-UniFi switch handling.
- Show a clear empty state when no UniFi switch is detected.
- Add firmware inventory using device data returned by the API.
- Add Firewall, Protect, Backups, Alerts, and Settings readiness pages.
- Replace locked pages with usable read-only information and availability states.

## 0.2.0

- Add functional sidebar navigation and page switching.
- Load real UniFi sites, devices, and clients through the backend.
- Add inventory tables, site selector, search, refresh, loading, success, and error states.
- Keep destructive modules visibly locked until write-safety controls are implemented.

## 0.1.5

- Fix the blank Home Assistant Ingress page by using relative frontend asset URLs.
- Add a persistent Vite `base: "./"` setting for future frontend builds.

## 0.1.4

- Align Ingress, watchdog, Uvicorn, and Docker metadata on internal port `8599`.
- Prevent Ingress `502 Bad Gateway` errors caused by mixed internal port configuration.

## 0.1.3

- Fix AppArmor startup denial by granting read-and-execute access to `/init` and the s6-overlay bootstrap paths.
- Remove generated Python bytecode caches from the distribution archive.

## 0.1.2

- Fix local HAOS builds on `aarch64` by shipping the prebuilt frontend.
- Remove the Node/npm build stage that failed with `Exit handler never called`.
- Eliminate the invalid `npm ci --omit=dev=false` invocation.

## 0.1.1

- Fix local HAOS builds by using the official multi-architecture `base-python` image directly.
- Remove the invalid nested `BUILD_ARCH` expansion from `BUILD_FROM`.

## 0.1.0

- Add the initial experimental architecture and dashboard.
