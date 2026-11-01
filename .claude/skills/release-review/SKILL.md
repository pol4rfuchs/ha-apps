---
name: release-review
description: Reviews an open Release Please PR of an add-on before it is merged (tag of the previous version, changelog with new commits only, checks, title, scope). Only reads, never merges or pushes. Call it with the add-on slug or the PR number, e.g. /release-review ntfy.
disable-model-invocation: true
allowed-tools: Read, Bash(gh pr list *), Bash(gh pr view *), Bash(gh release list *), Bash(git tag *), Bash(git log *), Bash(git show *), Bash(git status *)
argument-hint: <slug or PR number>
---

# Review a release PR: $ARGUMENTS

The basis is catalog §7 (skill `ha-apps-buildrules`, section "Versioning / Release Please"). This skill only reads: merge nothing, push nothing, create no tags or releases, no `gh api`.

## Procedure

1. **Find the PR.** If `$ARGUMENTS` is a number, open the PR directly (`gh pr view <n> --json number,title,body,files,statusCheckRollup,mergeable,labels`). Otherwise `gh pr list --state open --search "release $ARGUMENTS in:title"`. If there are several or none, stop and ask.
2. **Check the previous tag.** Read the add-on's version from `.release-please-manifest.json` on `origin/main` (`git show origin/main:.release-please-manifest.json`). Does the tag `<slug>-v<version>` exist (`git tag -l "<slug>-v*"`, additionally `gh release list`)? If it is missing, this is the known "missing anchor" error: do **not** merge the PR and report it as such.
3. **Changelog with new commits only.** Count the commits since the previous tag (`git log <slug>-v<old>..origin/main --oneline -- <slug>/`) and compare them with the entries in the PR text. Repeated old entries or a bloated changelog: do not merge, clarify the cause in the log of "05 Release Please" (§7).
4. **Checks.** Look at every entry of `statusCheckRollup`, not only the overall status. Name open, red or skipped checks individually. Renovate notes about `minimumReleaseAge` or lock files are informational and do not block.
5. **Scope and title.** The title follows `chore(main): release <slug> x.y.z`. Changed files may only be under `<slug>/` and in the manifest. A PR with several add-ons is an error.
6. **Order.** According to §7 first your own fix PRs, then Renovate, release PRs last, and release PRs one after the other, never at the same time (otherwise manifest conflicts). Report whether release PRs for other add-ons are still open.

## Output

A list, no git command. For each point 1 to 6: **OK**, **not OK** or **not checked** (with the reason). At the end exactly one recommendation: "merge" or "do not merge, because …". The decision and the merging stay with the user. Write the answer in German (it is a chat reply to the maintainer).
