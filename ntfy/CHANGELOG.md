# Changelog

## [1.2.5](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.2.4...ntfy-v1.2.5) (2026-07-25)


### Bug Fixes

* **ntfy:** disable apparmor after breaking production, profile needs rework ([c7d703f](https://github.com/pol4rfuchs/ha-apps/commit/c7d703f12468b8a518fecd66c075aa8e2e01c72a))

## [1.2.4](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.2.3...ntfy-v1.2.4) (2026-07-23)


### Bug Fixes

* **ntfy:** add de.yaml, apparmor profile, io.hass.arch label, --- header, drop -ha-app suffix, document missing visitor_* options ([231fc09](https://github.com/pol4rfuchs/ha-apps/commit/231fc091ca56fac365d97c3d56380132ea6846ba))

## [1.2.3](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.2.2...ntfy-v1.2.3) (2026-07-13)


### Bug Fixes

* **ntfy:** update upstream to 2.26.0 ([#171](https://github.com/pol4rfuchs/ha-apps/issues/171)) ([9df22fc](https://github.com/pol4rfuchs/ha-apps/commit/9df22fc5684497af00be2c7b2113e71b1e191fcd))

## [1.2.2](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.2.1...ntfy-v1.2.2) (2026-06-30)


### Bug Fixes

* **ntfy:** message-limit=0 is not unlimited on ntfy v2.25.0 ([b6c581b](https://github.com/pol4rfuchs/ha-apps/commit/b6c581bfac427bacc7d6965dac8fae12dab3623c))

## [1.2.1](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.2.0...ntfy-v1.2.1) (2026-06-28)


### Bug Fixes

* **ntfy:** quote message-size-limit as string in server.yml ([9466146](https://github.com/pol4rfuchs/ha-apps/commit/946614631af98f1c1e7d1d9340113cfd9657a7ee))

## [1.2.0](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.1.11...ntfy-v1.2.0) (2026-06-28)


### Features

* **ntfy:** add rate limits, message size limit and visitor attachment limits ([7d06b66](https://github.com/pol4rfuchs/ha-apps/commit/7d06b66da5d99fe04450556fd03f017ba3e53e16))

## [1.1.11](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.1.10...ntfy-v1.1.11) (2026-06-27)


### Bug Fixes

* **ntfy:** guard HA token provisioning against indefinite hang on boot ([fd35aa6](https://github.com/pol4rfuchs/ha-apps/commit/fd35aa67b0a497b85bd741fc306d2e1900ae20ec))

## [1.1.10](https://github.com/pol4rfuchs/ha-apps/compare/ntfy-v1.1.9...ntfy-v1.1.10) (2026-06-27)


### Bug Fixes

* **ntfy:** remove integrated admin panel (port 4281), ntfy_manager is the replacement ([0042f64](https://github.com/pol4rfuchs/ha-apps/commit/0042f6476958ab7f5b2d7bcdf78a980616b61fc5))
