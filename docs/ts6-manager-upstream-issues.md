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

## 6. Channel message fails with "already member of channel" (error 770)

`action_message` with `targetMode: channel` (`packages/backend/src/bot-engine/flow-runner.ts`, `executeMessage`) always
sends `clientmove` for the query session into the target channel before `sendtextmessage`. When the session already
is in that channel (for example the default channel) TeamSpeak answers error 770 `already member of channel`, the
execution ends with that error and no message is sent. Suggested: skip the `clientmove` when `whoami` reports the
target channel already, and move back in a `finally` block. The fork `pol4rfuchs/ts6-manager` contains this fix with a
test (branch `fix/channel-message-already-member`).

## 7. Server message (`targetMode: server`) is invisible in the TeamSpeak 6 client

The server accepts `sendtextmessage targetmode=3` (confirmed with a ServerQuery listener), but the TeamSpeak 6 client
has no server chat, so nobody sees it. Suggested: warn in the flow editor when `server` is chosen, or hide it.

## 8. Native Opus encoder is not used in the Alpine arm64 image (analysis)

On a Raspberry Pi 4 the log says `@discordjs/opus unavailable, using opusscript (WASM)`. The build installs the
prebuilt `opus.node` for `linux-arm64-musl` successfully, but that binary lists `libc.so` (not `libc.musl-aarch64.so.1`)
as a needed library (`readelf -d`); the x64 musl build lists `libc.musl-x86_64.so.1`. `libc.so` exists on Alpine only with
`musl-dev`, which the build stage has and the runtime stage does not, so loading fails at runtime only. Not verified in an
Alpine arm64 container (the analysis is from the downloaded release file and the CI build log). Possible fixes: build
`@discordjs/opus` from source in the build stage (`npm_config_build_from_source`), or provide a `libc.so` in the runtime image.
