# Hardening Notes

## Implemented in this build

- Removed `chmod 777`, `chmod 666` and `chmod a+x` from the Dockerfile.
- Hardened root hints download in the Dockerfile.
- Tightened AppArmor by replacing broad `/bin/**`, `/usr/bin/**` and `/config/** rw` rules.
- Added read-only AppArmor access for the known expert config files.
- Added `unbound-checkconf` validation before web-triggered reloads.
- Centralized reload handling through one API pipeline.
- Hardened blocklist URL validation and curl download options.
- Added support for local `A`, `AAAA`, `CNAME` and `PTR` records while keeping legacy `hostname` + `ip` records compatible.
- Added visible reload/validation status feedback in the web UI.
- Added Python tests and a GitHub Actions validation workflow.

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
