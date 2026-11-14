#!/usr/bin/env python3
"""Fail if German text is found in a tracked file.

Everything in this repository is English (CLAUDE.md, "Language"). The only
places that keep German are the app translations (`*/translations/*.yaml`),
the CHANGELOGs (old hand-written entries) and the wiki pages.

The check is a word list, not a language detector: it flags umlauts and about
sixty common German words. It can miss a German line that has none of them, and
it should not flag English text. A line that is meant to stay can carry the
marker `lang-check:allow`.

Usage:
    python scripts/check_english_only.py            # check all tracked files
    python scripts/check_english_only.py --self-test
"""
import re
import subprocess
import sys

ALLOW_MARKER = "lang-check:allow"

SKIP_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg", ".zip", ".pdf", ".woff", ".woff2", ".lock",
)
SKIP_NAMES = ("package-lock.json", "CHANGELOG.md")
SKIP_PREFIXES = ("wiki/",)
SKIP_FILES = ("scripts/check_english_only.py",)

UMLAUT = re.compile("[äöüÄÖÜß]")
WORDS = re.compile(
    r"\b(nicht|und|oder|wird|werden|wurde|wurden|für|eine|einen|einem|einer|dass|weil|auch|noch|schon|"
    r"wenn|beim|vom|zum|zur|damit|sowie|sondern|ohne|jetzt|statt|keine|kein|haben|kann|können|muss|"
    r"müssen|bitte|Fehler|Datei|Ordner|Hinweis|Beispiel|Einstellung|Einstellungen|Konfiguration|"
    r"Ausgabe|gefunden|prüfen|starten|beenden|erfolgreich|fehlgeschlagen|Passwort|Benutzer|Zugriff|"
    r"Verbindung)\b"
)


def is_skipped(path: str) -> bool:
    if path in SKIP_FILES or path.endswith(SKIP_SUFFIXES):
        return True
    if path.split("/")[-1] in SKIP_NAMES or path.startswith(SKIP_PREFIXES):
        return True
    if "/translations/" in path or "node_modules/" in path:
        return True
    return False


def looks_german(line: str) -> bool:
    if ALLOW_MARKER in line:
        return False
    return bool(UMLAUT.search(line) or WORDS.search(line))


def check_text(text: str) -> list[tuple[int, str]]:
    return [(n, line.strip()) for n, line in enumerate(text.split("\n"), 1) if looks_german(line)]


def self_test() -> None:
    assert looks_german("Die Datei wurde nicht gefunden")
    assert looks_german("Prüfung")  # umlaut
    assert looks_german("echo 'Fehler beim Start'")
    assert not looks_german("The file was not found")
    assert not looks_german("Release Please opens a release PR")
    assert not looks_german("Datei nicht gefunden  # lang-check:allow")
    assert is_skipped("navidrome/translations/de.yaml") and is_skipped("forgejo/CHANGELOG.md")
    assert is_skipped("wiki/hwinfo-thermalguard/index.html") and is_skipped("ts6_manager/logo.png")
    assert not is_skipped("ts6_manager/DOCS.md") and not is_skipped(".github/workflows/00-meta-validate.yml")
    print("self-test passed")


def main() -> int:
    if "--self-test" in sys.argv:
        self_test()
        return 0
    files = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
    found = 0
    for path in files:
        if not path or is_skipped(path):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except (UnicodeDecodeError, OSError):
            continue  # binary or unreadable
        for number, line in check_text(text):
            print(f"{path}:{number}: {line[:120]}")
            found += 1
    if found:
        print(
            f"\nERROR: {found} line(s) look German. Everything outside translations, CHANGELOGs and the wiki "
            f"has to be English (CLAUDE.md). Translate the text, or add '{ALLOW_MARKER}' to a line that has to stay.",
            file=sys.stderr,
        )
        return 1
    print("No German text found outside translations, CHANGELOGs and the wiki.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
