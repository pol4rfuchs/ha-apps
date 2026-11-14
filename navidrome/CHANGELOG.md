# Changelog

## [2.1.14](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.13...navidrome-v2.1.14) (2026-11-14)


### Bug Fixes

* **navidrome:** fall back from an invalid scan schedule, document schedule and WAV track numbers ([#929](https://github.com/pol4rfuchs/ha-apps/issues/929)) ([e85201b](https://github.com/pol4rfuchs/ha-apps/commit/e85201ba9c9bb41c330a731731b90ac8bb7d96f4))

## [2.1.13](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.12...navidrome-v2.1.13) (2026-11-13)


### Bug Fixes

* **apps:** clear Supervisor warnings (translations network, app_config map) ([#870](https://github.com/pol4rfuchs/ha-apps/issues/870)) ([74b5408](https://github.com/pol4rfuchs/ha-apps/commit/74b54080a750ff55f3dff6fe9714a1c469764d57))

## [2.1.12](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.11...navidrome-v2.1.12) (2026-10-25)


### Bug Fixes

* **navidrome:** add the standard log_level option ([#671](https://github.com/pol4rfuchs/ha-apps/issues/671)) ([71f8a4c](https://github.com/pol4rfuchs/ha-apps/commit/71f8a4ccca1df9299b50cc99a63d8a8a6d296c0c))

## [2.1.11](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.10...navidrome-v2.1.11) (2026-10-16)


### Bug Fixes

* **navidrome:** remove options that do nothing, make ND_EXTRA_MUSIC_FOLDERS real, correct the docs ([#567](https://github.com/pol4rfuchs/ha-apps/issues/567)) ([58f7746](https://github.com/pol4rfuchs/ha-apps/commit/58f77461b0a82d780129ab7018c27b257f580dfc))

## [2.1.10](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.9...navidrome-v2.1.10) (2026-09-27)

## [2.1.9](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.8...navidrome-v2.1.9) (2026-09-26)

### Bug Fixes

* **navidrome:** update upstream to 0.64.2 (changelog: https://github.com/navidrome/navidrome/releases/tag/v0.64.2) ([#430](https://github.com/pol4rfuchs/ha-apps/issues/430)) ([1efd138](https://github.com/pol4rfuchs/ha-apps/commit/1efd138fc70a5feb23f6b0a76013d6f3e1441528))

## [2.1.8](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.7...navidrome-v2.1.8) (2026-09-23)

### Bug Fixes

* **navidrome:** update upstream to 0.64.1 (changelog: https://github.com/navidrome/navidrome/releases/tag/v0.64.1) ([#410](https://github.com/pol4rfuchs/ha-apps/issues/410)) ([7cf860a](https://github.com/pol4rfuchs/ha-apps/commit/7cf860aaa6fee968e4698c20d0e0d1ed24ada4c8))

## [2.1.7](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.6...navidrome-v2.1.7) (2026-09-19)

### Bug Fixes

* **navidrome:** update upstream to 0.64.0 (changelog: https://github.com/navidrome/navidrome/releases/tag/v0.64.0) ([#382](https://github.com/pol4rfuchs/ha-apps/issues/382)) ([685d253](https://github.com/pol4rfuchs/ha-apps/commit/685d2535ab0eee86cbdb63f2f43ddf6047d5ba04))

## [2.1.6](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.5...navidrome-v2.1.6) (2026-09-07)

### Bug Fixes

* **navidrome:** parameterize upstream image tag via ARG NAVIDROME_VERSION ([36ccefc](https://github.com/pol4rfuchs/ha-apps/commit/36ccefc71353898d7a1189079d1e1770158226eb))

## [2.1.5](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.4...navidrome-v2.1.5) (2026-07-23)

### Bug Fixes

* **navidrome:** correct swapped en/de translations, add apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix and deprecated hassio_api, remove insecure curl TLS bypass ([6bd16bc](https://github.com/pol4rfuchs/ha-apps/commit/6bd16bcaee76f930f9869a5afd1994e2cb239c91))

## [2.1.4](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.3...navidrome-v2.1.4) (2026-07-13)

### Bug Fixes

* **navidrome:** update upstream to 0.63.2 ([#168](https://github.com/pol4rfuchs/ha-apps/issues/168)) ([cfe7905](https://github.com/pol4rfuchs/ha-apps/commit/cfe79050bf5a49d0ae23377fc1fe8f4cb2a269d3))

## [2.1.3](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.2...navidrome-v2.1.3) (2026-06-26)

### Bug Fixes

* **navidrome:** ND_DATAFOLDER corrected to the persistent /data path ([b777d13](https://github.com/pol4rfuchs/ha-apps/commit/b777d1393d45f88d22e261e989634282362a8273))

## v2.1.0

### Bug fixes
- **ENV persistence**: `ha_entrypoint.sh` sources init scripts with `.` instead of a `bash` subshell — all `ND_*` variables now really reach Navidrome
- **Belt and suspenders**: additionally `/run/navidrome.env` is written and sourced in `navidrome-run.sh` (double safeguard)
- **Ingress SPA fix**: `ND_BASEURL` is set dynamically from `bashio::addon.ingress_entry` — the Navidrome SPA now works correctly behind the HA Ingress path
- Removed the `sub_filter` hack from nginx (it was broken and unnecessary with `ND_BASEURL`)
- nginx `ingress.conf`: `proxy_buffering off` for streaming, `/healthz` endpoint instead of `/ping`

### New features
- **Multiple music folders**: `ND_EXTRA_MUSIC_FOLDERS` (comma-separated) — are mounted as symlinks under `ND_MUSICFOLDER`
- **Jukebox**: `privileged: true` + ALSA-Devices (`/dev/snd`) in `config.yaml` — the jukebox now works
- **Podcasts**: `ND_PODCAST_EPSIODEKEEPCOUNT`, `ND_PODCAST_EPSIODEDOWLOADCOUNT`
- **Scanner/Extractor**: `ND_SCANNER_EXTRACTOR` (taglib/ffmpeg), `ND_FFMPEGPATH`
- All options are now described in `translations/en.yaml`

## v2.0.0

- Initial rewrite based on the celynw/ha-addons baseline
- Full option coverage

## v1.0_0.54.5 (upstream celynw baseline)

- Last upstream version: [v0.54.5](https://github.com/navidrome/navidrome/releases/tag/v0.54.5)
