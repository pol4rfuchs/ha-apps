from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class Settings:
    controller_url: str
    api_key: str
    verify_tls: bool
    read_only: bool
    allow_firewall_write: bool
    allow_firewall_delete: bool
    allow_policy_reorder: bool
    require_change_confirmation: bool
    create_prechange_snapshot: bool
    polling_interval: int
    history_retention_days: int
    max_history_rows: int
    log_level: str
    ntfy_enabled: bool
    ntfy_url: str
    ntfy_topic: str
    ntfy_token: str
    notify_on_connection_failure: bool
    notify_on_connection_recovery: bool
    notify_on_new_client: bool
    notify_on_device_offline: bool
    notify_on_device_recovery: bool
    device_offline_grace_polls: int
    notification_cooldown: int

    @classmethod
    def load(cls) -> "Settings":
        path = Path(os.getenv("APP_OPTIONS_PATH", "/data/options.json"))
        raw = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        return cls(
            controller_url=str(raw.get("controller_url", "")).rstrip("/"),
            api_key=str(raw.get("api_key", "")),
            verify_tls=bool(raw.get("verify_tls", True)),
            read_only=bool(raw.get("read_only", True)),
            allow_firewall_write=bool(raw.get("allow_firewall_write", False)),
            allow_firewall_delete=bool(raw.get("allow_firewall_delete", False)),
            allow_policy_reorder=bool(raw.get("allow_policy_reorder", False)),
            require_change_confirmation=bool(raw.get("require_change_confirmation", True)),
            create_prechange_snapshot=bool(raw.get("create_prechange_snapshot", True)),
            polling_interval=max(5, min(300, int(raw.get("polling_interval", 15)))),
            history_retention_days=max(1, min(365, int(raw.get("history_retention_days", 30)))),
            max_history_rows=max(1000, min(1_000_000, int(raw.get("max_history_rows", 100000)))),
            log_level=str(raw.get("log_level", "INFO")).upper(),
            ntfy_enabled=bool(raw.get("ntfy_enabled", False)),
            ntfy_url=str(raw.get("ntfy_url", "")).rstrip("/"),
            ntfy_topic=str(raw.get("ntfy_topic", "ha-alerts")).strip("/"),
            ntfy_token=str(raw.get("ntfy_token", "")),
            notify_on_connection_failure=bool(raw.get("notify_on_connection_failure", True)),
            notify_on_connection_recovery=bool(raw.get("notify_on_connection_recovery", True)),
            notify_on_new_client=bool(raw.get("notify_on_new_client", True)),
            notify_on_device_offline=bool(raw.get("notify_on_device_offline", True)),
            notify_on_device_recovery=bool(raw.get("notify_on_device_recovery", True)),
            device_offline_grace_polls=max(1, min(10, int(raw.get("device_offline_grace_polls", 2)))),
            notification_cooldown=max(60, min(86400, int(raw.get("notification_cooldown", 900)))),
        )
