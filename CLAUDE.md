# ha-apps

Monorepo für Home-Assistant-Apps (Add-ons). Jeder Top-Level-Ordner mit `config.yaml` ist eine App,
die einzeln gebaut, versioniert und released wird. Remote: `pol4rfuchs/ha-apps`.

Verbindlicher Regelkatalog: Skill `ha-apps-buildrules` (`references/appbuildrules.md`, Port-Tabelle in
`references/port-table.md`). Bei Arbeit an Dockerfile, `config.yaml`, `apparmor.txt`, Translations oder
Workflows den Skill nutzen. Aufbau eines App-Ordners und CI-Regeln: `CONTRIBUTING.md`.
Offener Backlog: liegt lokal beim Maintainer, nicht im Repo (`OFFENE_PUNKTE.md` steht in `.gitignore`).

Aufbau: `<app>/` je App (Ordner mit `config.yaml`), `.github/workflows/` (nummeriert), `scripts/` (`check_apparmor.py`,
`sync_version_badges.py`, `validate_wiki.py`), `wiki/` (Wiki-Seiten), `docs/`, Manifeste im Wurzelverzeichnis.
Der Nutzer will Listen, keine Git-Befehle.

## Befehle

```bash
python -m yamllint -c .yamllint .                       # gesamtes Repo
python -m yamllint -f parsable -c .yamllint */config.yaml */translations .github
docker build --build-arg BUILD_ARCH=amd64 --build-arg BUILD_VERSION=test -t ha-test-<app> ./<app>
```

`hadolint`, `actionlint` und `shellcheck` sind lokal nicht installiert. Der Stop-Hook startet sie über Docker
(dieselben Images wie die CI, in `.claude/hooks/stop_check.py` per Digest gepinnt), aber nur, wenn Docker Desktop läuft
und das Image schon lokal vorhanden ist. Sonst meldet er „übersprungen“, das ist **kein** bestandener Check.
`apparmor_parser` und `scripts/check_apparmor.py` brauchen Linux und laufen nur in der CI (Workflow 29).

## Arbeitsregeln

- **Nie pushen oder mergen.** Nur lokal committen; Push und Merge macht der Nutzer selbst
  (in `.claude/settings.local.json` zusätzlich gesperrt: `git push`, `gh pr merge`, `rm`, `git reset`).
- Ein Branch und ein PR pro App, Branch von `origin/main` mit `--no-track`.
  PR-Titel: Conventional Commit mit App-Scope (`fix(ntfy): …`, `feat(ts6_manager): …`, sonst `chore:`/`docs(scope):`).
- `CHANGELOG.md` erzeugt Release Please: **nicht von Hand ändern**. `version:` in `config.yaml` wird per Workflow 05 aus dem
  Release-Please-Manifest synchronisiert und nicht für lokale Tests hochgezählt. Einzige Ausnahme (Katalog §7): eine rein
  interne Dependency-Änderung ohne Upstream-Wechsel, die Nutzer sofort bekommen sollen; dann `version:` um eine Patch-Stufe
  erhöhen, damit HA ein Update anzeigt.
- Vor jedem Commit bauen und testen: zweimal starten, jeweils in einem neuen Container mit demselben `/data`.
  Nicht testbar ohne Pi bzw. HAOS: AppArmor im Enforce-Modus, Supervisor-Optionsprüfung. Das im PR sagen.
- Befunde nur aus dem Code sind Verdacht, bis sie getestet sind.
- Bei allem, was sich seit dem Trainingsstand geändert haben kann (Base-Image-Tags, Supervisor, Actions-Verhalten):
  vorher recherchieren, nicht aus der Snapshot-Tabelle in §16 abschreiben.
- AppArmor-Profile nicht nebenbei ändern.
- Kein pauschales Suchen-und-Ersetzen „addon → app“: Ordner, Dateinamen, Slugs, Image-Namen, `map:`-Werte wie `addon_config`
  und Workflow-Namen bleiben unverändert (Katalog §17).
- Keine Verweise auf die frühere Forge (Codeberg-Domains, Forgejo-Punktordner) in neuen Zeilen; Forgejo mit
  `https://forgejo.org` verlinken. Ausnahme nur mit dem Marker `forge-check:allow`. Workflow 00 prüft das im ganzen Repo,
  deshalb diese Zeichenketten auch hier nicht ausschreiben.
- Keine Schlüssel oder Passwörter ins Repo. Passwort-Optionen: Schema `password`, kein Default.

## Struktur, die man nicht aus dem Code ableitet

- Neue App zusätzlich eintragen in `addons.json`, `release-please-config.json`, `.release-please-manifest.json`.
- Host-Ports sind repo-weit eindeutig (Tabelle im Skill prüfen, bevor ein Port vergeben wird).
- Optionen in `config.yaml` müssen wirken; `translations/en.yaml` und `de.yaml` bleiben mit dem Schema synchron.
- Workflows sind nummeriert (`00`–`30`); Actions per Commit-SHA gepinnt, Runner `ubuntu-24.04`.
- Labels stehen in `.github/labels.yml`.
