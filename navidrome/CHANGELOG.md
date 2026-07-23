# Changelog

## [2.1.5](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.4...navidrome-v2.1.5) (2026-07-23)


### Bug Fixes

* **navidrome:** correct swapped en/de translations, add apparmor profile (disabled pending manual test), --- header, drop -ha-app suffix and deprecated hassio_api, remove insecure curl TLS bypass ([6bd16bc](https://github.com/pol4rfuchs/ha-apps/commit/6bd16bcaee76f930f9869a5afd1994e2cb239c91))

## [2.1.4](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.3...navidrome-v2.1.4) (2026-07-13)


### Bug Fixes

* **navidrome:** update upstream to 0.63.2 ([#168](https://github.com/pol4rfuchs/ha-apps/issues/168)) ([cfe7905](https://github.com/pol4rfuchs/ha-apps/commit/cfe79050bf5a49d0ae23377fc1fe8f4cb2a269d3))

## [2.1.3](https://github.com/pol4rfuchs/ha-apps/compare/navidrome-v2.1.2...navidrome-v2.1.3) (2026-06-26)


### Bug Fixes

* **navidrome:** ND_DATAFOLDER auf persistenten /data-Pfad korrigiert ([b777d13](https://github.com/pol4rfuchs/ha-apps/commit/b777d1393d45f88d22e261e989634282362a8273))

## v2.1.0

### Bugfixes
- **ENV-Persistenz**: `ha_entrypoint.sh` sourct Init-Scripts mit `.` statt `bash`-Subshell — alle `ND_*` Variablen kommen jetzt wirklich bei Navidrome an
- **Belt+Suspenders**: Zusätzlich wird `/run/navidrome.env` geschrieben und in `navidrome-run.sh` gesourct (doppelte Absicherung)
- **Ingress SPA-Fix**: `ND_BASEURL` wird dynamisch aus `bashio::addon.ingress_entry` gesetzt — Navidrome-SPA funktioniert jetzt korrekt hinter dem HA Ingress-Pfad
- `sub_filter`-Hack aus nginx entfernt (war kaputt und unnötig mit `ND_BASEURL`)
- nginx `ingress.conf`: `proxy_buffering off` für Streaming, `/healthz` Endpunkt statt `/ping`

### Neue Features
- **Multiple music folders**: `ND_EXTRA_MUSIC_FOLDERS` (kommagetrennt) — werden als Symlinks unter `ND_MUSICFOLDER` eingehängt
- **Jukebox**: `privileged: true` + ALSA-Devices (`/dev/snd`) in `config.yaml` — Jukebox funktioniert jetzt
- **Podcasts**: `ND_PODCAST_EPSIODEKEEPCOUNT`, `ND_PODCAST_EPSIODEDOWLOADCOUNT`
- **Scanner/Extractor**: `ND_SCANNER_EXTRACTOR` (taglib/ffmpeg), `ND_FFMPEGPATH`
- Alle Optionen jetzt auf Deutsch beschrieben in `translations/en.yaml`

## v2.0.0

- Initiale Neuentwicklung basierend auf celynw/ha-addons Baseline
- Vollständige Option-Coverage

## v1.0_0.54.5 (upstream celynw baseline)

- Letzte upstream Version: [v0.54.5](https://github.com/navidrome/navidrome/releases/tag/v0.54.5)
