"""Validate the wiki/ folder structure before it gets deployed by
08-docs-pages.yml.

Adapted from the standalone ha-appwikis repo's validate_wikis.py, scoped to
run against the wiki/ subfolder of this monorepo instead of a repo root.
"""
import re
import sys
import os
import glob

WIKI_DIR = "wiki"
errors = 0

if not os.path.isdir(WIKI_DIR):
    print(f"ERROR: {WIKI_DIR}/ directory not found in repo root")
    sys.exit(1)

os.chdir(WIKI_DIR)

# ── 1. Every wiki folder must have a non-stub index.html ──────────
print("=== Folder check ===")
for d in sorted(glob.glob("*/")):
    if d == "assets/":
        continue
    path = os.path.join(d.rstrip("/"), "index.html")
    if not os.path.exists(path):
        print(f"  MISSING  {path}")
        errors += 1
    else:
        size = os.path.getsize(path)
        if size < 500:
            print(f"  STUB     {path}  ({size} bytes)")
            errors += 1
        else:
            print(f"  OK       {path}  ({size} bytes)")

# ── 2. Every hub card on the index must link to an existing folder ─
print("\n=== Card -> folder check ===")
with open("index.html", encoding="utf-8") as f:
    html = f.read()

hrefs = re.findall(r'<a class="card"[^>]*href="\./([^/]+)/"', html)
for slug in hrefs:
    path = os.path.join(slug, "index.html")
    if not os.path.exists(path):
        print(f"  BROKEN   card ./{slug}/ has no folder")
        errors += 1
    else:
        print(f"  OK       ./{slug}/")

# ── 3. No leftover references to the retired ha-appwikis repo ─────
print("\n=== Stale-reference check ===")
for path in glob.glob("**/*.html", recursive=True):
    with open(path, encoding="utf-8") as f:
        content = f.read()
    if "ha-appwikis" in content:
        print(f"  STALE REF  {path} still references ha-appwikis/")
        errors += 1

if errors == 0:
    print("\nAll checks passed.")

sys.exit(errors)
