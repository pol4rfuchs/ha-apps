from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from typing import Any

SEVERITY_WEIGHTS = {"critical": 25, "high": 15, "medium": 8, "low": 3, "info": 0}


def _rows(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return [item for item in value if isinstance(item, dict)]
    if isinstance(value, dict):
        for key in ("data", "items", "results"):
            nested = value.get(key)
            if isinstance(nested, list):
                return [item for item in nested if isinstance(item, dict)]
    return []


def _action(policy: dict[str, Any]) -> str:
    value = policy.get("action")
    if isinstance(value, str):
        return value.lower()
    if isinstance(value, dict):
        for key in ("type", "action", "name"):
            nested = value.get(key)
            if isinstance(nested, str):
                return nested.lower()
    return "unknown"


def _name(policy: dict[str, Any], index: int) -> str:
    for key in ("name", "description", "id"):
        value = policy.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return f"Policy {index + 1}"


def _is_any(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip().lower() in {"", "any", "all", "*", "0.0.0.0/0", "::/0"}
    if isinstance(value, list):
        return len(value) == 0 or all(_is_any(item) for item in value)
    if isinstance(value, dict):
        meaningful = [v for k, v in value.items() if k.lower() not in {"negate", "except"}]
        return len(meaningful) == 0 or all(_is_any(item) for item in meaningful)
    return False


def _endpoint(policy: dict[str, Any], side: str) -> Any:
    for key in (side, f"{side}Config", f"{side}_config"):
        if key in policy:
            return policy[key]
    return None


def _logging_enabled(policy: dict[str, Any]) -> bool:
    return policy.get("loggingEnabled") is True or policy.get("logging_enabled") is True or policy.get("logging") is True


def _enabled(policy: dict[str, Any]) -> bool:
    return policy.get("enabled", True) is not False


def _signature(policy: dict[str, Any]) -> str:
    ignored = {"id", "_id", "name", "description", "index", "order", "createdAt", "updatedAt", "metadata"}
    normalized = {key: value for key, value in policy.items() if key not in ignored}
    return json.dumps(normalized, sort_keys=True, separators=(",", ":"), default=str)


def analyze_firewall(policies_value: Any, zones_value: Any) -> dict[str, Any]:
    policies = _rows(policies_value)
    zones = _rows(zones_value)
    findings: list[dict[str, Any]] = []

    signatures: dict[str, list[tuple[int, dict[str, Any]]]] = defaultdict(list)
    for index, policy in enumerate(policies):
        signatures[_signature(policy)].append((index, policy))

        name = _name(policy, index)
        action = _action(policy)
        source_any = _is_any(_endpoint(policy, "source"))
        destination_any = _is_any(_endpoint(policy, "destination"))

        if _enabled(policy) and action in {"allow", "accept", "permit"} and source_any and destination_any:
            findings.append({
                "code": "ANY_TO_ANY_ALLOW",
                "severity": "critical",
                "title": "Broad Any → Any allow policy",
                "policy_name": name,
                "policy_id": policy.get("id") or policy.get("_id"),
                "message": "An enabled allow policy appears to accept traffic from any source to any destination.",
                "recommendation": "Constrain source, destination, protocol, ports, or connection state before relying on this policy.",
            })
        elif _enabled(policy) and action in {"allow", "accept", "permit"} and (source_any or destination_any):
            findings.append({
                "code": "BROAD_ALLOW",
                "severity": "high",
                "title": "Broad allow policy",
                "policy_name": name,
                "policy_id": policy.get("id") or policy.get("_id"),
                "message": "An enabled allow policy uses an unrestricted source or destination.",
                "recommendation": "Review whether the unrestricted side can be narrowed to a zone, network, host, or group.",
            })
        if _enabled(policy) and action in {"allow", "accept", "permit"} and not _logging_enabled(policy):
            findings.append({
                "code": "ALLOW_WITHOUT_LOGGING",
                "severity": "low",
                "title": "Allow policy without logging",
                "policy_name": name,
                "policy_id": policy.get("id") or policy.get("_id"),
                "message": "This enabled allow policy does not report logging as enabled.",
                "recommendation": "Enable logging for sensitive inter-zone rules when operationally appropriate.",
            })
        if not str(policy.get("name") or policy.get("description") or "").strip():
            findings.append({
                "code": "MISSING_DESCRIPTION",
                "severity": "low",
                "title": "Policy has no clear name or description",
                "policy_name": name,
                "policy_id": policy.get("id") or policy.get("_id"),
                "message": "The policy cannot be identified by a meaningful name or description.",
                "recommendation": "Assign a purpose-oriented name before future changes are made.",
            })

    for group in signatures.values():
        if len(group) < 2:
            continue
        names = [_name(policy, index) for index, policy in group]
        findings.append({
            "code": "DUPLICATE_POLICY",
            "severity": "medium",
            "title": "Duplicate policy definitions",
            "policy_name": ", ".join(names[:4]),
            "policy_ids": [policy.get("id") or policy.get("_id") for _, policy in group],
            "message": f"{len(group)} policies have the same normalized rule definition.",
            "recommendation": "Confirm whether all duplicates are required before removing or consolidating anything.",
        })

    deduction = sum(SEVERITY_WEIGHTS.get(str(finding["severity"]), 0) for finding in findings)
    score = max(0, 100 - deduction)
    counts = {severity: sum(1 for finding in findings if finding["severity"] == severity) for severity in SEVERITY_WEIGHTS}
    return {
        "score": score,
        "policy_count": len(policies),
        "zone_count": len(zones),
        "finding_count": len(findings),
        "severity_counts": counts,
        "weights": SEVERITY_WEIGHTS,
        "findings": findings,
        "limitations": [
            "Analysis is conservative and uses only fields returned by the official UniFi Network API.",
            "A finding is advisory; the app does not change or delete policies in v0.4.0.",
            "Advanced semantic shadowing and packet-path simulation are not claimed in this milestone.",
        ],
    }


def canonical_snapshot(site_id: str, policies: Any, zones: Any, network_api: str | None = None, unifi_os: str | None = None) -> dict[str, Any]:
    payload = {
        "schema_version": 1,
        "site_id": site_id,
        "network_api": network_api,
        "unifi_os": unifi_os,
        "policies": _rows(policies),
        "zones": _rows(zones),
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    payload["sha256"] = hashlib.sha256(canonical).hexdigest()
    return payload


def snapshot_diff(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    def keyed(items: Any) -> dict[str, dict[str, Any]]:
        result: dict[str, dict[str, Any]] = {}
        for index, item in enumerate(_rows(items)):
            key = str(item.get("id") or item.get("_id") or item.get("name") or f"index:{index}")
            result[key] = item
        return result

    before_policies = keyed(before.get("policies"))
    after_policies = keyed(after.get("policies"))
    added = sorted(set(after_policies) - set(before_policies))
    removed = sorted(set(before_policies) - set(after_policies))
    changed = sorted(
        key for key in set(before_policies) & set(after_policies)
        if json.dumps(before_policies[key], sort_keys=True, default=str) != json.dumps(after_policies[key], sort_keys=True, default=str)
    )
    return {
        "before_sha256": before.get("sha256"),
        "after_sha256": after.get("sha256"),
        "added": [{"key": key, "policy": after_policies[key]} for key in added],
        "removed": [{"key": key, "policy": before_policies[key]} for key in removed],
        "changed": [{"key": key, "before": before_policies[key], "after": after_policies[key]} for key in changed],
        "summary": {"added": len(added), "removed": len(removed), "changed": len(changed)},
    }
