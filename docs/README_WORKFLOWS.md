# ha-apps workflow map

This repository uses a compact monorepo workflow set. Do not mix this set with the generic numbered workflow pack (`00-meta-validate.yml` to `15-zizmor.yml`). Those files are not required for the current ha-apps pipeline and create duplicate/unclear CI behavior.

## Active workflows

| Workflow | Purpose | Scope |
|---|---|---|
| `.github/workflows/build-ghcr-registry.yml` | Build and push multi-arch GHCR images | `ts6_manager`, `teamspeak6`, `ntfy`, `navidrome`, `matrix_synapse`, `nginx_proxy_manager` |
| `.github/workflows/build-intiface.yml` | Build and push Intiface image | `intiface_central` |
| `.github/workflows/build-searxng.yml` | Build and push SearXNG image | `searxng` |
| `.github/workflows/ntfy_manager.yml` | Digest-based multi-arch build + manifest merge | `ntfy_manager` |
| `.github/workflows/validate-addon.yaml` | Static add-on validation + optional Docker smoke build | all add-ons |
| `.github/workflows/release-on-main.yaml` | Create GitHub releases from `config.yaml` versions | all add-ons |
| `.github/workflows/auto-update-ts6-manager.yaml` | Safe update candidates/PRs for supported upstreams | supported add-ons, no-op for unsafe sources |
| `.github/workflows/ghcr-cleanup.yml` | Delete old untagged GHCR container versions | all configured packages |

## GHCR package access requirement

Each existing GHCR package must grant this repository write access:

```text
Package settings → Manage Actions access → pol4rfuchs/ha-apps → Write/Admin
```

Packages to check:

```text
intiface-ha-app
matrix-synapse-ha-app
navidrome-ha-app
npm-ha-app
ntfy-ha-app
ntfy-manager-ha-app
searxng-ha-app
teamspeak6-ha-app
teamspeak6-manager-ha-app
```

A failed build with this error is a package access problem, not a workflow-code problem:

```text
denied: permission_denied: write_package
```

## Obsolete files

Remove these when migrating from older workflow packs:

```text
.github/workflows/00-meta-validate.yml
.github/workflows/01-addon-lint.yml
.github/workflows/02-build-test.yml
.github/workflows/03-build-publish-ghcr.yml
.github/workflows/04-release-from-config.yml
.github/workflows/05-security-scan.yml
.github/workflows/06-update-upstream-candidate.yml
.github/workflows/07-dependabot-pr-check.yml
.github/workflows/08-docs-pages.yml
.github/workflows/09-hacs-validate.yml
.github/workflows/10-hassfest.yml
.github/workflows/11-python-tests.yml
.github/workflows/12-dockerfile-lint.yml
.github/workflows/13-yaml-json-lint.yml
.github/workflows/14-actionlint.yml
.github/workflows/15-zizmor.yml
.github/workflows/build-app.yaml
scripts/validate-addon.sh
```
