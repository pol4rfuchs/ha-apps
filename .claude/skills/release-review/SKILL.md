---
name: release-review
description: Prüft einen offenen Release-Please-PR eines Add-ons, bevor er gemergt wird (Tag der Vorgängerversion, Changelog nur mit neuen Commits, Checks, Titel, Umfang). Liest nur, mergt und pusht nie. Aufruf mit dem Add-on-Slug oder der PR-Nummer, z. B. /release-review ntfy.
disable-model-invocation: true
allowed-tools: Read, Bash(gh pr list *), Bash(gh pr view *), Bash(gh release list *), Bash(git tag *), Bash(git log *), Bash(git show *), Bash(git status *)
argument-hint: <slug oder PR-Nummer>
---

# Release-PR prüfen: $ARGUMENTS

Grundlage ist Katalog §7 (Skill `ha-apps-buildrules`, Abschnitt „Versionierung / Release Please“). Dieser Skill liest nur: nichts mergen, nichts pushen, keine Tags oder Releases anlegen, kein `gh api`.

## Ablauf

1. **PR finden.** Ist `$ARGUMENTS` eine Zahl, den PR direkt öffnen (`gh pr view <n> --json number,title,body,files,statusCheckRollup,mergeable,labels`). Sonst `gh pr list --state open --search "release $ARGUMENTS in:title"`. Gibt es mehrere oder keinen, anhalten und fragen.
2. **Vorgänger-Tag prüfen.** Version des Add-ons aus `.release-please-manifest.json` auf `origin/main` lesen (`git show origin/main:.release-please-manifest.json`). Existiert der Tag `<slug>-v<Version>` (`git tag -l "<slug>-v*"`, ergänzend `gh release list`)? Fehlt er, ist das der bekannte Fehler „fehlender Anker“: den PR **nicht** mergen und das so melden.
3. **Changelog nur mit neuen Commits.** Die Commits seit dem Vorgänger-Tag zählen (`git log <slug>-v<alt>..origin/main --oneline -- <slug>/`) und mit den Einträgen im PR-Text vergleichen. Wiederholte alte Einträge oder ein aufgeblähter Changelog: nicht mergen, Ursache im Log von „05 Release Please“ klären (§7).
4. **Checks.** Alle Einträge aus `statusCheckRollup` ansehen, nicht nur den Gesamtstatus. Offene, rote oder übersprungene Checks einzeln nennen. Renovate-Hinweise zu `minimumReleaseAge` oder Lock-Dateien sind informativ und blockieren nicht.
5. **Umfang und Titel.** Der Titel folgt `chore(main): release <slug> x.y.z`. Geänderte Dateien dürfen nur unter `<slug>/` sowie im Manifest liegen. Ein PR mit mehreren Add-ons ist ein Fehler.
6. **Reihenfolge.** Laut §7 zuerst die eigenen Fix-PRs, dann Renovate, zuletzt Release-PRs, und Release-PRs nacheinander, nie gleichzeitig (sonst Manifest-Konflikte). Melde, ob für andere Add-ons noch Release-PRs offen sind.

## Ausgabe

Eine Liste, kein Git-Befehl. Je Punkt 1 bis 6: **in Ordnung**, **nicht in Ordnung** oder **nicht geprüft** (mit Grund). Am Ende genau eine Empfehlung: „mergen“ oder „nicht mergen, weil …“. Die Entscheidung und das Mergen bleiben beim Nutzer.
