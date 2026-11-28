# Security Policy

This repository is a collection of Home Assistant apps. Most of them wrap third-party software
(Vaultwarden, Nextcloud, Forgejo, Matrix Synapse and others). What this repository owns is the
**packaging**: Dockerfiles, start scripts, `config.yaml` defaults, AppArmor profiles, and the CI that
builds and publishes the images. Security reports are welcome for exactly that part.

## Reporting a vulnerability

**Please do not open a public issue, pull request or discussion for an undisclosed vulnerability.**

Use GitHub's private vulnerability reporting instead:

1. Open the [Security tab](https://github.com/pol4rfuchs/ha-apps/security) of this repository.
2. Choose **Report a vulnerability**
   (direct link: <https://github.com/pol4rfuchs/ha-apps/security/advisories/new>).

Only the maintainer can see the report. Please include as much of the following as you can:

- the affected app (folder name) and version, plus architecture (`aarch64` / `amd64`) and Home Assistant version
- what is wrong, and what an attacker gains (impact)
- the steps or a minimal proof of concept to reproduce it
- whether you already know a fix or a mitigation
- whether the problem is already public somewhere, and how you want to be credited (or not)

A report without a working proof of concept is still welcome, but it may take longer to assess.

If you cannot use GitHub for the report, open a public issue that says only "I need a private
channel for a security report" and contains **no technical details**. A private channel will be
arranged from there.

## What is in scope

| In scope (report here) | Out of scope (report elsewhere) |
|---|---|
| Insecure defaults in `config.yaml` (exposed ports, `host_network`, `full_access`, privileges, `map:` values) | Bugs in the upstream software itself: report to the upstream project (linked in each app's `README.md`) |
| Secrets generated, stored, logged or exposed insecurely by an app's start scripts | Vulnerabilities in Home Assistant Core, Supervisor or the OS: report to [Home Assistant](https://www.home-assistant.io/security/) |
| Ingress, authentication or proxy configuration added by this repository that weakens upstream's protection | Problems that need prior admin or root access to the Home Assistant host |
| AppArmor profiles that are bypassable or far broader than the app needs | Exposing an app to the internet without TLS or without a reverse proxy, against the app's own documentation |
| Dockerfiles that pull unverified artefacts, run as root without need, or leave build secrets in a layer | Missing hardening that has no demonstrable impact |
| Workflow and supply-chain issues: unpinned actions, excessive `permissions:`, secret exposure, tampering with published images on GHCR | Denial of service that needs local or authenticated access |
| Credentials or tokens committed to this repository | Findings only in versions that are no longer the latest release |

If you are unsure whether something belongs to the packaging or to upstream, report it here
privately. I will tell you, and where needed forward it to upstream in coordination with you.

### Known CVEs in dependencies

A CVE that is already public and sits in an upstream release, a base image or a package is **not**
a private matter. Dependabot alerts, Renovate updates and
`.github/workflows/27-dependabot-alerts-to-issues.yml` handle those in the open. Use the
"Dependency / Security Report" issue form if you want to point one out. Report it privately only if
this repository's packaging makes it exploitable in a way upstream does not describe.

## Supported versions

Only the **latest released version of each app** receives security fixes. Apps are released
independently and updated through the Home Assistant app store, so a fix ships as a new release of
the affected app. There are no backports to older versions.

Apps marked `wip` or `experimental` in the [README](README.md) are supported on the same terms, but
expect rougher edges.

## What to expect

This is a hobby project run by one person, so everything below is best effort and not a service
level agreement.

| Step | Target |
|---|---|
| Acknowledgement of your report | within 7 days |
| First assessment (valid or not, severity) | within 14 days |
| Fix or mitigation, depending on severity | critical and high: as fast as possible; others: next regular release |
| Public disclosure | after the fix is released, or after 90 days at the latest, whichever comes first |

I will keep you updated while the report is open, and I will tell you if I decide a report is out of
scope or not reproducible, with the reason. If a fix needs more than 90 days, I will agree a later
date with you rather than disclose silently.

## Disclosure

- Fixes are developed privately, using the temporary private fork that GitHub offers for security
  advisories where that helps.
- After the fix is released, a GitHub Security Advisory is published for the affected app. If the
  issue qualifies, a CVE ID is requested through GitHub as CNA. CVEs for upstream software are not
  assigned here.
- You are credited in the advisory unless you ask not to be.
- There is no bug bounty.

## Safe harbour

Good-faith research is welcome. I will not take action against anyone who:

- tests only against their own instance of an app
- does not access, change or delete data that belongs to others
- does not run denial-of-service, social-engineering or physical attacks
- does not attack the infrastructure of GitHub, GHCR, Home Assistant or the maintainer
- gives me reasonable time to fix the issue before disclosing it

## Notes for users

- Keep apps updated. Most security fixes arrive as ordinary app updates.
- Put apps that need it behind HTTPS (a reverse proxy) before exposing them beyond your LAN; each
  app's `DOCS.md` describes local and external access.
- These are unofficial community apps and are not endorsed or supported by the upstream authors.
  Do not report problems with these apps to the upstream projects unless you have confirmed that they
  also occur with the upstream image.
