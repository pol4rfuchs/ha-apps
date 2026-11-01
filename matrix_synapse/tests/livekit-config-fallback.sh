#!/usr/bin/env bash
# Test for livekit_config_fallback in s6-rc.d/livekit/run.
#
# LiveKit aborts with exit 1 right away on an unknown config field. If a
# (future) LiveKit does not know skip_external_ip_validation, the line must be
# removed; other errors must not touch the config.
# The function is loaded from the real script; livekit-server is a stub and
# bashio::log.warning is stubbed. Needs bash and timeout.
set -euo pipefail
S="$(dirname "$0")/../rootfs/etc/s6-overlay/s6-rc.d/livekit/run"

WARN_LOG=""
bashio::log.warning() { WARN_LOG="${WARN_LOG}$*"$'\n'; }

eval "$(sed -n '/^livekit_config_fallback() {/,/^}/p' "${S}")"
[ "$(type -t livekit_config_fallback)" = "function" ] || { echo "livekit_config_fallback not found in ${S}"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/bin"

# livekit-server stub. FAKE_LK_MODE: accept | reject-skip | other-error
cat > "${WORK}/bin/livekit-server" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "${FAKE_LK_CALLS}"
cfg=""
while [ $# -gt 0 ]; do
    if [ "$1" = "--config" ]; then cfg="$2"; fi
    shift
done
if [ "${FAKE_LK_MODE}" = "reject-skip" ] && grep -q '^  skip_external_ip_validation:' "${cfg}"; then
    echo "could not parse config: yaml: unmarshal errors:"
    echo "  line 9: field skip_external_ip_validation not found in type config.RTCConfig"
    exit 1
fi
if [ "${FAKE_LK_MODE}" = "other-error" ]; then
    echo "failed to listen on :7880: address already in use"
    exit 1
fi
exec sleep 30
EOF
chmod +x "${WORK}/bin/livekit-server"
export PATH="${WORK}/bin:${PATH}"
export FAKE_LK_CALLS="${WORK}/calls"

write_cfg() {
    cat > "${WORK}/livekit.yaml" <<'EOF'
rtc:
  tcp_port: 7881
  use_external_ip: true
  # comment
  skip_external_ip_validation: true

keys:
  devkey: "x"
EOF
}
reset() { : > "${FAKE_LK_CALLS}"; WARN_LOG=""; write_cfg; }

# 1. LiveKit accepts the option: config stays, no warning
reset
FAKE_LK_MODE=accept livekit_config_fallback "${WORK}/livekit.yaml"
grep -q '^  skip_external_ip_validation: true' "${WORK}/livekit.yaml" || { echo "accept: option removed"; exit 1; }
[ -z "${WARN_LOG}" ] || { echo "accept: unexpected warning"; exit 1; }

# 2. LiveKit rejects the option: line removed, rest of the config unchanged, exactly one warning
reset
FAKE_LK_MODE=reject-skip livekit_config_fallback "${WORK}/livekit.yaml"
! grep -q 'skip_external_ip_validation' "${WORK}/livekit.yaml" || { echo "reject: option still present"; exit 1; }
grep -q '^  use_external_ip: true' "${WORK}/livekit.yaml" || { echo "reject: use_external_ip lost"; exit 1; }
grep -q '^  devkey: "x"' "${WORK}/livekit.yaml" || { echo "reject: keys lost"; exit 1; }
[ "$(printf '%s' "${WARN_LOG}" | grep -c .)" = "1" ] || { echo "reject: expected exactly one warning"; exit 1; }

# 3. Other error (e.g. port in use): config unchanged, no warning
reset
FAKE_LK_MODE=other-error livekit_config_fallback "${WORK}/livekit.yaml"
grep -q '^  skip_external_ip_validation: true' "${WORK}/livekit.yaml" || { echo "other-error: option removed"; exit 1; }
[ -z "${WARN_LOG}" ] || { echo "other-error: unexpected warning"; exit 1; }

# 4. Config without the option: LiveKit is not started at all
reset
sed -i '/skip_external_ip_validation/d' "${WORK}/livekit.yaml"
FAKE_LK_MODE=reject-skip livekit_config_fallback "${WORK}/livekit.yaml"
[ ! -s "${FAKE_LK_CALLS}" ] || { echo "no-option: livekit-server was started"; exit 1; }

echo "livekit-config-fallback tests passed"
