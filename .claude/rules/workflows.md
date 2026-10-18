---
paths:
  - ".github/workflows/**"
---

# GitHub-Workflows

- Runner `ubuntu-24.04`, nie `ubuntu-latest` (auch in der Matrix von `build-app.yaml`).
- Actions per Commit-SHA pinnen, die Version im Kommentar dahinter (`# v7.0.1`).
- Dateiname nummeriert (`NN-name.yml`); die Workflows 12 (hadolint), 13 (yamllint), 14 (actionlint) müssen grün sein.
- YAML ohne Doppel-Leerzeichen und ohne Leerzeichen am Zeilenende (yamllint).
- Jobs, die als Pflichtprüfung gedacht sind, bekommen keinen Pfad-Filter (so begründet es Workflow 29: sonst bleibt der Check „pending“).
- Setzt ein Workflow ein Label, das nicht in `.github/labels.yml` steht, dort ergänzen.
- `actionlint` läuft lokal nur über den Stop-Hook in Docker (wenn Docker Desktop läuft und das Image lokal vorhanden ist).
  Meldet der Hook „übersprungen“, Änderungen sorgfältig gegenlesen und im PR sagen, dass nur die CI sie geprüft hat.
