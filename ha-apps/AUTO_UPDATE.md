# Safe TeamSpeak 6 Manager Auto-Update Flow

This repository uses a guarded Forgejo workflow for the TeamSpeak 6 Manager Home Assistant add-on.

## Safety model

The updater does **not** push directly to `main`.

Flow:

1. Resolve the latest `clusterzx/ts6-manager` upstream commit from `main`, or an explicitly supplied ref.
2. Pin `TS6_MANAGER_REF` directly in `ts6_manager/Dockerfile` as an `ARG` default.
3. Bump `ts6_manager/config.yaml` add-on version.
4. Update `ts6_manager/CHANGELOG.md`.
5. Run `scripts/validate-addon.sh`.
6. Push a candidate branch only:

```text
auto/ts6-manager-<shortsha>
```

Home Assistant sees an update only after you manually merge the candidate branch into `main`.

## build.yaml migration

`build.yaml` is intentionally no longer required for this add-on. Home Assistant warns that `build.yaml` is deprecated and that build parameters should live in the Dockerfile directly.

The Dockerfile is now the build source of truth:

```text
ts6_manager/Dockerfile
```

The former `build.yaml` values moved to Dockerfile statements:

```text
build_from  → final FROM ghcr.io/hassio-addons/base:16.3.2
labels      → LABEL io.hass.* / maintainer / OCI labels
args        → ARG BUILD_VERSION / BUILD_ARCH / TS6_MANAGER_REPO / TS6_MANAGER_BRANCH / TS6_MANAGER_REF
```

If `ts6_manager/build.yaml` still exists, remove it after this migration is committed and validated.

## Codeberg hosted runner note

Codeberg hosted runners may not expose a usable Docker daemon. Therefore the default validation mode is:

```text
VALIDATE_DOCKER=auto
```

This always runs static validation. Docker build and smoke-test run only when Docker is actually available.

For full validation use a self-hosted runner with Docker and set:

```text
VALIDATE_DOCKER=required
```

## Required files

Both workflows require these files to be committed at repository root:

```text
.forgejo/workflows/validate-addon.yaml
.forgejo/workflows/auto-update-ts6-manager.yaml
scripts/install-yq-ci.sh
scripts/validate-addon.sh
scripts/update-ts6-manager.sh
ts6_manager/Dockerfile
ts6_manager/config.yaml
```

`ts6_manager/build.yaml` is **not** required anymore.

## Release-on-main

Release creation remains separate and must run only after a candidate branch is merged into `main`.

Flow:

```text
candidate branch → pull request → merge into main → release-on-main creates Codeberg Release
```

Do not create Releases from candidate branches.


## v8 build.yaml-free release/push fixes

- `ts6_manager/build.yaml` is no longer required.
- Release-on-main reads upstream metadata from `ts6_manager/Dockerfile` ARG defaults.
- Auto-update candidate branch push handles an already existing remote branch via explicit `--force-with-lease`.
- This keeps the safe candidate flow intact while avoiding the Home Assistant `build.yaml` deprecation warning.
