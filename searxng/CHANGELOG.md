# Changelog

## [1.0.10](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.9...searxng-v1.0.10) (2026-07-21)


### Bug Fixes

* **searxng:** update upstream to 2026.7.19-6d ([#192](https://github.com/pol4rfuchs/ha-apps/issues/192)) ([62f05b0](https://github.com/pol4rfuchs/ha-apps/commit/62f05b07e5efe1e60449282db0ce93e698c32452))

## [1.0.9](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.8...searxng-v1.0.9) (2026-07-13)


### Bug Fixes

* **searxng:** update upstream to 2026.7.12-74 ([#170](https://github.com/pol4rfuchs/ha-apps/issues/170)) ([7432bc1](https://github.com/pol4rfuchs/ha-apps/commit/7432bc12fb9dc3106b224d7a25b3bc877010c24b))

## [1.0.8](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.7...searxng-v1.0.8) (2026-07-06)


### Bug Fixes

* **searxng:** update upstream to 2026.7.6-556 ([#150](https://github.com/pol4rfuchs/ha-apps/issues/150)) ([f183af5](https://github.com/pol4rfuchs/ha-apps/commit/f183af5680ed7e6df7fa809a45813d3e4807a264))

## [1.0.7](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.6...searxng-v1.0.7) (2026-06-29)


### Bug Fixes

* **searxng:** update upstream to 2026.6.29-13 ([#99](https://github.com/pol4rfuchs/ha-apps/issues/99)) ([fce7080](https://github.com/pol4rfuchs/ha-apps/commit/fce708008c0311c0753be2b748c44b410787ff4d))

## [1.0.6](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.5...searxng-v1.0.6) (2026-06-27)


### Bug Fixes

* **searxng:** update upstream to 2026.6.26-f8 ([#79](https://github.com/pol4rfuchs/ha-apps/issues/79)) ([8202f28](https://github.com/pol4rfuchs/ha-apps/commit/8202f28bd68b57b5e997bfe4463839a825e3657e))

## [1.0.5](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.4...searxng-v1.0.5) (2026-06-22)


### Bug Fixes

* **searxng:** update upstream to 2026.6.22-ae ([#52](https://github.com/pol4rfuchs/ha-apps/issues/52)) ([2bd14b4](https://github.com/pol4rfuchs/ha-apps/commit/2bd14b4f137b79a32e762e5ac59d883d7a99d5c7))

## [1.0.4](https://github.com/pol4rfuchs/ha-apps/compare/searxng-v1.0.3...searxng-v1.0.4) (2026-06-16)


### Bug Fixes

* **searxng:** update upstream to 2026.6.15-cf ([1b8d10e](https://github.com/pol4rfuchs/ha-apps/commit/1b8d10e5862c478b65a92088248796f840f5019d))
* **searxng:** update upstream to 2026.6.15-cf ([9af53ef](https://github.com/pol4rfuchs/ha-apps/commit/9af53efd2347bc8cda20de59de60198d04a8ac40))

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
