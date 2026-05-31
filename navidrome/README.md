<div align="center">

<img src="https://raw.githubusercontent.com/pol4rfuchs/ha-apps/main/navidrome/icon.png" alt="Navidrome Icon" width="128">

# 🎵 Navidrome — Home Assistant Add-on

</div>

<div align="center">

[![GitHub Repo](https://img.shields.io/badge/GitHub-ha--apps-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/pol4rfuchs/ha-apps)
[![Upstream](https://img.shields.io/github/v/release/navidrome/navidrome?label=Upstream&style=for-the-badge&logo=github&logoColor=white)](https://github.com/navidrome/navidrome/releases/latest)
[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?style=for-the-badge&logo=homeassistant&logoColor=white)](https://www.home-assistant.io/addons/)

**Self-hosted music server and streamer — Subsonic/Airsonic API compatible, works with any Subsonic client.**

</div>

---

## 🧭 Overview

| Property | Value |
|---|---|
| **Upstream image** | `deluan/navidrome` |
| **Default port** | `4533` |
| **Arch** | `amd64`, `aarch64` |
| **API** | Subsonic / Airsonic compatible |
| **Clients** | DSub, Symfonium, Ultrasonic, Feishin, … |

---

## 🚀 Installation

### Step 1 — Add the repository

```text
Settings → Add-ons → Add-on Store → ⋮ → Repositories
```

Add:

```text
https://github.com/pol4rfuchs/ha-apps
```

### Step 2 — Install & configure

Install **Navidrome** and set at minimum:

```yaml
ND_MUSICFOLDER: "/media/music"
```

### Step 3 — Start

Open the Web UI via the button in the add-on Info tab (port `4533`).  
On first start, create your admin account.

---

## ⚙️ Configuration

All options map 1:1 to [Navidrome environment variables](https://www.navidrome.org/docs/usage/configuration-options/).

| Option | Default | Description |
|---|---|---|
| `ND_MUSICFOLDER` | `/media/music` | **Required.** Path to your music library. |
| `ND_DATAFOLDER` | `/data` | Database and cache location. |
| `ND_SCANSCHEDULE` | `@every 24h` | Cron or duration. `0` = disabled. |
| `ND_LOGLEVEL` | `info` | `error / warn / info / debug / trace` |
| `ND_ENABLEDOWNLOADS` | `true` | Allow downloading tracks from the UI. |
| `ND_JUKEBOX_ENABLED` | `false` | Play audio on server hardware. |
| `ND_LASTFM_ENABLED` | `false` | Last.fm scrobbling and metadata. |
| `ND_LISTENBRAINZ_ENABLED` | `false` | ListenBrainz scrobbling. |
| `ND_SPOTIFY_ID` | — | Spotify Client ID for artist images. |
| `ND_SPOTIFY_SECRET` | — | Spotify Client Secret. |
| `ND_REVERSEPROXYUSERHEADER` | — | SSO header (e.g. `Remote-User`). |

Full option reference: <https://www.navidrome.org/docs/usage/configuration-options/>

---

## 🌐 Ports

| Port | Protocol | Purpose |
|---|---|---|
| `4533` | TCP | Navidrome Web UI + Subsonic API |

---

## 📂 Music folder paths

| Source | Typical path |
|---|---|
| USB / HDD via HA | `/media/...` |
| SMB share (Samba add-on) | `/share/...` |
| NFS mount | `/share/...` |

---

## 💾 Data persistence

```text
/data/
├── navidrome.db      ← Library database
└── cache/            ← Transcoding cache, artwork
```

HA backups include the add-on `/data` directory automatically.

---

## 🔧 Troubleshooting

| Problem | Fix |
|---|---|
| Web UI not loading | Check that port `4533` is mapped in the Network tab |
| Music not showing | Verify `ND_MUSICFOLDER` path is correct and readable |
| Scan not running | Trigger manually: UI → Settings → Scan Library |
| Client can't connect | Use the Subsonic API URL: `http://[HA-IP]:4533` |

---

## 📜 License

MIT — this add-on wrapper.  
Navidrome is licensed under [GPL-3.0](https://github.com/navidrome/navidrome/blob/master/LICENSE).
