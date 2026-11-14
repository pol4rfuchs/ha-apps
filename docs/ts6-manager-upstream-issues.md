# Upstream issue drafts for clusterzx/ts6-manager

Drafts only. They are not filed anywhere; copy them into the upstream issue tracker if wanted.
Findings were made with the manager at the commit pinned in `ts6_manager/Dockerfile` (`TS6_MANAGER_REF`)
against TeamSpeak 6 6.0.0-beta13.1.

## 1. Footer shows a hard-coded "TS6 WEBUI v1.0.0"

The login page (`packages/frontend/src/pages/Login.tsx`) and the setup page (`SetupPage.tsx`) print the literal
text `TS6 WEBUI v1.0.0`. It does not follow the real release, so it is wrong after every release.
Suggested: read the version from `package.json` at build time (for example a Vite `define`) or drop the number.

## 2. Wrong ids in request bodies answered with HTTP 500 instead of 400

A missing or non-numeric `songId` (queue and play) or `stationId` (play-radio) in the music bot routes ended in an
unhandled error and HTTP 500. These are client errors and should answer 400 with a message such as
`songId must be an integer`. The fork `pol4rfuchs/ts6-manager` already contains this change (its pull request 6);
it can be taken over as is.

## 3. The `viewer` role cannot read anything

`requireServerAccess` only lets a `viewer` onto a server that has a row in `UserServerAccess`, but no API route and
no page creates such a row. Observed: a new `viewer` gets 403 on `/api/servers/1`, its channel list and its bans.
After inserting a row by hand it gets 200 on channels and clients and 403 on bans, logs, bots and all writes.
Suggested: a route and a UI control (for admins) to grant and revoke server access per user, and a short list of what
a `viewer` may read in the documentation. Until then the role is effectively unusable.

## 4. Bot flow with the wrong node shape is reported as enabled but never fires

A flow whose nodes carry their settings under `data` instead of `config` (for example
`{"type":"trigger_cron","data":{"cron":"* * * * *"}}`) is enabled successfully, while the log says
`Invalid cron expression '' in flow N` and the flow never runs. The same flow with `config` runs (`status: completed`
every minute). Suggested: reject the flow when it is saved or enabled with a clear error, or accept both shapes, and
document the node format (`trigger_cron: { cron }`, `action_message: { targetMode, message }`).

## 5. Music bot creation blocks for minutes without feedback

Creating a music bot computes a TeamSpeak identity with `generateIdentityAsync(23)` (`voice-bot-manager.ts`).
On a Raspberry Pi 4 this took 138 seconds, one CPU core was busy, and the interface showed nothing. Suggested: show a
progress or "working" state, and make the security level configurable (for example an environment variable).
