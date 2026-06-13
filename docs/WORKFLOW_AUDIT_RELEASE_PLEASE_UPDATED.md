# ha-apps workflow audit + Release Please migration

## Status

**Result:** GO, with runtime prerequisites.

This document supersedes the older v4 audit text. The previous audit still described pre-migration defects as if they were current and had stale add-on versions for several packages.

## Scope

`addons.json` contains 12 add-on directories. Release Please manages 10 of them. `forgejo` and `unbound` stay manual.

| Add-on | Current `config.yaml` version | Image | Release Please |
|---|---:|---|---:|
| `forgejo` | `16.0.0` | `ghcr.io/pol4rfuchs/forgejo-ha-app` | manual |
| `intiface_central` | `1.0.0` | `ghcr.io/pol4rfuchs/intiface-ha-app` | yes |
| `matrix_synapse` | `1.2.11` | `ghcr.io/pol4rfuchs/matrix-synapse-ha-app` | yes |
| `navidrome` | `2.1.2` | `ghcr.io/pol4rfuchs/navidrome-ha-app` | yes |
| `nginx_proxy_manager` | `2.1.3` | `ghcr.io/pol4rfuchs/npm-ha-app` | yes |
| `ntfy` | `1.1.8` | `ghcr.io/pol4rfuchs/ntfy-ha-app` | yes |
| `ntfy_manager` | `0.2.1` | `ghcr.io/pol4rfuchs/ntfy-manager-ha-app` | yes |
| `nextcloud` | `33.0.6` | `ghcr.io/pol4rfuchs/nextcloud-ha-app` | yes |
| `searxng` | `1.0.2` | `ghcr.io/pol4rfuchs/searxng-ha-app` | yes |
| `teamspeak6` | `1.1.13` | `ghcr.io/pol4rfuchs/teamspeak6-ha-app` | yes |
| `ts6_manager` | `1.0.4` | `ghcr.io/pol4rfuchs/teamspeak6-manager-ha-app` | yes |
| `unbound` | `1.24.2-ha38-pol4r1` | `ghcr.io/pol4rfuchs/unbound-ha-app` | manual |

## Current Release Please files

These files belong in the repository root:

```text
.release-please-manifest.json
release-please-config.json
```

These files belong in `.github/workflows/`:

```text
03-build-publish-ghcr.yml
04-release-from-config.yml
04-release-please.yml
06-update-upstream-candidate.yml
18-conventional-pr-title.yml
```

## Fixed migration blockers

### 1. Release authority conflict resolved

`04-release-from-config.yml` must not create releases anymore. It is acceptable only as a disabled/manual stub:

```yaml
on:
  workflow_dispatch:
```

Release authority after migration:

```text
04-release-please.yml
```

GHCR publishing authority after migration:

```text
03-build-publish-ghcr.yml on tags matching <addon>-v<version>
```

Keeping two files named `04-*` is technically safe. Keeping two active release workflows is not safe.

### 2. Release Please token fixed

`04-release-please.yml` must use:

```yaml
with:
  token: ${{ secrets.APP_TOKEN }}
  config-file: release-please-config.json
  manifest-file: .release-please-manifest.json
  target-branch: main
```

Without a real `APP_TOKEN`, Release Please may create tags with `GITHUB_TOKEN`, and follow-up workflows such as GHCR publishing may not run reliably.

Minimum `APP_TOKEN` capabilities:

```text
contents: write
pull_requests: write
issues: write
```

Also verify in repository settings:

```text
Settings → Actions → General → Workflow permissions → Allow GitHub Actions to create and approve pull requests
```

### 3. Manifest versions corrected

The manifest now matches the current `config.yaml` versions for the 10 Release Please-managed add-ons:

```json
{
  "intiface_central": "1.0.0",
  "matrix_synapse": "1.2.11",
  "navidrome": "2.1.2",
  "nginx_proxy_manager": "2.1.3",
  "ntfy": "1.1.8",
  "ntfy_manager": "0.2.1",
  "nextcloud": "33.0.6",
  "searxng": "1.0.2",
  "teamspeak6": "1.1.13",
  "ts6_manager": "1.0.4"
}
```

`forgejo` and `unbound` are intentionally absent from the manifest.

### 4. `bootstrap-sha` validated

Configured value:

```text
aee5755b0895b0706d0679d40eb97497d760a229
```

Local validation command:

```powershell
cd C:\Users\Wuest3nFuchs\Git-projects\ha-apps-main; git cat-file -t aee5755b0895b0706d0679d40eb97497d760a229
```

Expected output:

```text
commit
```

The user already verified this locally.

### 5. Updater version ownership fixed

`06-update-upstream-candidate.yml` must update only the add-on `Dockerfile` upstream reference or image tag.

It must not update:

```text
<addon>/config.yaml
<addon>/CHANGELOG.md
.release-please-manifest.json
```

Those files are owned by Release Please.

Correct flow:

```text
06 updater PR: fix(<addon>): update upstream to <version/ref>
↓
merge updater PR into main
↓
Release Please opens chore(<addon>): release <addon> <next-version>
↓
merge Release Please PR
↓
Release Please creates tag <addon>-v<version>
↓
03-build-publish-ghcr.yml builds only that add-on
```

### 6. Regex replacement in `06` fixed

The Dockerfile version update must use callback replacement, not index slicing over old regex matches.

Safe pattern:

```python
def _replace_version_arg(m):
    old_val = m.group(2)
    if re.match(r"\d{4}\.\d+\.\d+", old_val) or re.match(r"\d+\.\d+", old_val):
        return m.group(1) + value
    return m.group(0)
text = tag_pattern.sub(_replace_version_arg, text)
```

This prevents corrupting Dockerfiles when multiple `ARG *_VERSION=` lines exist.

### 7. PR title guard fixed

`18-conventional-pr-title.yml` should enforce add-on scopes for release-producing changes:

```text
fix(ntfy): update upstream to 2.14.0
feat(ts6_manager): add backup scheduler
```

Housekeeping remains allowed:

```text
chore(ci): update pinned GitHub Actions
chore: update repository metadata
```

Release Please bot PRs must pass:

```text
chore(ntfy): release ntfy 1.1.9
chore(main): release ntfy 1.1.9
```

## Remaining runtime gates

These cannot be fully proven from local static validation:

| Gate | Required result |
|---|---|
| `APP_TOKEN` secret exists | yes |
| `APP_TOKEN` can push branches | yes |
| `APP_TOKEN` can open PRs | yes |
| Release Please can create tags/releases | yes |
| GHCR packages grant repo write access | yes |
| `03-build-publish-ghcr.yml` runs from Release Please-created tag | yes |
| Built GHCR image tag equals add-on `config.yaml` version | yes |

## GHCR package access checklist

Each GHCR package used by `image:` should grant this repo write access:

```text
Package settings → Manage Actions access → pol4rfuchs/ha-apps → Write/Admin
```

Check at least:

```text
forgejo-ha-app
intiface-ha-app
matrix-synapse-ha-app
navidrome-ha-app
npm-ha-app
ntfy-ha-app
ntfy-manager-ha-app
nextcloud-ha-app
searxng-ha-app
teamspeak6-ha-app
teamspeak6-manager-ha-app
unbound-ha-app
```

Release Please only creates automatic tags for the 10 managed add-ons, but manual/dispatch GHCR builds can still involve the full `addons.json` list.

## First live test checklist

Use one safe add-on first. `ntfy` is a good candidate.

1. Ensure migration branch contains only workflow/release files, not unrelated docs.
2. Merge migration PR.
3. Wait for `04-release-please.yml` on `main`.
4. Confirm Release Please opens a PR titled like:

```text
chore(ntfy): release ntfy <next-version>
```

5. Confirm `18-conventional-pr-title.yml` passes on that Release Please PR.
6. Confirm the Release Please PR touches only expected files for the affected add-on:

```text
ntfy/config.yaml
ntfy/CHANGELOG.md
.release-please-manifest.json
```

7. Merge the Release Please PR.
8. Confirm tag exists:

```text
ntfy-v<version>
```

9. Confirm `03-build-publish-ghcr.yml` starts from that tag.
10. Confirm the build matrix contains only:

```text
ntfy
```

11. Confirm GHCR has:

```text
ghcr.io/pol4rfuchs/ntfy-ha-app:<version>
```

12. Confirm Home Assistant can pull/update the add-on.

## Final decision

```text
GO with current fixed files.
```

Do not merge if any of these are missing:

```text
APP_TOKEN
GHCR package write access
03 tag-driven build workflow
04-release-from-config disabled or deleted
06 no longer bumps config.yaml
18 allows Release Please bot PR title
manifest matches current config.yaml versions
```
