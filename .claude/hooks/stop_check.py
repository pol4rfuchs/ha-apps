#!/usr/bin/env python3
"""Stop hook: deterministic checks on the working tree before Claude may finish.

Checks (only on files that changed vs. HEAD, plus untracked files):
  1. yamllint (repo config .yamllint) on changed *.yaml / *.yml  -> errors block, warnings do not
  2. CHANGELOG.md of an existing app was edited by hand           -> blocks (Release Please generates it)
  3. Added lines that mention codeberg.org or .forgejo            -> blocks (Buildrules §6),
                                                                   unless the line has "forge-check:allow"
  4. Docker linters, only for the matching changed files (same images/options as the CI):
       hadolint   changed */Dockerfile                  (workflow 12: failure-threshold error, ignore DL3008/13/18)
       actionlint changed .github/workflows/*.y*ml      (workflow 14)
       shellcheck changed *.sh and s6 run/finish files  (severity error only; the CI has no shellcheck step)
     The hook never pulls images and never waits for Docker: if the Docker engine is unreachable or an image is
     missing locally, that linter is reported as skipped (with the command to fix it), not as passed.

Hook contract (Claude Code): JSON on stdin; to block, print {"decision": "block", "reason": ...} and exit 0.
Skips itself when stop_hook_active is true so it cannot loop (Claude Code caps blocks at 8 anyway).
Only reports what it really ran; tools that are not installed are named as skipped, never as passed.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

FORGE_RE = re.compile(r"codeberg\.org|\.forgejo", re.IGNORECASE)
MARKER = "forge-check:allow"
ANSI_RE = re.compile("\x1b\\[[0-9;]*m")  # hadolint colours its output
# The rule text itself names the forbidden strings, so these files are not scanned.
FORGE_SKIP = ("CLAUDE.md", ".claude/")

# Same images as the CI. hadolint: pinned by hadolint-action v3.5.0 (workflow 12). actionlint/shellcheck: pinned here.
IMAGES = {
    "hadolint": "ghcr.io/hadolint/hadolint:v2.15.1-debian@sha256:9a3944b7fddcb947d1ffd90829ac1a6e5c30479223358f249d8b96c7d0019e27",
    "actionlint": "rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667",
    "shellcheck": "koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d",
}
# Test seam: STOP_CHECK_DOCKER="python fake_docker.py" replaces the docker command.
DOCKER = shlex.split(os.environ.get("STOP_CHECK_DOCKER", "docker"))
DOCKER_TIMEOUT = 100  # seconds per linter run; the hook timeout in settings.json must stay above the sum


def git(*args: str, cwd: Path) -> str:
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    except OSError:
        return ""
    return out.stdout if out.returncode == 0 else ""


def changed_files(root: Path) -> tuple[list[str], list[str]]:
    """Returns (modified/added tracked files, untracked files), relative to root, existing only."""
    tracked = [p for p in git("diff", "--name-only", "--diff-filter=AM", "HEAD", cwd=root).splitlines() if p]
    untracked = [p for p in git("ls-files", "--others", "--exclude-standard", cwd=root).splitlines() if p]
    return ([p for p in tracked if (root / p).is_file()], [p for p in untracked if (root / p).is_file()])


def docker_engine_problem() -> str | None:
    """None when the Docker engine answers, else the reason (one line)."""
    try:
        info = subprocess.run([*DOCKER, "info", "--format", "{{.ServerVersion}}"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return "Docker nicht erreichbar"
    if info.returncode != 0 or not info.stdout.strip():
        return "Docker-Engine läuft nicht (Docker Desktop starten)"
    return None


def image_missing(image: str) -> bool:
    try:
        have = subprocess.run([*DOCKER, "image", "inspect", image], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return True
    return have.returncode != 0


def run_linter(name: str, root: Path, args: list[str], files: list[str]) -> tuple[str, list[str]]:
    """Returns ("ok"|"findings"|"error", output lines). The tool is set as --entrypoint (the actionlint and
    shellcheck images already have it as entrypoint, so passing its name again would be read as a file name)."""
    cmd = [*DOCKER, "run", "--rm", "--mount", f"type=bind,source={root},target=/repo,readonly", "-w", "/repo",
           "--entrypoint", name, IMAGES[name], *args, *files]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=DOCKER_TIMEOUT)
    except subprocess.TimeoutExpired:
        return "error", [f"Zeitüberschreitung nach {DOCKER_TIMEOUT}s"]
    except OSError as exc:
        return "error", [str(exc)]
    text = ANSI_RE.sub("", res.stdout + res.stderr)
    lines = [ln[:300] for ln in text.splitlines() if ln.strip()]
    if res.returncode == 0:
        return "ok", lines
    # 1 = findings for all three linters; anything else (125-127, 2+) is a tool/engine problem
    return ("findings" if res.returncode == 1 else "error"), lines


def shell_of(root: Path, rel: str) -> str:
    try:
        first = (root / rel).read_text(encoding="utf-8", errors="ignore").splitlines()[:1]
    except OSError:
        first = []
    shebang = first[0] if first else ""
    return "sh" if re.search(r"/(env\s+)?(ba)?sh\b", shebang) and "bash" not in shebang else "bash"


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        event = {}
    if event.get("stop_hook_active"):
        return 0

    root = Path(event.get("cwd") or ".")
    if not root.is_dir():
        root = Path.cwd()  # Claude Code starts hooks in the project directory
    root = root.resolve()
    top = git("rev-parse", "--show-toplevel", cwd=root).strip()
    if not top:
        return 0
    root = Path(top)

    tracked, untracked = changed_files(root)
    all_changed = tracked + untracked
    problems: list[str] = []
    ran: list[str] = []
    skipped: list[str] = []

    # 1. yamllint
    yaml_files = [p for p in all_changed if p.lower().endswith((".yaml", ".yml"))]
    if yaml_files:
        res = subprocess.run(
            [sys.executable, "-m", "yamllint", "-f", "parsable", "-c", ".yamllint", *yaml_files],
            cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if "No module named yamllint" in res.stderr:
            skipped.append("yamllint (nicht installiert)")
        else:
            ran.append(f"yamllint ({len(yaml_files)} Dateien)")
            errors = [ln for ln in res.stdout.splitlines() if "[error]" in ln]
            if errors:
                problems.append("yamllint-Fehler:\n  " + "\n  ".join(errors[:20]))

    # 2. CHANGELOG.md of an existing app edited by hand
    edited_changelogs = [p for p in tracked if p.endswith("CHANGELOG.md") and "/" in p]
    if edited_changelogs:
        problems.append(
            "CHANGELOG.md wird von Release Please erzeugt und darf nicht von Hand geändert werden: "
            + ", ".join(edited_changelogs)
            + " (mit `git checkout -- <Datei>` zurücksetzen)."
        )
    ran.append("CHANGELOG-Handedit-Check")

    # 3. forge-check on added lines only
    hits: list[str] = []
    diff = git("diff", "-U0", "HEAD", cwd=root)
    current = ""
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
        elif line.startswith("+") and not line.startswith("+++"):
            if current.startswith(FORGE_SKIP):
                continue
            if FORGE_RE.search(line) and MARKER not in line:
                hits.append(f"{current}: {line[1:].strip()[:120]}")
    for p in untracked:
        if p.startswith(FORGE_SKIP):
            continue
        try:
            text = (root / p).read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if FORGE_RE.search(line) and MARKER not in line:
                hits.append(f"{p}:{n}: {line.strip()[:120]}")
    ran.append("Forge-Check")
    if hits:
        problems.append(
            "Verweise auf codeberg.org/.forgejo in neuen Zeilen (Buildrules §6; Forgejo mit https://forgejo.org verlinken "
            f"oder Marker `{MARKER}` setzen):\n  " + "\n  ".join(hits[:20])
        )

    # 4. Docker linters
    dockerfiles = [p for p in all_changed if p.split("/")[-1] == "Dockerfile" and p.count("/") == 1]
    workflows = [p for p in all_changed if p.startswith(".github/workflows/") and p.lower().endswith((".yaml", ".yml"))]
    shell_files = [p for p in all_changed if p.endswith(".sh") or (p.split("/")[-1] in ("run", "finish") and "s6-rc.d" in p)]
    jobs: list[tuple[str, list[str], list[str]]] = []
    if dockerfiles:
        jobs.append(("hadolint", ["--failure-threshold", "error", "--ignore", "DL3008", "--ignore", "DL3013",
                                  "--ignore", "DL3018"], dockerfiles))
    if workflows:
        jobs.append(("actionlint", [], workflows))
    for shell in ("bash", "sh"):
        group = [p for p in shell_files if shell_of(root, p) == shell]
        if group:
            jobs.append(("shellcheck", ["-S", "error", "-s", shell], group))
    if jobs:
        why = docker_engine_problem()
        if why:
            skipped.extend(f"{n} ({why})" for n in dict.fromkeys(n for n, _, _ in jobs))
        else:
            missing: dict[str, bool] = {}
            tool_errors: dict[str, str] = {}
            counts: dict[str, int] = {}
            for name, args, files in jobs:
                image = IMAGES[name]
                if image not in missing:
                    missing[image] = image_missing(image)
                if missing[image]:
                    if not any(x.startswith(name + " ") for x in skipped):
                        skipped.append(f"{name} (Image fehlt lokal: docker pull {image})")
                    continue
                state, out = run_linter(name, root, args, files)
                if state == "error":
                    tool_errors.setdefault(name, out[0][:100] if out else "unbekannt")
                    continue
                counts[name] = counts.get(name, 0) + len(files)
                if state == "findings":
                    problems.append(f"{name}-Befunde:\n  " + "\n  ".join(out[:20]))
            ran.extend(f"{n} ({c} Dateien)" for n, c in counts.items())
            skipped.extend(f"{n} (Werkzeugfehler: {m})" for n, m in tool_errors.items())

    if problems:
        reason = "Stop-Check fehlgeschlagen. Bitte beheben und erneut prüfen.\n\n" + "\n\n".join(problems)
        reason += "\n\nGeprüft: " + ", ".join(ran)
        if skipped:
            reason += "\nÜbersprungen: " + ", ".join(skipped)
        print(json.dumps({"decision": "block", "reason": reason}))  # ASCII-escaped: safe on any console encoding
    elif skipped:
        # Nothing failed, but a check could not run: say so instead of looking like a full pass.
        print(json.dumps({"systemMessage": "Stop-Check: nicht alles geprüft. Übersprungen: " + ", ".join(skipped)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
