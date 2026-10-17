#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

bashio::log.level "$(bashio::config 'log_level')"
bashio::log.info "Starting Unbound DNS resolver ($(bashio::app.version))..."

CUSTOM_CONFIG_PATH="/config/unbound.conf"
BLOCKLISTS_FILE="/data/blocklists.json"
BLOCKLIST_CONF="/etc/unbound/blocklist.conf"
LOCAL_RECORDS_FILE="/data/local_records.json"
LOCAL_RECORDS_CONF="/etc/unbound/local_records.conf"

# Initialize blocklists file if it doesn't exist
init_blocklists() {
    if [ ! -f "${BLOCKLISTS_FILE}" ]; then
        echo "[]" > "${BLOCKLISTS_FILE}"
        bashio::log.info "Initialized empty blocklists file"
    fi
}

# Download and apply blocklists
apply_blocklists() {
    bashio::log.info "Processing blocklists..."

    if [ ! -f "${BLOCKLISTS_FILE}" ]; then
        # No blocklists configured, write empty conf
        : > "${BLOCKLIST_CONF}"
        return
    fi

    local count
    count=$(jq '. | length' "${BLOCKLISTS_FILE}")
    if [ "${count}" = "0" ]; then
        bashio::log.info "No blocklists configured"
        : > "${BLOCKLIST_CONF}"
        return
    fi

    # The web UI code downloads, parses (hosts format and plain domain lines), subtracts the
    # whitelist and writes ${BLOCKLIST_CONF}, so a restart gives the same result as a manual
    # refresh. It prints the number of blocked domains; download problems go to stderr.
    local blocked
    if blocked=$(python3 /web/app.py --write-blocklist | tail -n 1) && [[ "${blocked}" =~ ^[0-9]+$ ]]; then
        bashio::log.info "Blocklists applied: ${blocked} domains blocked"
    else
        bashio::log.warning "  Could not process the blocklists, starting without them"
        : > "${BLOCKLIST_CONF}"
    fi
}

# Initialize local records file if it doesn't exist
init_local_records() {
    if [ ! -f "${LOCAL_RECORDS_FILE}" ]; then
        echo "[]" > "${LOCAL_RECORDS_FILE}"
        bashio::log.info "Initialized empty local records file"
    fi

    local rec_count
    rec_count=$(jq '. | length' "${LOCAL_RECORDS_FILE}")
    {
        echo "# Generated local records"
        echo "# Do not edit manually"
        echo
        echo "server:"
    } > "${LOCAL_RECORDS_CONF}"

    if [ "${rec_count}" != "0" ]; then
        bashio::log.info "Writing ${rec_count} local DNS record(s)..."
        for i in $(seq 0 $((rec_count - 1))); do
            local hostname rtype value ttl
            hostname=$(jq -r ".[${i}].hostname // empty" "${LOCAL_RECORDS_FILE}" | sed 's/[.]$//')
            rtype=$(jq -r ".[${i}].type // \"A\"" "${LOCAL_RECORDS_FILE}" | tr '[:lower:]' '[:upper:]')
            value=$(jq -r ".[${i}].value // .[${i}].ip // empty" "${LOCAL_RECORDS_FILE}" | sed 's/[.]$//')
            ttl=$(jq -r ".[${i}].ttl // 300" "${LOCAL_RECORDS_FILE}")

            if [ -z "${hostname}" ] || [ -z "${value}" ]; then
                bashio::log.warning "  Skipping invalid local record at index ${i}"
                continue
            fi

            case "${rtype}" in
                A|AAAA)
                    bashio::log.info "  ${hostname} ${rtype} ${value}"
                    echo "    local-zone: \"${hostname}.\" static" >> "${LOCAL_RECORDS_CONF}"
                    echo "    local-data: \"${hostname}. ${ttl} IN ${rtype} ${value}\"" >> "${LOCAL_RECORDS_CONF}"
                    ;;
                CNAME)
                    bashio::log.info "  ${hostname} CNAME ${value}"
                    echo "    local-zone: \"${hostname}.\" transparent" >> "${LOCAL_RECORDS_CONF}"
                    echo "    local-data: \"${hostname}. ${ttl} IN CNAME ${value}.\"" >> "${LOCAL_RECORDS_CONF}"
                    ;;
                PTR)
                    bashio::log.info "  ${hostname} PTR ${value}"
                    echo "    local-data-ptr: \"${hostname} ${value}.\"" >> "${LOCAL_RECORDS_CONF}"
                    ;;
                *)
                    bashio::log.warning "  Skipping unsupported local record type: ${rtype}"
                    ;;
            esac
        done
    fi
}

# Update root hints (fallback to bundled copy on failure)
bashio::log.info "Updating root hints..."
if curl \
    --fail \
    --location \
    --show-error \
    --silent \
    --connect-timeout 10 \
    --max-time 30 \
    --max-filesize 1048576 \
    --max-redirs 3 \
    --output /etc/unbound/root.hints.tmp \
    https://www.internic.net/domain/named.root 2>/dev/null; then
    mv /etc/unbound/root.hints.tmp /etc/unbound/root.hints
    bashio::log.info "Root hints updated"
else
    rm -f /etc/unbound/root.hints.tmp
    bashio::log.warning "Failed to update root hints, using bundled copy"
fi

# ── unbound-control keys ───────────────────────────────────────────────────
# Generated once per installation (not in the image, where they would be the
# same for everyone) and kept in /data. unbound and unbound-control look for
# them in /etc/unbound, so link them there on every start. The server runs as
# the unbound user and re-reads the files on reload, so they must be readable
# by that group.
CONTROL_DIR="/data/unbound-control"
if [ ! -f "${CONTROL_DIR}/unbound_control.key" ] || [ ! -f "${CONTROL_DIR}/unbound_server.key" ]; then
    bashio::log.info "Generating unbound-control keys (first start) ..."
    mkdir -p "${CONTROL_DIR}"
    unbound-control-setup -d "${CONTROL_DIR}" >/dev/null 2>&1 \
        || { bashio::log.error "unbound-control-setup failed"; exit 1; }
fi
chown root:unbound "${CONTROL_DIR}" "${CONTROL_DIR}"/*
chmod 0750 "${CONTROL_DIR}"
chmod 0640 "${CONTROL_DIR}"/*.key
chmod 0644 "${CONTROL_DIR}"/*.pem
for f in unbound_server.key unbound_server.pem unbound_control.key unbound_control.pem; do
    ln -sf "${CONTROL_DIR}/${f}" "/etc/unbound/${f}"
done

# Seed config.json from options.json on first run
python3 /web/config_gen.py --seed-if-needed

# Check custom_config from config.json
CUSTOM_CONFIG_WARNING="/data/custom_config_warning.txt"
USE_CUSTOM=false
if jq -e '.custom_config == true' /data/config.json >/dev/null 2>&1; then
    bashio::log.info "Custom config mode enabled"

    if [ ! -f "${CUSTOM_CONFIG_PATH}" ]; then
        bashio::log.warning "Custom config enabled but ${CUSTOM_CONFIG_PATH} not found!"
        bashio::log.warning "Place your unbound.conf at the host path /addon_configs/<slug>/unbound.conf"
        bashio::log.warning "Falling back to web UI configuration..."
        echo "Custom config file not found at ${CUSTOM_CONFIG_PATH}. Falling back to web UI configuration." \
            > "${CUSTOM_CONFIG_WARNING}"
    else
        bashio::log.info "Using custom config from ${CUSTOM_CONFIG_PATH}"
        cp "${CUSTOM_CONFIG_PATH}" /etc/unbound/unbound.conf

        bashio::log.info "Validating custom configuration..."
        CHECKCONF_OUTPUT=$(unbound-checkconf /etc/unbound/unbound.conf 2>&1) || true
        if echo "${CHECKCONF_OUTPUT}" | grep -q "^unbound-checkconf: no errors"; then
            USE_CUSTOM=true
            rm -f "${CUSTOM_CONFIG_WARNING}"
        else
            bashio::log.warning "Custom config failed validation!"
            bashio::log.warning "Falling back to web UI configuration..."
            echo "Custom config failed validation: ${CHECKCONF_OUTPUT}" \
                > "${CUSTOM_CONFIG_WARNING}"
        fi
    fi
else
    rm -f "${CUSTOM_CONFIG_WARNING}"
fi

if [ "${USE_CUSTOM}" = "false" ]; then
    # Generated config mode: prepare include targets before --generate so the
    # built-in validate-with-overlay-fallback step in config_gen.py sees them.
    init_blocklists
    apply_blocklists
    init_local_records
    [ -f /data/stub_zones.json ] || echo '[]' > /data/stub_zones.json

    bashio::log.info "Generating and validating Unbound configuration..."
    if ! python3 /web/config_gen.py --generate; then
        bashio::log.error "Invalid Unbound configuration!"
        bashio::log.error "Generated config:"
        cat /etc/unbound/unbound.conf
        exit 1
    fi

    if [ -f /data/overlay_warning.txt ]; then
        bashio::log.warning "Overlay disabled — see web UI banner for details."
    fi
fi

bashio::log.info "Configuration valid. Starting Unbound..."

# Ensure query log exists (custom config mode needs it too). Owned
# group "unbound", mode 0660: unbound (the daemon, after privilege
# drop) and root (this script, and app.py) are both in that group, so
# no need for world-writable permissions. Only initialize on first
# run — re-running install would truncate an existing log on restart.
if [ ! -f /data/unbound_queries.log ]; then
    install -m 0660 -g unbound /dev/null /data/unbound_queries.log
fi

# Start web UI in background
bashio::log.info "Starting web UI on port 2137..."
INGRESS_PATH=$(bashio::app.ingress_entry) \
    python3 /web/app.py &
WEBUI_PID=$!

# Run unbound as a tracked background job (not exec) so we can catch the
# stop signal ourselves and translate it into a clean exit. Without this,
# a normal "Stop" from the Supervisor forwards SIGTERM straight to unbound;
# unbound shuts down correctly (see the clean "service stopped" log lines),
# but its own signal-exit status isn't guaranteed to be 0, and the base
# image's legacy-services wrapper judges "crashed vs. stopped cleanly" by
# that exit code alone, regardless of what the log actually says. Result:
# a perfectly healthy stop gets shown as add-on status "Error".
start_unbound() {
    unbound -d -c /etc/unbound/unbound.conf &
    UNBOUND_PID=$!
}
start_unbound

shutdown() {
    bashio::log.info "Stop signal received, shutting down Unbound..."
    kill -TERM "${UNBOUND_PID}" 2>/dev/null || true
    wait "${UNBOUND_PID}" 2>/dev/null || true
    kill -TERM "${WEBUI_PID}" 2>/dev/null || true
    wait "${WEBUI_PID}" 2>/dev/null || true
    bashio::log.info "Unbound stopped cleanly."
    exit 0
}
trap shutdown TERM INT

# A DNS resolver that dies must come back by itself: without this the whole add-on
# exits and stays down (state "Error") until someone starts it again, because the
# Supervisor only restarts add-ons when its Watchdog switch is on. After an
# unexpected exit Unbound is started again. If it keeps dying (more than
# MAX_RESTARTS times within RESTART_WINDOW seconds) the add-on gives up and exits
# with Unbound's exit code, so a broken configuration does not loop forever.
MAX_RESTARTS=5
RESTART_WINDOW=300
restarts=0
window_start=$(date +%s)

# set -e would otherwise kill the script the instant `wait` reports
# unbound's real (possibly signal-derived) exit status; disable it around
# the wait so a normal stop can reach the trap/exit-0 path above, and a
# genuine unexpected crash (unbound exits on its own, no signal involved)
# is handled below with its real exit code.
while true; do
    set +e
    wait "${UNBOUND_PID}"
    UNBOUND_EXIT=$?
    set -e

    bashio::log.error "Unbound exited unexpectedly (code ${UNBOUND_EXIT})."

    now=$(date +%s)
    if [ $((now - window_start)) -gt "${RESTART_WINDOW}" ]; then
        window_start=${now}
        restarts=0
    fi
    restarts=$((restarts + 1))
    if [ "${restarts}" -gt "${MAX_RESTARTS}" ]; then
        bashio::log.fatal "Unbound keeps exiting (more than ${MAX_RESTARTS} restarts in ${RESTART_WINDOW} s), giving up."
        kill -TERM "${WEBUI_PID}" 2>/dev/null || true
        exit "${UNBOUND_EXIT}"
    fi

    bashio::log.warning "Restarting Unbound in 2 s (restart ${restarts} of ${MAX_RESTARTS})..."
    sleep 2
    start_unbound
done
