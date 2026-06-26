# Navidrome — Home Assistant Add-on

Self-hosted music server with Subsonic/Airsonic API. Works with DSub, Symfonium, Ultrasonic, Feishin and any other Subsonic-compatible client.

---

## Quick Start

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
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
| SMB share (Samba add-on) | `/share/...` |

---

## Configuration

All options map 1:1 to [Navidrome environment variables](https://www.navidrome.org/docs/usage/configuration-options/).

Key options:

| Option | Default | Description |
|--------|---------|-------------|
| `ND_MUSICFOLDER` | `/media/music` | **Required.** Path to your music library. |
| `ND_DATAFOLDER` | `/data` | Database and cache location. **Must stay under `/data`** (always persistent) or under `/config/addons_config/navidrome` *only if* `addon_config` is in the add-on's `map` config — any other path is wiped on restart. |
| `ND_SCANNER_SCHEDULE` | `@every 24h` | Auto-scan interval. `0` disables. |
| `ND_LOGLEVEL` | `info` | `error / warn / info / debug / trace` |
| `ND_JUKEBOX_ENABLED` | `false` | Play audio on server hardware (requires sound device). |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Web UI not loading | Check port `4533` is mapped in the Network tab |
| Music not showing | Verify `ND_MUSICFOLDER` path is correct and readable |
| Scan not running | Trigger manually: UI → Settings → Scan Library |
| Client can't connect | Use Subsonic API URL: `http://[HA-IP]:4533` |
| Admin user / library gone after restart (pre-v2.1.3) | `ND_DATAFOLDER` pointed to a non-persistent path. Update the add-on, then check the log for an automatic migration message. If your data was already lost, recreate the admin user once. |
