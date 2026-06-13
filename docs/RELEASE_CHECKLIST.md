# Release Checklist

## Security

- [ ] No `chmod 777`
- [ ] No `chmod 666`
- [ ] No `chmod a+x`

## AppArmor

- [ ] No `/bin/**`
- [ ] No `/usr/bin/**`
- [ ] No `/config/** rw`

## CI

- [ ] Workflow green
- [ ] Docker build green
- [ ] Tests green

## Runtime

- [ ] Add-on starts
- [ ] DNS resolves on 5053
- [ ] DNSSEC behavior is verified
- [ ] Blocklists work

## GUI

- [ ] Local A records work
- [ ] Local AAAA records work
- [ ] Local CNAME records work
- [ ] Local PTR records work
- [ ] Reload errors are visible
