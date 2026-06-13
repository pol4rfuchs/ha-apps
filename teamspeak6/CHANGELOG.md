## [1.1.12] - 2026-06-13
### Fixed
- Channel changes (creates, renames, deletions, icons) were lost on restart
- Root cause: WAL checkpoint ran after tsserver exited; when SQLite closes a
  WAL-mode DB it invalidates the WAL header, so external sqlite3 returned
  0|0|0 (nothing checkpointed) and the main DB stayed at its old state
- Fix: PRAGMA wal_checkpoint(PASSIVE) now runs BEFORE sending SIGTERM, while
  tsserver is alive and the WAL header is valid; verified: sqlite3 connects
  cleanly to the live DB and flushes all frames (0|88|88 — 88 frames moved,
  0 blocked); main DB is current before tsserver is stopped and copied to /data
- Reverted skip-restore-if-DB-exists logic from 1.1.11: HA Supervisor removes
  the container on every stop and recreates it on start, so /var/tsserver is
  always a fresh empty volume and /data must always be restored on startup

## [1.1.11] - 2026-06-13
### Fixed
- All channel changes (creates, renames, deletions) were lost on every
  stop/start restart
- Root cause: /var/tsserver is a persistent Docker volume that survives
  normal stop/start cycles and holds the live server state; sync_to_runtime
  was unconditionally copying /data (a backup from a previous stop) into
  the volume on every start, overwriting current data with a stale snapshot
- Fix: sync_to_runtime now checks for tsserver.sqlitedb in the volume;
  if found the volume is live and no restore is performed; if absent the
  volume is fresh (first install or add-on update) and /data is restored

## [1.1.10] - 2026-06-13
### Fixed
- Channel renames, deletions and creations were silently lost on restart
- Root cause: tsserver accumulates changes in a 4 MB WAL file and does not
  checkpoint it on SIGTERM — the main DB stays at an older state; on next
  start SQLite replays only fully committed WAL frames and ignores the rest,
  so recent changes vanish (renamed channel reverted, new channel gone,
  deleted channel reappeared)
- Fix: PRAGMA wal_checkpoint(TRUNCATE) is now run via sqlite3 immediately
  after tsserver stops and before syncing to /data; this flushes all
  committed transactions from the WAL into the main DB and truncates the
  WAL to zero, making the DB the single source of truth before the sync

## [1.1.9] - 2026-06-13
### Fixed
- Newly created channels disappeared after every stop/restart (definitive fix)
- Root cause: tsserver does not checkpoint the SQLite WAL on SIGTERM — channel
  data accumulates in tsserver.sqlitedb-wal (observed: 4 MB) rather than being
  flushed to the main DB file
- The .sqlitedb-shm file is a process-local WAL index that becomes invalid when
  the container is destroyed; carrying a stale .shm into the next container run
  caused SQLite to misinterpret or skip WAL replay → channels gone
- Fix: delete *.sqlitedb-shm in both sync_from_runtime (after saving to
  persistent store) and sync_to_runtime (after restoring to runtime dir);
  SQLite rebuilds the WAL index cleanly from the WAL file on next open
- Reverts the sync_to_runtime skip-if-has-data logic from 1.1.8: /var/tsserver
  is ephemeral and pre-populated by the base image on every container start, so
  the has_dir_contents check always returned true and /data was never restored

## [1.1.8] - 2026-06-13
### Fixed
- Newly created channels disappeared after a normal stop/start restart
- Root cause: sync_to_runtime blindly overwrote /var/tsserver with data
  from /data on every start; if sync_from_runtime had failed silently on
  the previous stop, this restored stale data on top of the current runtime,
  erasing any channels created in that session
- Fix: sync_to_runtime now skips the restore when /var/tsserver already
  has data (normal restart where Docker volume persists); restore only
  runs when the volume is empty (after an update or reinstall)
- sync_from_runtime no longer silently swallows errors — failures are now
  visible as [ERROR] in the add-on log
- EXISTING_SERVER_STATE now checks /var/tsserver (runtime) instead of
  /data/teamspeak6/server to reflect what tsserver actually sees on startup

## [1.1.7] - 2026-06-13
### Fixed
- Add-on showed "Fehler" (error) status in HA after being stopped normally
- tsserver exits with code 143 (SIGTERM) on shutdown; wait propagated this
  non-zero code to the shell, which HA interpreted as a crash
- Added `|| true` to wait so a signal-induced exit is treated as clean shutdown

## [1.1.6] - 2026-06-13

### Fixed
- sync_from_runtime was called twice on shutdown: TERM trap fired cleanup(),
  then EXIT trap fired it again — causing the sync log message to appear twice
- Added _CLEANUP_DONE guard to ensure cleanup() runs exactly once

## [1.1.5] - 2026-06-13

### Changes up to [1.1.3.-1.1.5]
### Fixed
- Channel icons, banners and uploaded assets were lost on every restart
- Root cause: `exec tsserver` replaced the shell process, causing the EXIT trap
  (`sync_from_runtime`) to never fire — runtime data in `/var/tsserver/files/`
  was never synced back to persistent storage at `/data/teamspeak6/server/`
- Fix: tsserver now runs as a background process with `wait`; a unified
  `cleanup()` trap (EXIT TERM INT) forwards SIGTERM, waits for clean shutdown,
  then syncs all data back
- First-start (token detection) path migrated from pipe to FIFO so tsserver
  PID is known and signal handling is consistent across both code paths

## [1.1.1] - 2026-04-23

### Changes up to [1.1.1.-1.1.2]
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

## [1.0.3.2] - 2026-03-08

### Changes up to [1.0.3.0-1.0.3.2]  
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