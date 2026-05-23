#!/usr/bin/env bash
set -euo pipefail

ADDON_DIR="${ADDON_DIR:-ts6_manager}"
VALIDATE_DOCKER="${VALIDATE_DOCKER:-auto}"
BUILD_ARCH="${BUILD_ARCH:-amd64}"
IMAGE_NAME="${IMAGE_NAME:-ts6-manager-ha-addon-smoke}"
SMOKE_HTTP_PORT="${SMOKE_HTTP_PORT:-18066}"
SMOKE_WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-120}"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || fail "Missing required file: $1"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
is_sha40() { [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]; }

get_docker_arg() {
  local file="$1" name="$2"
  awk -v name="$name" '$1 == "ARG" { line=$0; sub(/^ARG[[:space:]]+/, "", line); split(line, parts, "="); if (parts[1] == name) { sub("^[^=]*=", "", line); print line; exit } }' "$file"
}

tcp_open() { local host="$1" port="$2"; timeout 2 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; }

CONFIG_YAML="${ADDON_DIR}/config.yaml"
BUILD_YAML="${ADDON_DIR}/build.yaml"
DOCKERFILE="${ADDON_DIR}/Dockerfile"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"
UPDATE_SCRIPT="scripts/update-ts6-manager.sh"
INIT_SCRIPT="${ADDON_DIR}/rootfs/usr/bin/ts6-init-run.sh"
BACKEND_RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/ts6-backend/run"
NGINX_RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/ts6-nginx/run"
NGINX_CONF="${ADDON_DIR}/rootfs/etc/nginx/http.d/ts6manager.conf"

log "Validating Home Assistant TS6 Manager add-on structure"
need_file "$CONFIG_YAML"; need_file "$DOCKERFILE"; need_file "$CHANGELOG"; need_file "$UPDATE_SCRIPT"
need_file "$INIT_SCRIPT"; need_file "$BACKEND_RUN"; need_file "$NGINX_RUN"; need_file "$NGINX_CONF"
need_cmd yq

if [[ -f "$BUILD_YAML" ]]; then
  warn "$BUILD_YAML exists but build.yaml is deprecated. Remove it after the Dockerfile migration is committed."
fi

bash -n "$UPDATE_SCRIPT"; sh -n "$INIT_SCRIPT"; sh -n "$BACKEND_RUN"; sh -n "$NGINX_RUN"

SLUG="$(yq -r '.slug // ""' "$CONFIG_YAML")"
ADDON_VERSION="$(yq -r '.version // ""' "$CONFIG_YAML")"
BASE_FROM="$(awk '$1 == "FROM" && $2 ~ /^ghcr\.io\/hassio-addons\/base:/ { print $2; exit }' "$DOCKERFILE")"
BUILD_VERSION_ARG="$(get_docker_arg "$DOCKERFILE" "BUILD_VERSION")"
TS6_MANAGER_REPO="$(get_docker_arg "$DOCKERFILE" "TS6_MANAGER_REPO")"
TS6_MANAGER_BRANCH="$(get_docker_arg "$DOCKERFILE" "TS6_MANAGER_BRANCH")"
TS6_MANAGER_REF="$(get_docker_arg "$DOCKERFILE" "TS6_MANAGER_REF")"

[[ "$SLUG" == "ts6_manager" ]] || fail "Unexpected add-on slug: '$SLUG'"
[[ "$ADDON_VERSION" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]] || fail "Add-on version must look like 1.2.3 or 1.2.3.4: '$ADDON_VERSION'"
[[ "$BASE_FROM" == ghcr.io/hassio-addons/base:* ]] || fail "Dockerfile final stage must use ghcr.io/hassio-addons/base:* directly, got '$BASE_FROM'"
[[ -n "$BUILD_VERSION_ARG" ]] || fail "Dockerfile must define ARG BUILD_VERSION=<add-on-version>"
[[ "$BUILD_VERSION_ARG" == "$ADDON_VERSION" ]] || warn "Dockerfile ARG BUILD_VERSION (${BUILD_VERSION_ARG}) differs from config.yaml version (${ADDON_VERSION}); Supervisor should still pass BUILD_VERSION, but update the ARG default on next candidate."
[[ "$TS6_MANAGER_REPO" == "https://github.com/clusterzx/ts6-manager.git" ]] || fail "Unexpected TS6_MANAGER_REPO ARG: '$TS6_MANAGER_REPO'"
[[ "$TS6_MANAGER_BRANCH" == "main" ]] || fail "Unexpected TS6_MANAGER_BRANCH ARG: '$TS6_MANAGER_BRANCH'"
is_sha40 "$TS6_MANAGER_REF" || fail "TS6_MANAGER_REF must be pinned to a 40-character commit SHA, got '$TS6_MANAGER_REF'"

grep -q '^ARG BUILD_ARCH=' "$DOCKERFILE" || fail "Dockerfile must define ARG BUILD_ARCH with a default value"
grep -q '^ARG BUILD_VERSION=' "$DOCKERFILE" || fail "Dockerfile must define ARG BUILD_VERSION with a default value"
grep -q '^ARG TS6_MANAGER_REF=' "$DOCKERFILE" || fail "Dockerfile must define ARG TS6_MANAGER_REF with a pinned default"
grep -q 'git fetch --depth 1 origin "${TS6_MANAGER_REF}"' "$DOCKERFILE" || fail "Dockerfile must fetch the pinned TS6_MANAGER_REF"
grep -q 'git checkout --detach FETCH_HEAD' "$DOCKERFILE" || fail "Dockerfile must checkout the fetched upstream ref detached"
grep -q 'COPY rootfs /' "$DOCKERFILE" || fail "Dockerfile must copy rootfs/ into the image"
grep -q '/usr/bin/ts6-init-run.sh' "$DOCKERFILE" || fail "Dockerfile must chmod /usr/bin/ts6-init-run.sh"
if grep -q '/usr/bin/ts6-init.sh' "$DOCKERFILE"; then fail "Dockerfile still references old missing /usr/bin/ts6-init.sh"; fi
grep -q 'LABEL io.hass.name="TS6 Manager"' "$DOCKERFILE" || fail "Dockerfile must contain Home Assistant labels directly"
grep -q 'io.hass.version="${BUILD_VERSION}"' "$DOCKERFILE" || fail "Dockerfile must set io.hass.version label from BUILD_VERSION"

grep -q 'DATABASE_URL="file:/data/ts6webui.db"' "$BACKEND_RUN" || fail "Backend must keep SQLite database under /data/ts6webui.db"
grep -q 'MUSIC_DIR="/data/music"' "$BACKEND_RUN" || fail "Backend must keep music library under /data/music"
grep -q '/data/secrets.env' "$INIT_SCRIPT" || fail "Init script must keep secrets under /data/secrets.env"
grep -q '/data/ts6webui.db' "$INIT_SCRIPT" || fail "Init script must initialise SQLite under /data/ts6webui.db"
grep -q 'listen 8066' "$NGINX_CONF" || fail "nginx config must listen on 8066"

if grep -Eq 'git push +origin +(main|master)\b' "$UPDATE_SCRIPT"; then fail "update script must not push directly to main/master"; fi
if grep -Eq '/releases\b' "$UPDATE_SCRIPT" && ! grep -q 'CREATE_RELEASE is intentionally blocked' "$UPDATE_SCRIPT"; then fail "update script must not auto-create releases before review/merge"; fi

log "Static validation OK: add-on v${ADDON_VERSION}, TS6 Manager ${TS6_MANAGER_REF:0:12}, base ${BASE_FROM}"

if [[ "$VALIDATE_DOCKER" == "false" || "$VALIDATE_DOCKER" == "0" || "$VALIDATE_DOCKER" == "no" ]]; then
  log "Docker validation disabled by VALIDATE_DOCKER=${VALIDATE_DOCKER}"
  exit 0
fi
if ! command -v docker >/dev/null 2>&1; then
  if [[ "$VALIDATE_DOCKER" == "auto" ]]; then warn "Docker CLI not available; skipping Docker build/smoke test because VALIDATE_DOCKER=auto"; exit 0; fi
  fail "Docker is required for safe auto-update validation but the Docker CLI is not available"
fi
if ! docker info >/dev/null 2>&1; then
  if [[ "$VALIDATE_DOCKER" == "auto" ]]; then warn "Docker daemon is not reachable; skipping Docker build/smoke test because VALIDATE_DOCKER=auto"; warn "Use a self-hosted Forgejo runner with Docker access and VALIDATE_DOCKER=required for full smoke tests."; exit 0; fi
  docker version || true; fail "Docker is required for safe auto-update validation but the Docker daemon is not reachable"
fi

IMAGE_TAG="${IMAGE_NAME}:addon-${ADDON_VERSION}-${TS6_MANAGER_REF:0:12}-${BUILD_ARCH}"
log "Building smoke-test image: ${IMAGE_TAG}"
docker build --pull \
  --build-arg "BUILD_ARCH=${BUILD_ARCH}" \
  --build-arg "BUILD_VERSION=${ADDON_VERSION}" \
  --build-arg "TS6_MANAGER_REPO=${TS6_MANAGER_REPO}" \
  --build-arg "TS6_MANAGER_BRANCH=${TS6_MANAGER_BRANCH}" \
  --build-arg "TS6_MANAGER_REF=${TS6_MANAGER_REF}" \
  -t "${IMAGE_TAG}" \
  "${ADDON_DIR}"

TMP_ROOT="$(mktemp -d)"
CONTAINER_NAME="ts6-manager-ha-addon-smoke-${RANDOM}-${RANDOM}"
cleanup() { docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true; rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT
mkdir -p "${TMP_ROOT}/data" "${TMP_ROOT}/backup"
printf '{\n  "log_level": "info"\n}\n' > "${TMP_ROOT}/data/options.json"
log "Starting TS6 Manager smoke-test container"
docker run -d --name "${CONTAINER_NAME}" -p "127.0.0.1:${SMOKE_HTTP_PORT}:8066" -v "${TMP_ROOT}/data:/data" -v "${TMP_ROOT}/backup:/backup" "${IMAGE_TAG}" >/dev/null
log "Waiting for TS6 Manager web port to open"
DEADLINE=$((SECONDS + SMOKE_WAIT_SECONDS))
while (( SECONDS < DEADLINE )); do
  if tcp_open 127.0.0.1 "${SMOKE_HTTP_PORT}"; then log "Smoke test OK: TS6 Manager web port opened"; exit 0; fi
  if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then docker logs "${CONTAINER_NAME}" || true; fail "Smoke-test container exited before the web port opened"; fi
  sleep 2
done
docker logs "${CONTAINER_NAME}" || true
fail "Smoke test failed: TS6 Manager web port did not open within ${SMOKE_WAIT_SECONDS}s"
