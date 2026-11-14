# Changelog

## [0.2610.0-ha3-pol4r1] - Clear error message when copying registration.yaml

- If copying registration.yaml to `/share` fails, an error is now written to the log.
  Before, the add-on reported "copied!" anyway, and Synapse did not find the bridge.

## [0.2610.0-ha2-pol4r1] - Postgres password and config errors

- Postgres: user, password and DB name are now URL-encoded in the DB URI.
  Passwords containing `@ : / ? # %` broke the URI (wrong host, truncated password).
- Option values are passed to yq through the environment (`strenv()`) instead of being put into the
  expression. A `"` in the password made the expression invalid, and the bridge silently kept running
  with the old config.
- If writing config.yaml fails, startup now aborts with an error message.

## [26.7.0-ha1-pol4r1] - Initial Release

- Initial release: mautrix-signal v0.2607.0 as a standalone HA add-on
- 3-stage source build (Rust libsignal_ffi.a + Go, Alpine), aarch64 + amd64
- SQLite/Postgres selectable, encryption toggle, appservice registration via `/share`
