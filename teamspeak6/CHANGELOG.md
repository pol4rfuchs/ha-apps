
## [1.1.1-1.1.2] - 2026-04-23
### Fixed
- Persist TeamSpeak server state explicitly under `/data/teamspeak6/server`
- Re-link `/var/tsserver` to the Home Assistant persistent storage on every start
- Migrate pre-existing runtime data from `/var/tsserver` into persistent storage before launch
- Remove stale token marker automatically if no persisted server state is present
- Fixed run.sh

## [1.1.0] - 2026-04-22
### Changed
- Switched base image to official teamspeaksystems/teamspeak6-server:latest
- Native ARM64 support via beta9 — Box64 and QEMU emulation no longer needed
- Removed box64-rpi4arm64, qemu-user-static, libc6:amd64 from Dockerfile
- Dockerfile significantly simplified
- Server starts faster and runs more efficiently on Raspberry Pi 4

### Added
- ca-certificates for proper HTTPS support

## [1.0.3.0-2] - 2026-03-04
### Changed
- UI simplified: only license, query admin password, log level
- Ports removed from Options tab (use Network tab)
- All UI text switched to English
- License auto-accepted via TSSERVER_LICENSE_ACCEPTED env var
- TS6 logs cleared on every restart

### Added
- Admin token prominently displayed on first start (once only)
- Warning on subsequent starts with ServerQuery token recovery instructions

### Fixed
- Admin token shown twice — now shows only once via TOKEN_FOUND flag
- Removed dns: override from config.yaml
- Removed resolv.conf override from run.sh
  
## [1.0.2] - 2026-02-22
### Added
- Admin token prominently displayed on first start
- Warning on subsequent starts that token is no longer visible
- TS icon in Add-on Store

### Fixed
- Box64 emulator instead of QEMU — puzzle computed in seconds instead of 45 minutes
- Persistent data storage — server no longer recreated on every restart

## [1.0.1] - 2026-02-21
### Fixed
- Correct TS6 flags (--accept-license, --log-path, --query-ip-allow-list etc.)
- ENTRYPOINT reset in Dockerfile to avoid conflicts with base image
- QEMU x86-64 emulation for ARM64

## [1.0.0] - 2026-02-20
### Added
- Initial release
- ARM64 (aarch64) and amd64 support
- Full UI configuration for ports, server name, password, max clients
- Based on indogermane/teamspeak6-server-arm
- SSH Query, HTTP Query, File Transfer ports configurable
