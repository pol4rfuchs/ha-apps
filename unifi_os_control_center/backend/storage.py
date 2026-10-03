from __future__ import annotations

import json
import sqlite3
import time
from pathlib import Path
from typing import Any

DB_PATH = Path("/data/unifi_control_center.db")


def init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB_PATH) as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=NORMAL")
        db.execute("""
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at INTEGER NOT NULL,
                kind TEXT NOT NULL,
                payload TEXT NOT NULL
            )
        """)
        db.execute("CREATE INDEX IF NOT EXISTS idx_snapshots_kind_created ON snapshots(kind, created_at)")
        db.execute("""
            CREATE TABLE IF NOT EXISTS firewall_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at INTEGER NOT NULL,
                site_id TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                policy_count INTEGER NOT NULL,
                zone_count INTEGER NOT NULL,
                sha256 TEXT NOT NULL,
                payload TEXT NOT NULL
            )
        """)
        db.execute("CREATE INDEX IF NOT EXISTS idx_firewall_snapshots_site_created ON firewall_snapshots(site_id, created_at DESC)")
        db.execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at INTEGER NOT NULL,
                level TEXT NOT NULL,
                source TEXT NOT NULL,
                message TEXT NOT NULL,
                acknowledged INTEGER NOT NULL DEFAULT 0
            )
        """)
        columns = {row[1] for row in db.execute("PRAGMA table_info(alerts)").fetchall()}
        if "acknowledged" not in columns:
            db.execute("ALTER TABLE alerts ADD COLUMN acknowledged INTEGER NOT NULL DEFAULT 0")
        db.execute("CREATE INDEX IF NOT EXISTS idx_alerts_created ON alerts(created_at DESC)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_alerts_ack_created ON alerts(acknowledged, created_at DESC)")


def save_snapshot(kind: str, payload: Any) -> None:
    with sqlite3.connect(DB_PATH) as db:
        db.execute(
            "INSERT INTO snapshots(created_at, kind, payload) VALUES (?, ?, ?)",
            (int(time.time()), kind, json.dumps(payload, separators=(",", ":"))),
        )


def create_firewall_snapshot(site_id: str, payload: dict[str, Any], note: str = "") -> dict[str, Any]:
    created_at = int(time.time())
    policies = payload.get("policies") if isinstance(payload.get("policies"), list) else []
    zones = payload.get("zones") if isinstance(payload.get("zones"), list) else []
    sha256 = str(payload.get("sha256") or "")
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute(
            """INSERT INTO firewall_snapshots(created_at, site_id, note, policy_count, zone_count, sha256, payload)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (created_at, site_id, note[:500], len(policies), len(zones), sha256, json.dumps(payload, separators=(",", ":"), default=str)),
        )
        snapshot_id = int(cursor.lastrowid)
    return {"id": snapshot_id, "created_at": created_at, "site_id": site_id, "note": note[:500], "policy_count": len(policies), "zone_count": len(zones), "sha256": sha256}


def list_firewall_snapshots(site_id: str, limit: int = 50) -> list[dict[str, Any]]:
    safe_limit = max(1, min(limit, 200))
    with sqlite3.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(
            "SELECT id, created_at, site_id, note, policy_count, zone_count, sha256 FROM firewall_snapshots WHERE site_id = ? ORDER BY created_at DESC, id DESC LIMIT ?",
            (site_id, safe_limit),
        ).fetchall()
    return [dict(row) for row in rows]


def get_firewall_snapshot(snapshot_id: int) -> dict[str, Any] | None:
    with sqlite3.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        row = db.execute("SELECT * FROM firewall_snapshots WHERE id = ?", (snapshot_id,)).fetchone()
    if row is None:
        return None
    result = dict(row)
    result["payload"] = json.loads(result["payload"])
    return result


def cleanup(retention_days: int, max_rows: int) -> None:
    cutoff = int(time.time()) - retention_days * 86400
    with sqlite3.connect(DB_PATH) as db:
        db.execute("DELETE FROM snapshots WHERE created_at < ?", (cutoff,))
        db.execute("DELETE FROM firewall_snapshots WHERE created_at < ?", (cutoff,))
        db.execute("DELETE FROM alerts WHERE created_at < ?", (cutoff,))
        db.execute(
            "DELETE FROM snapshots WHERE id NOT IN (SELECT id FROM snapshots ORDER BY id DESC LIMIT ?)",
            (max_rows,),
        )
        db.execute(
            "DELETE FROM firewall_snapshots WHERE id NOT IN (SELECT id FROM firewall_snapshots ORDER BY id DESC LIMIT ?)",
            (max_rows,),
        )
        db.execute(
            "DELETE FROM alerts WHERE id NOT IN (SELECT id FROM alerts ORDER BY id DESC LIMIT ?)",
            (max_rows,),
        )


def add_alert(level: str, source: str, message: str) -> dict[str, Any]:
    created_at = int(time.time())
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute(
            "INSERT INTO alerts(created_at, level, source, message) VALUES (?, ?, ?, ?)",
            (created_at, level[:16], source[:64], message[:1000]),
        )
        alert_id = int(cursor.lastrowid)
    return {"id": alert_id, "created_at": created_at, "level": level[:16], "source": source[:64], "message": message[:1000]}


def list_alerts(limit: int = 100) -> list[dict[str, Any]]:
    safe_limit = max(1, min(limit, 500))
    with sqlite3.connect(DB_PATH) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(
            "SELECT id, created_at, level, source, message, acknowledged FROM alerts ORDER BY acknowledged ASC, created_at DESC, id DESC LIMIT ?",
            (safe_limit,),
        ).fetchall()
    return [dict(row) for row in rows]


def clear_alerts() -> int:
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute("DELETE FROM alerts")
        return int(cursor.rowcount)


def acknowledge_alert(alert_id: int) -> bool:
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute("UPDATE alerts SET acknowledged = 1 WHERE id = ?", (alert_id,))
        return cursor.rowcount > 0


def acknowledge_all_alerts() -> int:
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute("UPDATE alerts SET acknowledged = 1 WHERE acknowledged = 0")
        return int(cursor.rowcount)


def delete_alert(alert_id: int) -> bool:
    with sqlite3.connect(DB_PATH) as db:
        cursor = db.execute("DELETE FROM alerts WHERE id = ?", (alert_id,))
        return cursor.rowcount > 0


def alert_stats() -> dict[str, Any]:
    with sqlite3.connect(DB_PATH) as db:
        total = int(db.execute("SELECT COUNT(*) FROM alerts").fetchone()[0])
        open_count = int(db.execute("SELECT COUNT(*) FROM alerts WHERE acknowledged = 0").fetchone()[0])
        acknowledged = total - open_count
        by_level = {row[0]: int(row[1]) for row in db.execute("SELECT level, COUNT(*) FROM alerts GROUP BY level").fetchall()}
        by_source = {row[0]: int(row[1]) for row in db.execute("SELECT source, COUNT(*) FROM alerts GROUP BY source ORDER BY COUNT(*) DESC, source ASC").fetchall()}
    return {
        "total": total,
        "open": open_count,
        "acknowledged": acknowledged,
        "by_level": by_level,
        "by_source": by_source,
    }
