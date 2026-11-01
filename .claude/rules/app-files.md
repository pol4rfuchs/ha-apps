---
paths:
  - "*/config.yaml"
  - "*/Dockerfile"
  - "*/apparmor.txt"
  - "*/translations/*.yaml"
  - "*/rootfs/**"
---

# App files (build rules)

Consult the skill `ha-apps-buildrules` before changing these files; if anything contradicts, `appbuildrules.md` wins.

- Architectures: only `aarch64` and `amd64`. Never `armhf`, `armv7` or `i386`, neither in `config.yaml` nor in the Dockerfile (catalog §1).
- `Dockerfile`: `ARG BUILD_FROM` contains `${BUILD_ARCH}` (except for an official multi-arch tag). Declare `ARG BUILD_ARCH` and
  `BUILD_VERSION` again after `FROM`. Label `io.hass.type="app"`. Upstream binary with a smoke test (`RUN x --version`).
  Do not generate keys at build time. Do not forget `chmod +x` for s6 scripts (`run`, `finish`).
- `config.yaml`: starts with `---`. Passwords with schema `password`, without a default. Lists as `["str"]`.
  `log_level` in every app, and the option must really take effect in the application.
- `translations/en.yaml` and `de.yaml` stay in sync with the schema.
- `apparmor.txt`: needs the s6-overlay baseline, otherwise a crash loop on restart. Change it only deliberately; enforce mode is only testable on the Pi.
- bashio scripts run with `errexit`/`pipefail`/`nounset`: `x="$(cmd)" || rc=$?`, never `export VAR="$(cmd)"`; `cd … || exit 1`.
- After changes: `python -m yamllint -c .yamllint <changed files>` and a Docker test (start twice, same `/data`).
