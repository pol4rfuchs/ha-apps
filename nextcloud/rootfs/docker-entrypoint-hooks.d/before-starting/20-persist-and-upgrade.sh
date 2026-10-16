#!/bin/bash
# Runs after the official entrypoint's install/upgrade step, before Apache starts
# (as www-data). Complements ha-init.sh, see the layout notes there.
#   1. first start: move config, custom_apps and themes to /data/nextcloud and
#      link them back into /var/www/html
#   2. image newer than the saved version: run `occ upgrade` (the entrypoint
#      skips it because ha-init.sh presents the image's version.php)
#   3. save the version of the code now installed
set -euo pipefail

NC_BASE=/data/nextcloud
NC_HTML=/var/www/html
NC_SRC=/usr/src/nextcloud

version_of() {
    php -r 'require $argv[1]; echo implode(".", $OC_Version);' "$1"
}
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

# 1. persist directories created by a fresh installation
for d in config custom_apps themes; do
    if [[ ! -L "${NC_HTML}/${d}" ]]; then
        mkdir -p "${NC_BASE}/${d}"
        cp -a "${NC_HTML}/${d}/." "${NC_BASE}/${d}/"
        rm -rf "${NC_HTML:?}/${d}"
        ln -s "${NC_BASE}/${d}" "${NC_HTML}/${d}"
        echo "[ha-persist] ${d} moved to ${NC_BASE}/${d}"
    fi
done

# 2. upgrade
image_version="$(version_of "${NC_SRC}/version.php")"
if [[ -f "${NC_BASE}/version.php" ]]; then
    saved_version="$(version_of "${NC_BASE}/version.php")"
    if version_greater "${saved_version}" "${image_version}"; then
        echo "[ha-persist] Can't start Nextcloud: the data (${saved_version}) is newer than this add-on (${image_version}). Downgrading is not supported."
        exit 1
    fi
    if version_greater "${image_version}" "${saved_version}"; then
        if [ "${image_version%%.*}" -gt "$((${saved_version%%.*} + 1))" ]; then
            echo "[ha-persist] Can't upgrade from ${saved_version} to ${image_version}: only one major version at a time is supported."
            exit 1
        fi
        echo "[ha-persist] Upgrading Nextcloud ${saved_version} -> ${image_version}"
        php "${NC_HTML}/occ" upgrade
    fi
fi

# 3. remember the installed version
cp "${NC_HTML}/version.php" "${NC_BASE}/version.php"
