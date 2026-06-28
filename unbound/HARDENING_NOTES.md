# Hardening Notes

## Implemented (2026-06-27/28 session)

- Dropped privileges for the Unbound daemon itself: `username: "unbound"`
  is now actually honored at runtime (the Dockerfile already chowned
  `/var/lib/unbound` to the `unbound` user, but the daemon never dropped
  out of root to match it — fixed).
- Built Unbound from source (1.25.1) instead of using the Alpine 3.24
  apk package, which still ships 1.24.2. The source build fixes 11
  upstream CVEs, including a remote-code-execution risk during DNSSEC
  validation (CVE-2026-33278). Build-args/configure flags
  (`--enable-subnet`, `--with-username=unbound`) preserve existing
  add-on features (EDNS Client Subnet); verified working post-build.
- Added SHA256 checksum verification of the downloaded Unbound source
  tarball against NLnet Labs' official `.sha256` sidecar file before
  extracting/compiling it. Build fails on mismatch.
- Bumped the base image (`hassio-addons/base`) from `20.2.0` to
  `21.0.0` and replaced deprecated `bashio::addon.*` calls in `run.sh`
  with `bashio::app.*`. The deprecated calls were silently hitting a
  403'd Supervisor API endpoint on every container start.
- Resolved a pidfile/run-dir permission failure introduced by the
  source build: Unbound's pidfile is now disabled entirely
  (`--with-pidfile=""`) instead of trying to write into a freshly
  s6-reset `/var/run`. Avoids granting `CAP_CHOWN`/`CAP_DAC_OVERRIDE`
  at runtime, which the AppArmor profile deliberately omits.
- Removed `chmod 777`, `chmod 666` and `chmod a+x` from the Dockerfile.
- Hardened root hints download in the Dockerfile.
- Tightened AppArmor by replacing broad `/bin/**`, `/usr/bin/**` and
  `/config/** rw` rules.
- Added read-only AppArmor access for the known expert config files.
- Added `unbound-checkconf` validation before web-triggered reloads.
- Centralized reload handling through one API pipeline.
- Hardened blocklist URL validation and curl download options.
- Added support for local `A`, `AAAA`, `CNAME` and `PTR` records while
  keeping legacy `hostname` + `ip` records compatible.
- Added visible reload/validation status feedback in the web UI.
- Added Python tests and a GitHub Actions validation workflow.

## Verified working (2026-06-28)

- Unbound 1.25.1 starts cleanly, no crash loop, no permission errors.
- DNS resolution confirmed end to end (`nslookup`/`drill` against the
  add-on from a client on the network, both A and AAAA records).
- EDNS Client Subnet (`subnetcache` module) loads correctly under the
  source-built binary — `--enable-subnet` was carried over correctly.
- No more `403`/`deprecated bashio::addon.*` noise in the logs.

## Still open / not yet done

- **AppArmor profile has not had a full systematic review.** Everything
  changed so far was reactive (fixing whatever broke), not a
  deliberate top-to-bottom pass over the profile.
- **`unbound.conf` hardening directives are unreviewed.** Worth
  checking: `hide-identity`, `hide-version`, tightening
  `access-control` beyond the default, rate-limiting settings against
  amplification abuse (`ratelimit`, `ip-ratelimit`), and whether
  `harden-*` options (e.g. `harden-glue`, `harden-dnssec-stripped`)
  are set to their recommended values in `config_gen.py`.
- **Web UI authentication/session handling is unreviewed.** Unclear
  whether there's any auth beyond Ingress, and whether that's
  considered sufficient.
- **Only SHA256 checksum verification, no GPG signature check.** NLnet
  Labs signs releases with an OpenPGP key; checksum verification
  protects against corruption/simple tampering but not against a
  compromise of nlnetlabs.nl itself serving both a tampered tarball
  and a matching tampered checksum. Full GPG verification would close
  that gap but needs a pinned public key and `gnupg`/`sqv` in the
  build stage.
- **No automated check that the next Unbound CVE/version bump won't
  silently fall back to whatever Alpine's apk repo has.** Since
  Unbound is now built from source and version-pinned manually, a
  future "just bump the version" change needs to remember this is a
  source build, not an apk package swap.

## Safe rollout

Start with DNS mapped to port `5053` and test through AdGuard Home before considering port `53`.

```bash
dig @<HA-IP> -p 5053 google.com
dig @<HA-IP> -p 5053 cloudflare.com AAAA
dig @<HA-IP> -p 5053 dnssec-failed.org
```

## Rollback

1. Disable this add-on.
2. Remove it from AdGuard upstreams.
3. Restore the previous upstream resolver.
4. Restart AdGuard Home.
5. Verify DNS resolution.
