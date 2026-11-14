# Navidrome — Home Assistant App

Self-hosted music server with Subsonic/Airsonic API. Works with DSub, Symfonium, Ultrasonic, Feishin and any other Subsonic-compatible client.

---

## Quick Start

1. **Settings → Apps → App Store → ⋮ → Repositories**
2. Add: `https://github.com/pol4rfuchs/ha-apps`
3. Install **Navidrome** and set at minimum:

```yaml
ND_MUSICFOLDER: "/media/music"
```

4. Click **Start** and open the Web UI on port `4533`
5. On first start, create your admin account in the browser

---

## Music Folder Paths

| Source | Path |
|--------|------|
| USB / HDD via HA | `/media/...` |
| SMB share (Samba app) | `/share/...` |

---

## Configuration

All options map 1:1 to [Navidrome environment variables](https://www.navidrome.org/docs/usage/configuration-options/).

Key options:

| Option | Default | Description |
|--------|---------|-------------|
| `ND_MUSICFOLDER` | `/media/music` | **Required.** Path to your music library. |
| `ND_DATAFOLDER` | `/data` | Database and cache location. **Must stay under `/data`** (always persistent) or under `/config/addons_config/navidrome` *only if* `addon_config` is in the app's `map` config — any other path is wiped on restart. |
| `ND_SCANNER_SCHEDULE` | `@every 24h` | When the library is scanned automatically. Allowed: an interval such as `@every 24h` or `@every 1h30m`, the descriptors `@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`, or a cron expression with 5 or 6 fields (for example `0 3 * * *` = every day at 03:00). `0` switches the automatic scan off (checked with Navidrome 0.64.2: no periodic scan is scheduled). An invalid value would make Navidrome stop at start, so the app replaces it with `@every 24h` and writes a warning to its log; the check is coarse and does not test the value ranges inside a cron field. |
| `log_level` | `info` | `trace / debug / info / warning / error`. Sets Navidrome's `ND_LOGLEVEL` (`warning` → `warn`) and the app's own log output. Replaces the former `ND_LOGLEVEL` option. |
| `ND_EXTRA_MUSIC_FOLDERS` | — | Comma-separated extra music folders (e.g. `/share/music2,/media/usb/music`). Each existing folder is linked into `ND_MUSICFOLDER` at start. |
| `ND_JUKEBOX_ENABLED` | `false` | Play audio on server hardware (requires sound device). |

The app runs Navidrome as **root**; there is no `PUID`/`PGID` option. Last.fm API key/secret, Spotify credentials, external authentication and jukebox devices cannot be configured through the app options.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Web UI not loading | Check port `4533` is mapped in the Network tab |
| Music not showing | Verify `ND_MUSICFOLDER` path is correct and readable |
| Scan not running | Trigger manually: UI → Settings → Scan Library. Also check `ND_SCANNER_SCHEDULE`: `0` means no automatic scan, and an invalid value is replaced by `@every 24h` (see the app log). |
| Track number empty for WAV files | Navidrome reads the track number of a WAV file from the RIFF INFO tag `IPRT`, not from `ITRK` (tested with Navidrome 0.64.2: `IPRT=7` shows track 7, `ITRK=4` shows none). WAV tags are limited in general; for albums prefer FLAC or MP3, where the track number (FLAC `TRACKNUMBER`, ID3 `TRCK`, also `1/3`) arrives normally. |
| Client can't connect | Use Subsonic API URL: `http://[HA-IP]:4533` |
| Admin user / library gone after restart (pre-v2.1.3) | `ND_DATAFOLDER` pointed to a non-persistent path. Update the app, then check the log for an automatic migration message. If your data was already lost, recreate the admin user once. |

## Local and external access

**Local (LAN):** open `http://<ha-host>:4533`; Subsonic clients use the same URL. Access is protected by Navidrome's own login. There is no `ssl` option, so use a reverse proxy if you need HTTPS.

**External (internet):** recommendation **ok, but only through a reverse proxy with TLS.** Never forward port `4533` directly. Public share links stay off (`ND_ENABLESHARING: false` by default), and the outgoing services (Last.fm, ListenBrainz, insights collector, Gravatar) are all off by default; keep them opt-in.
