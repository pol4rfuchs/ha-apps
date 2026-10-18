---
paths:
  - "*/config.yaml"
  - "*/Dockerfile"
  - "*/apparmor.txt"
  - "*/translations/*.yaml"
  - "*/rootfs/**"
---

# App-Dateien (Buildrules)

Vor Änderungen an diesen Dateien den Skill `ha-apps-buildrules` heranziehen; gilt `appbuildrules.md`, wenn sich etwas widerspricht.

- `Dockerfile`: `ARG BUILD_FROM` enthält `${BUILD_ARCH}` (außer bei offiziellem Multi-Arch-Tag). `ARG BUILD_ARCH` und
  `BUILD_VERSION` nach `FROM` erneut deklarieren. Label `io.hass.type="app"`. Upstream-Binary mit Smoke-Test (`RUN x --version`).
  Keine Schlüssel zur Build-Zeit erzeugen. `chmod +x` für s6-Skripte (`run`, `finish`) nicht vergessen.
- `config.yaml`: beginnt mit `---`. Passwörter mit Schema `password`, ohne Default. Listen als `["str"]`.
  `log_level` in jeder App, und die Option muss wirklich bis in die Anwendung wirken.
- `translations/en.yaml` und `de.yaml` bleiben mit dem Schema synchron.
- `apparmor.txt`: braucht die s6-overlay-Baseline, sonst Crash-Loop beim Neustart. Nur gezielt ändern, Enforce nur am Pi testbar.
- bashio-Skripte laufen mit `errexit`/`pipefail`/`nounset`: `x="$(cmd)" || rc=$?`, nie `export VAR="$(cmd)"`; `cd … || exit 1`.
- Nach Änderungen: `python -m yamllint -c .yamllint <geänderte Dateien>` und Docker-Test (zweimal starten, gleiches `/data`).
