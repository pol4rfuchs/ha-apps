---
paths:
  - ".github/workflows/**"
---

# GitHub workflows

- Runner `ubuntu-24.04`, never `ubuntu-latest` (also in the matrix of `build-app.yaml`).
- Pin actions by commit SHA, with the version in a comment behind it (`# v7.0.1`).
- Numbered file name (`NN-name.yml`); workflows 12 (hadolint), 13 (yamllint), 14 (actionlint) must be green.
- YAML without double spaces and without trailing spaces (yamllint).
- Jobs meant as required checks get no path filter (as workflow 29 explains: otherwise the check stays "pending").
- The label sync (`15-labels.yml`) stays at `prune: false`; otherwise `autorelease: pending`/`tagged` disappear from the release PRs and
  Release Please creates no tag and no release (catalog §7).
- Never create tags retroactively for old, superseded versions: that triggers builds for those versions (catalog §7).
- If a workflow sets a label that is not in `.github/labels.yml`, add it there.
- `actionlint` only runs locally through the stop hook in Docker (if Docker Desktop is running and the image is present locally).
  If the hook reports "skipped", proofread the changes carefully and say in the PR that only the CI checked them.
