#!/usr/bin/env python3
"""Collect repository stats for the README badges.

Writes shields.io endpoint files and a cumulative state file into --out-dir
(checked out from the orphan branch `stats` by workflow 31):

* visitors.json / views.json: GitHub only keeps the last 14 days of traffic, so the
  daily numbers are merged into state.json and summed over the whole history.
  "Visitors" is the sum of the daily unique visitors (one person on two days counts twice).
* downloads.json: sum of "Total downloads" of every GHCR package listed in addons.json,
  read from the public package page (GitHub has no API for it). Unique downloads do not exist.

Environment: GH_TOKEN (needs read access to the repository traffic, i.e. push/admin rights).
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

USER_AGENT = "ha-apps-repo-stats"
COLOR = "41BDF5"
MULTIPLIER = {"": 1, "k": 1_000, "m": 1_000_000}


def fetch(url: str, token: str | None = None, accept: str | None = None) -> str:
    headers = {"User-Agent": USER_AGENT}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if accept:
        headers["Accept"] = accept
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310 (fixed https URLs)
        return response.read().decode("utf-8", "replace")


def parse_total_downloads(html: str) -> int | None:
    """Return the number shown under "Total downloads" on a package page, or None."""
    position = html.find("Total downloads")
    if position < 0:
        return None
    window = html[position : position + 600]
    exact = re.search(r'title="(\d[\d,]*)"', window)
    if exact:
        return int(exact.group(1).replace(",", ""))
    shown = re.search(r">\s*(\d+(?:[.,]\d+)?)\s*([kKmM]?)\s*<", window)
    if shown:
        value = float(shown.group(1).replace(",", "."))
        return int(round(value * MULTIPLIER[shown.group(2).lower()]))
    return None


def human(number: int) -> str:
    if number >= 1_000_000:
        return f"{number / 1_000_000:.1f}M"
    if number >= 1_000:
        return f"{number / 1_000:.1f}k"
    return str(number)


def badge(label: str, number: int) -> dict:
    return {"schemaVersion": 1, "label": label, "message": human(number), "color": COLOR}


def update_views(state: dict, repo: str, token: str) -> None:
    raw = fetch(f"https://api.github.com/repos/{repo}/traffic/views?per=day", token, "application/vnd.github+json")
    for entry in json.loads(raw).get("views", []):
        state["views"][entry["timestamp"][:10]] = {"count": entry["count"], "uniques": entry["uniques"]}


def update_downloads(state: dict, owner: str, slugs: list[str]) -> int:
    parsed = 0
    for slug in slugs:
        url = f"https://github.com/users/{owner}/packages/container/package/{slug}"
        try:
            total = parse_total_downloads(fetch(url))
        except urllib.error.URLError as error:
            print(f"::warning::{slug}: package page not readable ({error})")
            continue
        if total is None:
            print(f"::warning::{slug}: no 'Total downloads' number found on the package page")
            continue
        parsed += 1
        # Never go backwards (a rounded "1.2k" or a deleted package version must not lower the total).
        state["downloads"][slug] = max(total, state["downloads"].get(slug, 0))
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--repo", required=True, help="owner/name")
    parser.add_argument("--addons", default="addons.json")
    args = parser.parse_args()

    token = os.environ.get("GH_TOKEN")
    if not token:
        print("GH_TOKEN is not set", file=sys.stderr)
        return 1

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    state_file = out / "state.json"
    state = {"views": {}, "downloads": {}}
    if state_file.exists():
        state.update(json.loads(state_file.read_text(encoding="utf-8")))

    owner = args.repo.split("/")[0]
    slugs = json.loads(Path(args.addons).read_text(encoding="utf-8"))

    try:
        update_views(state, args.repo, token)
    except urllib.error.HTTPError as error:
        print(f"::error::traffic API answered {error.code}; the token needs push/admin access to {args.repo}")
        return 1

    if update_downloads(state, owner, slugs) == 0:
        print("::error::could not read a single package page; the page layout may have changed")
        return 1

    unique = sum(day["uniques"] for day in state["views"].values())
    views = sum(day["count"] for day in state["views"].values())
    downloads = sum(state["downloads"].values())

    state["views"] = dict(sorted(state["views"].items()))
    state["downloads"] = dict(sorted(state["downloads"].items()))
    state_file.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    (out / "visitors.json").write_text(json.dumps(badge("visitors", unique)) + "\n", encoding="utf-8")
    (out / "views.json").write_text(json.dumps(badge("page views", views)) + "\n", encoding="utf-8")
    (out / "downloads.json").write_text(json.dumps(badge("downloads", downloads)) + "\n", encoding="utf-8")
    print(f"visitors={unique} views={views} downloads={downloads}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
