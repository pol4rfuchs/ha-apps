# Security Policy

## Scope

This fork focuses on hardening the Unbound Home Assistant OS add-on.

Primary goals:

- reduce filesystem write permissions
- avoid world-writable resolver state
- reduce AppArmor scope
- validate Unbound configuration before reload
- harden blocklist downloads
- expose useful reload/config errors in the web UI
- run the Unbound daemon itself as a non-root user, not just root with
  tightened file permissions
- build Unbound from verified upstream source when the distro package
  lags behind on security fixes

## Security Baseline

The following patterns are not allowed:

```text
chmod 777
chmod 666
chmod a+x
/bin/**
/usr/bin/**
/config/** rw
```

Exceptions must be documented and justified.

## Privilege Drop Rule

The Unbound daemon must run as the `unbound` user at runtime
(`username: "unbound"` in the generated config), not as root. Any
directory or file Unbound needs to read or write after startup must be
owned by `unbound:unbound` ahead of time — chowning it from inside
Unbound itself after the privilege drop is not possible.

## Capability Rule

The AppArmor profile intentionally does **not** grant `CAP_CHOWN` or
`CAP_DAC_OVERRIDE` to the container at runtime. This means:

- `chown`/`chmod` calls in the Dockerfile work fine (build time is not
  subject to the runtime capability set), but the same calls **will
  fail** if attempted at container runtime (e.g. in `run.sh`), even as
  root.
- Any path that needs correct ownership at runtime (pidfiles, sockets,
  state directories) must either already be correctly owned from build
  time and live outside `/run` (which s6-overlay resets fresh on every
  container start), or be avoided entirely (e.g. disabling Unbound's
  pidfile rather than working around the permission gap).
- Do not add `capability chown` or `capability dac_override` to work
  around a permissions issue without a documented reason — it
  re-opens exactly the privilege-escalation surface this add-on is
  trying to close.

## Source Build Rule

When Unbound is built from source instead of the Alpine apk package
(currently the case for 1.25.1, since Alpine 3.24 stable still ships
1.24.2), the downloaded tarball must be verified against NLnet Labs'
official SHA256 checksum before extraction. The build fails closed on
a mismatch.

## Reload Rule

No mutating web UI/API path may call:

```text
unbound-control reload
```

without first running:

```text
unbound-checkconf /etc/unbound/unbound.conf
```

## Blocklist Rule

External blocklist downloads must enforce:

- HTTP failure detection
- connection timeout
- total timeout
- maximum file size
- redirect limit
- URL scheme validation
- no credentials in URLs

## Open Items

- AppArmor profile: reactive fixes only so far, no full systematic
  audit yet.
- `unbound.conf` hardening directives (`hide-identity`, `hide-version`,
  `access-control` scope, rate-limiting, `harden-*` options) not yet
  reviewed against current best practice.
- Web UI authentication/session handling not yet reviewed.
- Source tarball verification is checksum-only; no GPG signature
  verification against NLnet Labs' release signing key yet.
