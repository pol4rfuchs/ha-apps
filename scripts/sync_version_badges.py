#!/usr/bin/env python3
"""
sync_version_badges.py
-----------------------
Liest .github/version-sync.json und bringt pro Add-on:
  - die Versions-Badges (shields.io, Format badge/<label>-<value>-<color>)
  - die dazugehörige Tabellenzeile (| **Label** | Wert |)
in den jeweiligen README.md / readme.md auf den Stand der echten Quelle
(Dockerfile ARG, config.yaml version, oder ein Shell-Skript).

Bewusste Grenzen (siehe .github/version-sync.json Kommentar):
  - navidrome nutzt einen dynamischen shields.io-Endpoint-Badge
    (img.shields.io/github/v/release/...) -> aktualisiert sich selbst,
    taucht hier bewusst nicht auf.
  - matrix_synapse: Synapse selbst (pip "matrix-synapse[all]>=1.121.0")
    sowie Element Web / Element Call / LiveKit werden zur LAUFZEIT im
    Container aufgelöst (siehe rootfs/etc/cont-init.d/03-/05-*.sh) und
    sind daher zum Build-/CI-Zeitpunkt nicht statisch bekannt. Nur
    Synapse Admin hat einen echten statischen Pin -> nur dieser wird
    synchronisiert.
  - ts6_manager: Upstream ist ein Git-Commit-Ref, kein Versions-Tag ->
    wird nicht synchronisiert, nur die Add-on-Version.

Exit code 0 immer, Änderungen werden über GITHUB_OUTPUT "changed" als
Liste der geänderten Add-ons gemeldet.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / ".github" / "version-sync.json"


def read_value(addon_dir: Path, value_from: dict) -> str | None:
    """Liest einen Versions-String aus einer Datei via Regex (erste Capture-Group)."""
    file_path = addon_dir / value_from["file"]
    if not file_path.exists():
        print(f"  ⚠️  Quelle fehlt: {file_path.relative_to(REPO_ROOT)}")
        return None

    text = file_path.read_text(encoding="utf-8")
    match = re.search(value_from["regex"], text, re.MULTILINE)
    if not match:
        print(f"  ⚠️  Pattern nicht gefunden in {file_path.relative_to(REPO_ROOT)}: {value_from['regex']}")
        return None

    return match.group(1).strip().strip('"')


def update_badge(readme: str, badge_label: str, color: str, new_value: str) -> str:
    """Ersetzt den Versions-Teil eines shields.io-Static-Badge mit fixem Label/Farbe.

    shields.io braucht escapte Bindestriche INNERHALB eines Feldes (sonst wird
    der Bindestrich als Feld-Trenner gelesen und die Badge-URL kaputt) -> "-" wird
    für die Badge-URL zu "--" verdoppelt. Die Tabellenzeile bekommt den
    unveränderten (lesbaren) Wert, siehe update_table_row.
    """
    escaped_value = new_value.replace("-", "--")
    pattern = re.compile(
        r"(badge/" + re.escape(badge_label) + r"-)[^-]+(?:--[^-]+)*(-" + re.escape(color) + r")"
    )
    if not pattern.search(readme):
        print(f"  ⚠️  Badge nicht gefunden: badge/{badge_label}-...-{color}")
        return readme
    return pattern.sub(lambda m: m.group(1) + escaped_value + m.group(2), readme, count=1)


def update_table_row(readme: str, label: str, new_value: str) -> str:
    """Ersetzt den Wert in einer Markdown-Tabellenzeile: | **Label** | <alt> | -> | **Label** | <neu> |"""
    pattern = re.compile(
        r"(\|\s*\*\*" + re.escape(label) + r"\*\*\s*\|)[^|]+(\|)"
    )
    if not pattern.search(readme):
        print(f"  ⚠️  Tabellenzeile nicht gefunden: **{label}**")
        return readme
    return pattern.sub(lambda m: f"{m.group(1)} {new_value} {m.group(2)}", readme, count=1)


def process_addon(slug: str, spec: dict) -> bool:
    addon_dir = REPO_ROOT / slug
    readme_path = addon_dir / spec["readme"]
    if not readme_path.exists():
        print(f"  ⚠️  README fehlt: {readme_path.relative_to(REPO_ROOT)}")
        return False

    original = readme_path.read_text(encoding="utf-8")
    updated = original

    for item in spec["items"]:
        value = read_value(addon_dir, item["value_from"])
        if value is None:
            continue

        display_value = item.get("value_prefix", "") + value + item.get("value_suffix", "")

        if "badge" in item:
            updated = update_badge(
                updated, item["badge"]["label"], item["badge"]["color"], display_value
            )

        if "table_row_label" in item:
            table_value = item.get("table_value_format", "{value}").format(value=display_value)
            updated = update_table_row(updated, item["table_row_label"], table_value)

    if updated != original:
        readme_path.write_text(updated, encoding="utf-8")
        print(f"  ✅ aktualisiert: {readme_path.relative_to(REPO_ROOT)}")
        return True

    print("  ℹ️  keine Änderung nötig")
    return False


def main() -> None:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    changed = []

    for slug, spec in config.items():
        if slug.startswith("_"):
            continue
        print(f"## {slug}")
        if process_addon(slug, spec):
            changed.append(slug)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            if changed:
                fh.write("### 🔄 Aktualisierte Add-on READMEs\n\n")
                for slug in changed:
                    fh.write(f"- `{slug}`\n")
            else:
                fh.write("### ✅ Alle Versions-Badges waren bereits aktuell\n")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as fh:
            fh.write(f"changed={'true' if changed else 'false'}\n")
            fh.write(f"changed_list={','.join(changed)}\n")


if __name__ == "__main__":
    sys.exit(main() or 0)
