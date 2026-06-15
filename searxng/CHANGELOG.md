# Changelog

## [1.0.3](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.2...searxng-vv1.0.3) (2026-06-15)


### Bug Fixes

* **searxng:** update upstream to 2026.6.15-cf ([1b8d10e](https://github.com/pol4rfuchs/ha-apps/commit/1b8d10e5862c478b65a92088248796f840f5019d))
* **searxng:** update upstream to 2026.6.15-cf ([9af53ef](https://github.com/pol4rfuchs/ha-apps/commit/9af53efd2347bc8cda20de59de60198d04a8ac40))

## 2026.3.8

- Initiales Release
- Basiert auf `searxng/searxng:latest`
- Ingress-Support mit automatischer Base-URL-Erkennung
- Secret Key wird persistent in `addon_config` gespeichert
- Default `settings.yml` wird beim Erststart automatisch angelegt
- `custom.sh` Hook für eigene Befehle vor dem Start
