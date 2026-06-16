# Support

## Before opening an issue

- Check the add-on logs in Home Assistant:
  **Settings → System → Logs → select the add-on**
- Check the Supervisor logs:
  **Settings → System → Logs → Supervisor**
- Make sure you are on `aarch64` or `amd64` — no other architectures are supported

## GHCR image pull problems

If Home Assistant cannot pull an add-on image:

1. Check your internet connection on the HA device
2. Verify the image is public:
   `https://ghcr.io/pol4rfuchs/<addon-slug>-ha-app`
3. Check for IPv6 issues — try disabling IPv6 on your router if pulls time out
4. Check Supervisor logs for `failed to pull` or `unauthorized` errors
5. Restart the Supervisor:
   **Settings → System → Restart Supervisor**

## Add-on does not appear in the store

1. Make sure the repository URL is exactly:
   `https://github.com/pol4rfuchs/ha-apps`
2. Remove and re-add the repository
3. Hard-refresh the Add-on Store

## Reporting issues

Open an issue at:
`https://github.com/pol4rfuchs/ha-apps/issues`

Please include:
- Add-on name and version
- Home Assistant version
- Architecture (`aarch64` / `amd64`)
- Relevant log output

## Out of scope

- Feature requests for upstream projects (ntfy, Navidrome, etc.) — report those upstream
- Support for `armhf`, `armv7`, `i386`
