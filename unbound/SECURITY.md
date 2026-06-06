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
