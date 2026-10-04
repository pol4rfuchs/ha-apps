from __future__ import annotations

import asyncio
import csv
import io
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from .settings import Settings
from .notifications import NotificationManager
from .firewall_analysis import analyze_firewall, canonical_snapshot, snapshot_diff
from .storage import (
    cleanup,
    create_firewall_snapshot,
    get_firewall_snapshot,
    init_db,
    list_firewall_snapshots,
    save_snapshot,
    add_alert,
    list_alerts,
    clear_alerts,
    acknowledge_alert,
    acknowledge_all_alerts,
    delete_alert,
    alert_stats,
)
from .unifi import UniFiAPIError, UniFiClient

settings = Settings.load()
logging.basicConfig(level=getattr(logging, settings.log_level, logging.INFO))
logger = logging.getLogger("unifi-control")
notifier = NotificationManager(settings)
runtime_status: dict[str, Any] = {
    "last_poll_at": None,
    "connection_ok": False,
    "tracked_devices": 0,
    "offline_devices": 0,
    "device_health_initialized": False,
}

def _device_key(item: dict[str, Any]) -> str:
    return str(item.get("id") or item.get("macAddress") or item.get("mac") or "")

def _device_name(item: dict[str, Any]) -> str:
    return str(item.get("name") or item.get("displayName") or item.get("hostname") or item.get("model") or _device_key(item) or "Unknown device")

def _explicit_online(item: dict[str, Any]) -> bool | None:
    for key in ("online", "isOnline", "connected", "active"):
        value = item.get(key)
        if isinstance(value, bool):
            return value
        if value in (0, 1):
            return bool(value)
    for key in ("state", "status", "connectionState"):
        value = item.get(key)
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"online", "connected", "up", "active", "ready"}:
                return True
            if normalized in {"offline", "disconnected", "down", "inactive", "unreachable"}:
                return False
    return None

async def poller(stop: asyncio.Event) -> None:
    client = UniFiClient(settings)
    connection_failed = False
    seen_clients: set[str] = set()
    initialized_clients = False
    device_states: dict[str, bool] = {}
    offline_counts: dict[str, int] = {}
    initialized_devices = False
    while not stop.is_set():
        try:
            sites = await client.sites()
            save_snapshot("sites", sites)
            site_rows = _rows(sites)
            if connection_failed:
                add_alert("success", "poller", "UniFi console connection recovered")
                if settings.notify_on_connection_recovery:
                    await notifier.send(key="connection-recovery", title="UniFi connection restored", message="The UniFi OS console is reachable again.", priority="default", tags="white_check_mark")
                connection_failed = False
            runtime_status["connection_ok"] = True
            runtime_status["last_poll_at"] = int(time.time())
            if site_rows:
                current_site_id = str(site_rows[0].get("id") or site_rows[0].get("siteId") or "")
                if current_site_id:
                    device_payload = await client.devices(current_site_id)
                    save_snapshot("devices", device_payload)
                    current_devices = _rows(device_payload)
                    explicit_devices = {
                        _device_key(item): (item, _explicit_online(item))
                        for item in current_devices
                        if _device_key(item) and _explicit_online(item) is not None
                    }
                    if not initialized_devices:
                        device_states = {key: bool(state) for key, (_, state) in explicit_devices.items()}
                        initialized_devices = True
                    else:
                        for key, (record, state_value) in explicit_devices.items():
                            state = bool(state_value)
                            previous = device_states.get(key)
                            if previous is None:
                                device_states[key] = state
                                offline_counts.pop(key, None)
                                continue
                            if not state and previous:
                                offline_counts[key] = offline_counts.get(key, 0) + 1
                                if offline_counts[key] >= settings.device_offline_grace_polls:
                                    name = _device_name(record)
                                    add_alert("error", "device-health", f"UniFi device offline: {name}")
                                    if settings.notify_on_device_offline:
                                        await notifier.send(key=f"device-offline:{key}", title="UniFi device offline", message=f"{name} is offline.", priority="high", tags="warning")
                                    device_states[key] = False
                                    offline_counts.pop(key, None)
                            elif state and not previous:
                                name = _device_name(record)
                                add_alert("success", "device-health", f"UniFi device recovered: {name}")
                                if settings.notify_on_device_recovery:
                                    await notifier.send(key=f"device-recovery:{key}", title="UniFi device recovered", message=f"{name} is online again.", priority="default", tags="white_check_mark")
                                device_states[key] = True
                                offline_counts.pop(key, None)
                            elif state:
                                offline_counts.pop(key, None)
                    runtime_status["tracked_devices"] = len(device_states)
                    runtime_status["offline_devices"] = sum(1 for state in device_states.values() if not state)
                    runtime_status["device_health_initialized"] = initialized_devices

                    client_payload = await client.clients(current_site_id)
                    current_clients = _rows(client_payload)
                    current_ids = {str(item.get("id") or item.get("macAddress") or item.get("mac") or "") for item in current_clients}
                    current_ids.discard("")
                    if initialized_clients and settings.notify_on_new_client:
                        for client_id in sorted(current_ids - seen_clients)[:10]:
                            record = next((item for item in current_clients if client_id in {str(item.get("id") or ""), str(item.get("macAddress") or ""), str(item.get("mac") or "")}), {})
                            name = str(record.get("name") or record.get("displayName") or record.get("hostname") or client_id)
                            add_alert("info", "clients", f"New client detected: {name}")
                            await notifier.send(key=f"new-client:{client_id}", title="New UniFi client", message=f"A new client was detected: {name}", priority="default", tags="new")
                    seen_clients = current_ids
                    initialized_clients = True
                    if len(seen_clients) > 4096:
                        seen_clients = set(sorted(seen_clients)[:4096])
            cleanup(settings.history_retention_days, settings.max_history_rows)
        except Exception as exc:  # polling must never crash the app
            runtime_status["connection_ok"] = False
            runtime_status["last_poll_at"] = int(time.time())
            logger.warning("Polling failed: %s", exc)
            if not connection_failed:
                add_alert("error", "poller", f"UniFi polling failed: {exc}")
                if settings.notify_on_connection_failure:
                    try:
                        await notifier.send(key="connection-failure", title="UniFi connection failed", message=f"The UniFi OS console could not be reached: {exc}", priority="high", tags="warning")
                    except Exception as notify_exc:
                        logger.warning("ntfy notification failed: %s", notify_exc)
                connection_failed = True
        try:
            await asyncio.wait_for(stop.wait(), timeout=settings.polling_interval)
        except asyncio.TimeoutError:
            pass

@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    stop = asyncio.Event()
    task = asyncio.create_task(poller(stop), name="unifi-poller")
    yield
    stop.set()
    await task

app = FastAPI(title="UniFi OS Control Center", version="0.7.3", lifespan=lifespan)  # x-release-please-version

# Home Assistant Ingress is the only supported entry point: the Supervisor
# proxies authenticated users from 172.30.32.2. The app has no login of its own,
# so any other peer (e.g. a LAN client hitting a mapped host port) is rejected.
_INGRESS_PEERS = frozenset({"172.30.32.2", "127.0.0.1", "::1"})
_rejected_peers: set[str] = set()


@app.middleware("http")
async def ingress_peer_guard(request: Request, call_next: Any) -> Response:
    peer = request.client.host if request.client else ""
    if peer not in _INGRESS_PEERS:
        if peer not in _rejected_peers and len(_rejected_peers) < 64:
            _rejected_peers.add(peer)
            logger.warning("Rejected connection from %s: only the Home Assistant Ingress gateway is allowed", peer or "unknown peer")
        return Response(content="Forbidden", status_code=403, media_type="text/plain")
    return await call_next(request)



def _safe_error(exc: Exception, context: str) -> str:
    """Log the exception server-side and return a generic message for API responses."""
    logger.warning("%s failed", context, exc_info=exc)
    return f"{type(exc).__name__}: request failed, see the app log for details"


def _api_error_detail(exc: Exception) -> Any:
    if isinstance(exc, UniFiAPIError):
        return exc.as_dict()
    return str(exc)


async def _diagnostic_attempt(name: str, operation: Any) -> dict[str, Any]:
    try:
        data = await operation
        count = len(_rows(data))
        return {"name": name, "ok": True, "status_code": 200, "count": count, "data": data}
    except UniFiAPIError as exc:
        return {"name": name, "ok": False, **exc.as_dict()}
    except Exception as exc:
        return {"name": name, "ok": False, "status_code": None, "reason": type(exc).__name__, "response_body": str(exc)}




def _detect_firewall_model(attempts: list[dict[str, Any]]) -> dict[str, Any]:
    legacy_code = "api.firewall.zone-based-firewall-not-configured"
    for attempt in attempts:
        body = attempt.get("response_body")
        if isinstance(body, dict) and body.get("code") == legacy_code:
            return {
                "firewall_model": "legacy",
                "zone_based_configured": False,
                "detection_code": legacy_code,
                "detection_message": str(body.get("message") or "Zone Based Firewall is not configured"),
            }
    if any(attempt.get("ok") for attempt in attempts):
        return {
            "firewall_model": "zone_based",
            "zone_based_configured": True,
            "detection_code": None,
            "detection_message": "Zone-Based Firewall API is available",
        }
    return {
        "firewall_model": "unknown",
        "zone_based_configured": None,
        "detection_code": None,
        "detection_message": "Firewall model could not be determined",
    }

def _rows(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    if isinstance(value, dict):
        for key in ("data", "items", "results"):
            nested = value.get(key)
            if isinstance(nested, list):
                return [item for item in nested if isinstance(item, dict)]
    return []

@app.get("/api/health")
async def health() -> dict[str, Any]:
    return {"status": "ok", "version": "0.7.3", "read_only": settings.read_only}  # x-release-please-version

@app.get("/api/config/status")
async def config_status() -> dict[str, Any]:
    return {
        "controller_configured": bool(settings.controller_url),
        "api_key_configured": bool(settings.api_key),
        "verify_tls": settings.verify_tls,
        "read_only": settings.read_only,
        "allow_firewall_write": settings.allow_firewall_write,
        "allow_firewall_delete": settings.allow_firewall_delete,
        "allow_policy_reorder": settings.allow_policy_reorder,
        "require_change_confirmation": settings.require_change_confirmation,
        "create_prechange_snapshot": settings.create_prechange_snapshot,
        "polling_interval": settings.polling_interval,
        "ntfy_enabled": settings.ntfy_enabled,
        "ntfy_configured": bool(settings.ntfy_url and settings.ntfy_topic),
        "ntfy_topic": settings.ntfy_topic,
        "notify_on_connection_failure": settings.notify_on_connection_failure,
        "notify_on_connection_recovery": settings.notify_on_connection_recovery,
        "notify_on_new_client": settings.notify_on_new_client,
        "notify_on_device_offline": settings.notify_on_device_offline,
        "notify_on_device_recovery": settings.notify_on_device_recovery,
        "device_offline_grace_polls": settings.device_offline_grace_polls,
        "notification_cooldown": settings.notification_cooldown,
    }



@app.get("/api/operations/status")
async def operations_status() -> dict[str, Any]:
    return {**runtime_status, "offline_grace_polls": settings.device_offline_grace_polls}

@app.get("/api/alerts")
async def alerts(limit: int = 100) -> dict[str, Any]:
    items = list_alerts(limit)
    return {"items": items, "count": len(items)}


@app.get("/api/alerts/stats")
async def alerts_stats() -> dict[str, Any]:
    return alert_stats()


@app.get("/api/alerts/export")
async def alerts_export(format: str = "json", limit: int = 500) -> Response:
    items = list_alerts(limit)
    export_format = format.lower().strip()
    if export_format == "json":
        payload = json.dumps({"exported_at": int(__import__("time").time()), "count": len(items), "items": items}, indent=2)
        return Response(
            content=payload,
            media_type="application/json",
            headers={"Content-Disposition": "attachment; filename=unifi-control-alerts.json"},
        )
    if export_format == "csv":
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=["id", "created_at", "level", "source", "message", "acknowledged"])
        writer.writeheader()
        writer.writerows(items)
        return Response(
            content=output.getvalue(),
            media_type="text/csv; charset=utf-8",
            headers={"Content-Disposition": "attachment; filename=unifi-control-alerts.csv"},
        )
    raise HTTPException(status_code=400, detail="format must be json or csv")


@app.delete("/api/alerts")
async def alerts_clear() -> dict[str, Any]:
    return {"ok": True, "deleted": clear_alerts()}


@app.post("/api/alerts/acknowledge-all")
async def alerts_acknowledge_all() -> dict[str, Any]:
    return {"ok": True, "updated": acknowledge_all_alerts()}


@app.post("/api/alerts/{alert_id}/acknowledge")
async def alert_acknowledge(alert_id: int) -> dict[str, Any]:
    if not acknowledge_alert(alert_id):
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"ok": True, "id": alert_id}


@app.delete("/api/alerts/{alert_id}")
async def alert_delete(alert_id: int) -> dict[str, Any]:
    if not delete_alert(alert_id):
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"ok": True, "id": alert_id}


@app.post("/api/notifications/test")
async def notification_test() -> dict[str, Any]:
    if not settings.ntfy_enabled:
        raise HTTPException(status_code=409, detail="ntfy notifications are disabled in the app configuration")
    if not settings.ntfy_url or not settings.ntfy_topic:
        raise HTTPException(status_code=409, detail="ntfy URL or topic is not configured")
    try:
        sent = await notifier.send(key=f"manual-test:{int(asyncio.get_running_loop().time())}", title="UniFi OS Control Center", message="Test notification from Home Assistant OS.", priority="default", tags="test_tube")
        add_alert("success", "ntfy", "ntfy test notification sent")
        return {"ok": sent, "topic": settings.ntfy_topic}
    except Exception as exc:
        add_alert("error", "ntfy", f"ntfy test failed: {exc}")
        raise HTTPException(status_code=502, detail=str(exc)) from exc

@app.get("/api/unifi/test")
async def test_connection() -> dict[str, Any]:
    try:
        data = await UniFiClient(settings).sites()
        count = len(data.get("data", data if isinstance(data, list) else [])) if data else 0
        add_alert("success", "connection-test", f"Connection successful: {count} site(s)")
        return {"ok": True, "site_count": count}
    except Exception as exc:
        add_alert("error", "connection-test", f"Connection failed: {exc}")
        raise HTTPException(status_code=502, detail=str(exc)) from exc

@app.get("/api/unifi/sites")
async def sites() -> Any:
    try:
        return await UniFiClient(settings).sites()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

@app.get("/api/unifi/sites/{site_id}/devices")
async def devices(site_id: str) -> Any:
    try:
        return await UniFiClient(settings).devices(site_id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

@app.get("/api/unifi/sites/{site_id}/clients")
async def clients(site_id: str) -> Any:
    try:
        return await UniFiClient(settings).clients(site_id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

@app.get("/api/unifi/sites/{site_id}/firewall/policies")
async def firewall_policies(site_id: str) -> Any:
    try:
        return await UniFiClient(settings).firewall_policies(site_id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=_api_error_detail(exc)) from exc

@app.get("/api/unifi/sites/{site_id}/firewall/zones")
async def firewall_zones(site_id: str) -> Any:
    try:
        return await UniFiClient(settings).firewall_zones(site_id)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=_api_error_detail(exc)) from exc

@app.get("/api/unifi/sites/{site_id}/firewall/diagnostics")
async def firewall_diagnostics(site_id: str) -> dict[str, Any]:
    client = UniFiClient(settings)
    attempts = [
        await _diagnostic_attempt("policies_paged", client.firewall_policies(site_id, paged=True)),
        await _diagnostic_attempt("policies_unpaged", client.firewall_policies(site_id, paged=False)),
        await _diagnostic_attempt("zones_paged", client.firewall_zones(site_id, paged=True)),
        await _diagnostic_attempt("zones_unpaged", client.firewall_zones(site_id, paged=False)),
    ]
    detection = _detect_firewall_model(attempts)
    return {
        "site_id": site_id,
        "network_api_reported": "Not auto-detected",
        "unifi_os_reported": "Not auto-detected",
        "read_only": settings.read_only,
        **detection,
        "attempts": attempts,
    }


@app.get("/api/unifi/sites/{site_id}/firewall/capabilities")
async def firewall_capabilities(site_id: str) -> dict[str, Any]:
    client = UniFiClient(settings)
    result: dict[str, Any] = {
        "policies_read": False,
        "zones_read": False,
        "ordering_read": False,
        "write_enabled": not settings.read_only,
        "firewall_model": "unknown",
        "zone_based_configured": None,
        "errors": {},
    }
    policies: Any = None
    zones: Any = None
    model_attempts: list[dict[str, Any]] = []
    try:
        policies = await client.firewall_policies(site_id)
        result["policies_read"] = True
        model_attempts.append({"ok": True})
    except UniFiAPIError as exc:
        result["errors"]["policies"] = exc.as_dict()
        model_attempts.append({"ok": False, "response_body": exc.response_body})
    except Exception as exc:
        result["errors"]["policies"] = _safe_error(exc, "firewall policies read")
    try:
        zones = await client.firewall_zones(site_id)
        result["zones_read"] = True
        model_attempts.append({"ok": True})
    except UniFiAPIError as exc:
        result["errors"]["zones"] = exc.as_dict()
        model_attempts.append({"ok": False, "response_body": exc.response_body})
    except Exception as exc:
        result["errors"]["zones"] = _safe_error(exc, "firewall zones read")

    zone_rows = _rows(zones)
    if len(zone_rows) >= 2:
        source_id = str(zone_rows[0].get("id", ""))
        destination_id = str(zone_rows[1].get("id", ""))
        if source_id and destination_id:
            try:
                await client.firewall_ordering(site_id, source_id, destination_id)
                result["ordering_read"] = True
            except Exception as exc:
                result["errors"]["ordering"] = _safe_error(exc, "firewall ordering read")
    if model_attempts:
        result.update(_detect_firewall_model(model_attempts))
    result["policy_count"] = len(_rows(policies))
    result["zone_count"] = len(zone_rows)
    return result



def _legacy_firewall_error(exc: Exception) -> bool:
    if not isinstance(exc, UniFiAPIError):
        return False
    body = exc.response_body
    return isinstance(body, dict) and body.get("code") == "api.firewall.zone-based-firewall-not-configured"


async def _live_firewall_payload(site_id: str) -> tuple[Any, Any]:
    client = UniFiClient(settings)
    try:
        policies, zones = await asyncio.gather(
            client.firewall_policies(site_id),
            client.firewall_zones(site_id),
        )
        return policies, zones
    except Exception as exc:
        if _legacy_firewall_error(exc):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "legacy_firewall_model",
                    "message": "Zone-Based Firewall is not configured; analysis and snapshots are unavailable.",
                },
            ) from exc
        raise HTTPException(status_code=502, detail=_api_error_detail(exc)) from exc



@app.get("/api/unifi/sites/{site_id}/firewall/write-safety")
async def firewall_write_safety(site_id: str) -> dict[str, Any]:
    diagnostics = await firewall_diagnostics(site_id)
    zone_based = diagnostics.get("firewall_model") == "zone_based"
    reasons: list[str] = []
    if settings.read_only:
        reasons.append("Global read_only mode is enabled")
    if not settings.allow_firewall_write:
        reasons.append("allow_firewall_write is disabled")
    if not zone_based:
        reasons.append("Zone-Based Firewall is not configured")
    return {
        "site_id": site_id,
        "firewall_model": diagnostics.get("firewall_model"),
        "zone_based_configured": diagnostics.get("zone_based_configured"),
        "global_read_only": settings.read_only,
        "allow_firewall_write": settings.allow_firewall_write,
        "allow_firewall_delete": settings.allow_firewall_delete,
        "allow_policy_reorder": settings.allow_policy_reorder,
        "require_change_confirmation": settings.require_change_confirmation,
        "create_prechange_snapshot": settings.create_prechange_snapshot,
        "write_ready": not reasons,
        "blocked_reasons": reasons,
        "workflow": [
            "Validate capability and payload",
            "Create pre-change snapshot",
            "Display diff and require explicit confirmation",
            "Apply one supported API mutation",
            "Read back and verify",
            "Write audit record",
        ],
        "implemented_operations": [],
        "note": "v0.5.0 establishes the write-safety boundary. Mutation forms remain unavailable until a Zone-Based Firewall site can be validated end-to-end.",
    }


@app.get("/api/unifi/sites/{site_id}/firewall/analysis")
async def firewall_analysis(site_id: str) -> dict[str, Any]:
    policies, zones = await _live_firewall_payload(site_id)
    return analyze_firewall(policies, zones)


@app.get("/api/unifi/sites/{site_id}/firewall/snapshots")
async def firewall_snapshot_list(site_id: str) -> dict[str, Any]:
    return {"items": list_firewall_snapshots(site_id), "site_id": site_id}


@app.post("/api/unifi/sites/{site_id}/firewall/snapshots")
async def firewall_snapshot_create(site_id: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    policies, zones = await _live_firewall_payload(site_id)
    note = str((body or {}).get("note") or "")
    payload = canonical_snapshot(site_id, policies, zones)
    created = create_firewall_snapshot(site_id, payload, note)
    return {"ok": True, "snapshot": created}


@app.get("/api/unifi/sites/{site_id}/firewall/snapshots/{snapshot_id}")
async def firewall_snapshot_get(site_id: str, snapshot_id: int) -> dict[str, Any]:
    snapshot = get_firewall_snapshot(snapshot_id)
    if snapshot is None or snapshot.get("site_id") != site_id:
        raise HTTPException(status_code=404, detail="Firewall snapshot not found")
    return snapshot


@app.get("/api/unifi/sites/{site_id}/firewall/snapshots/{before_id}/diff/{after_id}")
async def firewall_snapshot_compare(site_id: str, before_id: int, after_id: int) -> dict[str, Any]:
    before = get_firewall_snapshot(before_id)
    after = get_firewall_snapshot(after_id)
    if before is None or after is None or before.get("site_id") != site_id or after.get("site_id") != site_id:
        raise HTTPException(status_code=404, detail="One or both firewall snapshots were not found")
    return snapshot_diff(before["payload"], after["payload"])


frontend = Path("/app/frontend")
if frontend.exists():
    app.mount("/assets", StaticFiles(directory=frontend / "assets"), name="assets")

_FRONTEND_ROOT = os.path.realpath(frontend)

@app.get("/{path:path}")
async def spa(path: str) -> FileResponse:
    # Serve only files that resolve inside the frontend bundle; everything
    # else (including traversal attempts) falls back to the SPA entry point.
    if path and "\x00" not in path:
        full = os.path.realpath(os.path.join(_FRONTEND_ROOT, path))
        if full.startswith(_FRONTEND_ROOT + os.sep) and os.path.isfile(full):
            return FileResponse(full)
    return FileResponse(os.path.join(_FRONTEND_ROOT, "index.html"))
