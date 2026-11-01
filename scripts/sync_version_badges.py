#!/usr/bin/env python3
"""
sync_version_badges.py
-----------------------
Reads .github/version-sync.json and, for each add-on, brings
  - the version badges (shields.io, format badge/<label>-<value>-<color>)
  - the matching table row (| **Label** | value |)
in the respective README.md / readme.md in line with the real source
(Dockerfile ARG, config.yaml version, or a shell script).

Deliberate limits (see the comment in .github/version-sync.json):
  - navidrome uses a dynamic shields.io endpoint badge
    (img.shields.io/github/v/release/...) -> it updates itself and is
    deliberately not listed here.
  - matrix_synapse: only the Synapse pip floor ("matrix-synapse[all]>=...")
    in the Dockerfile is a static value, so only that badge is synchronized.
    Element Web / Element Call / LiveKit / Ketesa are resolved at RUNTIME
    in the container (see rootfs/etc/cont-init.d/03-/05-*.sh); the scripts
    only keep an emergency fallback version for an unreachable GitHub API.
    The README rows for them say "latest" on purpose and are not synchronized.
  - ts6_manager: upstream is a git commit ref, not a version tag ->
    it is not synchronized, only the add-on version is.

Always exits with code 0. Changes are reported through the GITHUB_OUTPUT
"changed" value as a list of the changed add-ons.
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
    """Reads a version string from a file via regex (first capture group)."""
    file_path = addon_dir / value_from["file"]
    if not file_path.exists():
        print(f"  ⚠️  Source missing: {file_path.relative_to(REPO_ROOT)}")
        return None

    text = file_path.read_text(encoding="utf-8")
    match = re.search(value_from["regex"], text, re.MULTILINE)
    if not match:
        print(f"  ⚠️  Pattern not found in {file_path.relative_to(REPO_ROOT)}: {value_from['regex']}")
        return None

    return match.group(1).strip().strip('"')


def update_badge(readme: str, badge_label: str, color: str, new_value: str) -> str:
    """Replaces the version part of a shields.io static badge with a fixed label/color.

    shields.io needs escaped hyphens INSIDE a field (otherwise the hyphen is
    read as a field separator and the badge URL breaks) -> "-" is doubled
    to "--" for the badge URL. The table row gets the unchanged (readable)
    value, see update_table_row.
    """
    escaped_value = new_value.replace("-", "--")
    pattern = re.compile(
        r"(badge/" + re.escape(badge_label) + r"-)[^-]+(?:--[^-]+)*(-" + re.escape(color) + r")"
    )
    if not pattern.search(readme):
        print(f"  ⚠️  Badge not found: badge/{badge_label}-...-{color}")
        return readme
    return pattern.sub(lambda m: m.group(1) + escaped_value + m.group(2), readme, count=1)


def update_table_row(readme: str, label: str, new_value: str) -> str:
    """Replaces the value in a Markdown table row: | **Label** | <old> | -> | **Label** | <new> |"""
    pattern = re.compile(
        r"(\|\s*\*\*" + re.escape(label) + r"\*\*\s*\|)[^|]+(\|)"
    )
    if not pattern.search(readme):
        print(f"  ⚠️  Table row not found: **{label}**")
        return readme
    return pattern.sub(lambda m: f"{m.group(1)} {new_value} {m.group(2)}", readme, count=1)


def process_addon(slug: str, spec: dict) -> bool:
    addon_dir = REPO_ROOT / slug
    readme_path = addon_dir / spec["readme"]
    if not readme_path.exists():
        print(f"  ⚠️  README missing: {readme_path.relative_to(REPO_ROOT)}")
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
        print(f"  ✅ updated: {readme_path.relative_to(REPO_ROOT)}")
        return True

    print("  ℹ️  no change needed")
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
                fh.write("### 🔄 Updated add-on READMEs\n\n")
                for slug in changed:
                    fh.write(f"- `{slug}`\n")
            else:
                fh.write("### ✅ All version badges were already up to date\n")

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as fh:
            fh.write(f"changed={'true' if changed else 'false'}\n")
            fh.write(f"changed_list={','.join(changed)}\n")


if __name__ == "__main__":
    sys.exit(main() or 0)
