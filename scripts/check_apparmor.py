#!/usr/bin/env python3
"""AppArmor checks for all add-ons listed in addons.json (Buildrules §8).

Per add-on:
  * syntax      apparmor_parser -Q -K on every existing apparmor.txt (hard fail)
  * complain    apparmor: true  +  flags=(complain) in the profile (hard fail)
  * missing     apparmor: true  +  no apparmor.txt (hard fail, repo rule)
  * s6 baseline rule-based check of the s6-overlay minimum (Buildrules §8);
                hard fail only for apparmor: true, otherwise reported only
                so the backlog (OFFENE_PUNKTE §3) stays visible.

Add-ons with apparmor: false and no profile are only listed in the summary.
HA treats a missing `apparmor` key as enabled, so that counts as true.

The parser only checks syntax; it does not load the profile into a kernel and
may differ in version from HAOS. Behaviour still has to be tested on the Pi
(complain mode, journalctl).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

# Sample paths that the s6-overlay re-executes on stop/restart. A profile
# passes when some non-deny rule covers one of the samples AND grants execute
# (x). The s6 runtime dir may be redirected to /tmp/s6 (S6_BASEDIR, used by
# nginx_proxy_manager because /run is noexec there), so both are accepted.
S6_BASELINE = {
    "/init": ("/init",),
    "/package/**": ("/package/x",),
    "/command/**": ("/command/x",),
    "/run/s6/** (or /tmp/s6/**)": ("/run/s6/x", "/tmp/s6/x"),
    "/etc/s6-overlay/**": ("/etc/s6-overlay/x",),
    "/etc/services.d/**": ("/etc/services.d/x",),
    "/etc/cont-init.d/**": ("/etc/cont-init.d/x",),
    "/etc/cont-finish.d/**": ("/etc/cont-finish.d/x",),
}

RULE_RE = re.compile(
    r"^(?:(?:audit|owner|allow)\s+)*(?P<path>/\S*)\s+(?P<perms>[a-zA-Z]+)\s*,"
)
COMPLAIN_RE = re.compile(r"\bflags\s*=\s*\([^)]*\bcomplain\b")


def expand_braces(pattern: str) -> list[str]:
    """Expand the first {a,b,...} group recursively (AppArmor alternation)."""
    match = re.search(r"\{([^{}]*)\}", pattern)
    if not match:
        return [pattern]
    out: list[str] = []
    for alt in match.group(1).split(","):
        out.extend(expand_braces(pattern[: match.start()] + alt + pattern[match.end():]))
    return out


def glob_to_regex(glob: str) -> re.Pattern[str]:
    regex = ""
    i = 0
    while i < len(glob):
        if glob.startswith("**", i):
            regex += ".*"
            i += 2
        elif glob[i] == "*":
            regex += "[^/]*"
            i += 1
        elif glob[i] == "?":
            regex += "[^/]"
            i += 1
        else:
            regex += re.escape(glob[i])
            i += 1
    return re.compile(regex + r"\Z")


def profile_lines(text: str) -> list[str]:
    """Non-empty profile lines without full-line and trailing comments."""
    lines = [re.sub(r"\s#.*$", "", ln).strip() for ln in text.splitlines()]
    return [ln for ln in lines if ln and not ln.startswith("#")]


def missing_baseline(text: str) -> list[str]:
    rules: list[tuple[re.Pattern[str], str]] = []
    for line in profile_lines(text):
        if line.startswith("deny "):
            continue
        match = RULE_RE.match(line)
        if not match or "x" not in match.group("perms"):
            continue
        for path in expand_braces(match.group("path")):
            rules.append((glob_to_regex(path), path))
    return [
        required
        for required, samples in S6_BASELINE.items()
        if not any(rx.match(sample) for rx, _ in rules for sample in samples)
    ]


def has_complain(text: str) -> bool:
    return any(COMPLAIN_RE.search(line) for line in profile_lines(text))


def run_parser(profile: Path) -> tuple[bool, str]:
    parser = shutil.which("apparmor_parser")
    if parser is None:
        return (os.environ.get("CI") != "true", "parser not installed")
    proc = subprocess.run(
        [parser, "-Q", "-K", str(profile)],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.returncode == 0, (proc.stderr or proc.stdout).strip()


def annotate(level: str, file: Path, message: str) -> None:
    rel = file.relative_to(ROOT).as_posix()
    # Workflow commands are single-line; escape so multi-line parser output
    # ends up complete in the annotation.
    message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::{level} file={rel}::{message}")


def check_addon(addon: str) -> dict:
    cfg_path = ROOT / addon / "config.yaml"
    profile = ROOT / addon / "apparmor.txt"
    if not cfg_path.is_file():
        annotate("error", ROOT / "addons.json", f"{addon}: config.yaml not found")
        return {
            "addon": addon, "enabled": False, "profile": profile.is_file(),
            "syntax": "-", "baseline": "-", "complain": "-", "failed": True,
        }
    config = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    enabled = config.get("apparmor", True) is not False
    row = {
        "addon": addon,
        "enabled": enabled,
        "profile": profile.is_file(),
        "syntax": "-",
        "baseline": "-",
        "complain": "-",
        "failed": False,
    }
    if not profile.is_file():
        if enabled:
            row["failed"] = True
            annotate("error", cfg_path, f"{addon}: apparmor is enabled but apparmor.txt is missing")
        return row

    text = profile.read_text(encoding="utf-8")

    ok, detail = run_parser(profile)
    row["syntax"] = "ok" if ok else "FAIL"
    if not ok:
        row["failed"] = True
        annotate("error", profile, f"{addon}: apparmor_parser failed: {detail}")
    elif detail == "parser not installed":
        row["syntax"] = "skipped"

    missing = missing_baseline(text)
    row["baseline"] = "ok" if not missing else f"missing {len(missing)}"
    if missing:
        msg = f"{addon}: s6 baseline (§8) lacks execute rule for: {', '.join(missing)}"
        if enabled:
            row["failed"] = True
            annotate("error", profile, msg)
        else:
            annotate("warning", profile, msg)

    row["complain"] = "yes" if has_complain(text) else "no"
    if enabled and row["complain"] == "yes":
        row["failed"] = True
        annotate("error", profile, f"{addon}: flags=(complain) must not be set while apparmor: true")
    return row


def main() -> int:
    addons = json.loads((ROOT / "addons.json").read_text(encoding="utf-8"))
    rows = [check_addon(a) for a in addons]

    lines = [
        "## AppArmor inventory",
        "",
        "| Add-on | apparmor | profile | syntax | s6 baseline | complain | result |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['addon']} | {'true' if r['enabled'] else 'false'} | "
            f"{'yes' if r['profile'] else 'no'} | {r['syntax']} | {r['baseline']} | "
            f"{r['complain']} | {'FAIL' if r['failed'] else 'ok'} |"
        )
    summary = "\n".join(lines) + "\n"
    print(summary)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as fh:
            fh.write(summary)

    return 1 if any(r["failed"] for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
