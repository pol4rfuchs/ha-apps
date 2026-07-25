# Changelog

## [1.1.1](https://github.com/pol4rfuchs/ha-apps/compare/ts6_manager-v1.1.0...ts6_manager-v1.1.1) (2026-07-25)


### Bug Fixes

* **ts6_manager:** dereference prisma CLI symlinks when copying into deploy stage ([81c6817](https://github.com/pol4rfuchs/ha-apps/commit/81c6817622f11fe8fe015ffe7d894c36be274430))

## [1.1.0](https://github.com/pol4rfuchs/ha-apps/compare/ts6_manager-v1.0.5...ts6_manager-v1.1.0) (2026-07-25)


### Features

* **ts6_manager:** switch build source to own fork, add video-streaming sidecar ([f5f82b9](https://github.com/pol4rfuchs/ha-apps/commit/f5f82b90c6a18c8c64773e3681cc78137c0124a1))


### Bug Fixes

* **ts6_manager:** derive sidecar GOARCH from buildx TARGETARCH, not BUILD_ARCH ([61b8fbf](https://github.com/pol4rfuchs/ha-apps/commit/61b8fbfb6064da81457431ee3470e1811b87fe18))

## [1.0.5](https://github.com/pol4rfuchs/ha-apps/compare/ts6_manager-v1.0.4...ts6_manager-v1.0.5) (2026-07-23)


### Bug Fixes

* **ts6_manager:** add de.yaml, draft apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix, fix wrong port in nginx log message ([56cbf20](https://github.com/pol4rfuchs/ha-apps/commit/56cbf20553133d2e1f315d6aaaf61838e2802ba0))

## 1.0.2

- Update upstream clusterzx/ts6-manager to dd26e57954feca794fcceac0fb982243897d9114.
- Upstream commit: https://github.com/clusterzx/ts6-manager/commit/dd26e57954feca794fcceac0fb982243897d9114
- Commit date: 2026-03-28
- Commit author: Your friendly nerd
- Commit subject: Merge pull request #45 from GingerFury6/fix-video-known-limitations

## 1.0.1

- Update upstream clusterzx/ts6-manager to dd26e57954feca794fcceac0fb982243897d9114.
- Upstream commit: https://github.com/clusterzx/ts6-manager/commit/dd26e57954feca794fcceac0fb982243897d9114
- Commit date: 2026-03-28
- Commit author: Your friendly nerd
- Commit subject: Merge pull request #45 from GingerFury6/fix-video-known-limitations

## 1.0.0

- Initial TS6 Manager Home Assistant add-on package.
- Safe auto-update flow pins upstream `clusterzx/ts6-manager` by commit SHA instead of floating `main`.
