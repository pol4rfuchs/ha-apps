# Maintenance Model: Low-Touch Maintenance

## Term

**Low-Touch Maintenance** (also called *Autopilot Repository* or *Maintenance-as-Code*) describes a repository whose day-to-day operation is carried almost entirely by automation. Manual intervention by the maintainer is rare, targeted, and mostly limited to structural decisions rather than routine work.

## Characteristics

- **Automated share (bulk of activity):**
  - Dependency updates (e.g. Renovate for GitHub Actions SHA pins, npm deps)
  - Upstream version tracking (e.g. Docker image bumps)
  - CI/CD: linting, validation, build & publish (e.g. to GHCR)
  - Recurring checks (meta-validation, Dockerfile linting)

- **Manual share (rare, roughly every 1–3 months):**
  - New features / new add-ons
  - Architecture or workflow migrations (e.g. switching to Release Please)
  - Non-trivial bug fixes (e.g. logic errors, data corruption)
  - Strategic decisions (e.g. which add-ons get added, versioning scheme)

## Example: `ha-apps` Monorepo

| Area | Automated | Manual |
|---|---|---|
| Action/dep updates | ✅ Renovate (Wednesday schedule) | – |
| Docker upstream bumps | ✅ Workflow `06` | – |
| Build & publish (GHCR) | ✅ Workflow `03` | – |
| Lint/meta-validation | ✅ Workflows `00`, `01`, `12` | – |
| Integrating new add-ons | – | ✅ |
| Release workflow migration | – | ✅ (Release Please) |
| Critical bug fixes (e.g. WAL checkpoint) | – | ✅ |

## Why the term fits

Unlike "Maintenance Mode" (which often implies: bug fixes only, no new features), *Low-Touch* doesn't imply stagnation — it implies that the **degree of automation is high enough** that active upkeep is only needed occasionally, for decisions a machine can't make on its own.
