# Home Assistant Add-on: Navidrome

![Version](https://img.shields.io/badge/dynamic/yaml?label=Version&query=%24.version&url=https%3A%2F%2Fcodeberg.org%2Fwuest3nfuchs%2Fha-addons%2Fraw%2Fbranch%2Fmain%2Fnavidrome%2Fconfig.yaml)
[![Upstream](https://img.shields.io/github/v/release/navidrome/navidrome?label=Upstream)](https://github.com/navidrome/navidrome/releases/latest)
![Ingress](https://img.shields.io/badge/Ingress-true-green)

## About

[Navidrome](https://www.navidrome.org/) is a self-hosted music server and streamer.
It is compatible with the **Subsonic / Airsonic API**, so any Subsonic client
(DSub, Symfonium, Ultrasonic, Feishin, …) works out of the box.

This add-on wraps the official [`deluan/navidrome`](https://hub.docker.com/r/deluan/navidrome)
Docker image and adds Home Assistant Supervisor integration (Ingress, bashio, options UI).

> **Fork note:** based on [celynw/ha-addons](https://github.com/celynw/ha-addons/tree/master/navidrome),
> extended with full option coverage and kept up-to-date.

## Installation

1. Add this repository to Home Assistant:
   _Settings → Add-ons → Add-on store → ⋮ → Repositories_
2. Install **Navidrome**
3. Set at minimum `ND_MUSICFOLDER` (path to your music, e.g. `/media/music`)
4. Start the add-on
5. Open the Web UI via the sidebar panel

## Updating Navidrome

Bump the version tag in `build.yaml` and rebuild:

```yaml
# build.yaml
build_from:
  aarch64: "deluan/navidrome:0.55.0"   # ← new version here (all arches)
```

Then update `config.yaml` → `version` and add an entry to `CHANGELOG.md`.

## Configuration

All options map 1:1 to [Navidrome environment variables](https://www.navidrome.org/docs/usage/configuration-options/).

| Option | Default | Notes |
|---|---|---|
| `ND_MUSICFOLDER` | `/media/music` | **Required.** Path to your music library. |
| `ND_DATAFOLDER` | `/config/addons_config/navidrome` | Database & cache location. |
| `ND_SCANSCHEDULE` | `@every 24h` | Cron or duration. `0` = disabled. |
| `ND_LOGLEVEL` | `info` | `error / warn / info / debug / trace` |
| `ND_ENABLEDOWNLOADS` | `true` | Allow downloading from the UI. |
| `ND_JUKEBOX_ENABLED` | `false` | Play audio on server hardware. |
| `ND_LASTFM_ENABLED` | `false` | Last.fm scrobbling & metadata. |
| `ND_LISTENBRAINZ_ENABLED` | `false` | ListenBrainz scrobbling. |
| `ND_SPOTIFY_ID/SECRET` | — | Artist images from Spotify. |
| `ND_REVERSEPROXYUSERHEADER` | — | SSO header (e.g. `Remote-User`). |

Full option reference: <https://www.navidrome.org/docs/usage/configuration-options/>

## Music folder paths

| HA mount | Typical path |
|---|---|
| USB / HDD via HA | `/media/...` |
| SMB share (Samba add-on) | `/share/...` |
| NFS mount | `/mnt/...` or `/share/...` |

## Support

Open an issue on [Codeberg](https://codeberg.org/wuest3nfuchs/ha-addons/issues).
