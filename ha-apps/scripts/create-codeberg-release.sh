#!/usr/bin/env bash
set -euo pipefail

ADDON_DIR="${ADDON_DIR:?ADDON_DIR must be set, e.g. ntfy, teamspeak6 or ts6_manager}"
CODEBERG_OWNER="${CODEBERG_OWNER:-Pol4rFuchs}"
CODEBERG_REPO="${CODEBERG_REPO:?CODEBERG_REPO must be set}"
CODEBERG_BASE_URL="${CODEBERG_BASE_URL:-https://codeberg.org}"
CODEBERG_API="${CODEBERG_API:-${CODEBERG_BASE_URL}/api/v1}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
TAG_PREFIX="${TAG_PREFIX:-}"
DRY_RUN="${DRY_RUN:-false}"

CONFIG_YAML="${ADDON_DIR}/config.yaml"
BUILD_YAML="${ADDON_DIR}/build.yaml"
DOCKERFILE="${ADDON_DIR}/Dockerfile"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"
REMOTE_URL="https://codeberg.org/${CODEBERG_OWNER}/${CODEBERG_REPO}.git"
RELEASE_SCRIPT_BANNER="release-on-main v8: build.yaml-free, Forgejo-token first, token-auth header, remote-tag-safe"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

read_yaml_scalar() {
  local key="$1" file="$2"
  awk -v key="$key" '$0 ~ "^[[:space:]]*" key ":[[:space:]]*" { sub("^[[:space:]]*" key ":[[:space:]]*", "", $0); gsub(/^"/, "", $0); gsub(/"$/, "", $0); gsub(/^\047/, "", $0); gsub(/\047$/, "", $0); print $0; exit }' "$file"
}

read_yaml_nested_scalar() {
  local parent="$1" key="$2" file="$3"
  awk -v parent="$parent" -v key="$key" '
    $0 ~ "^[[:space:]]*" parent ":[[:space:]]*$" { in_parent=1; next }
    in_parent && $0 ~ "^[^[:space:]]" { in_parent=0 }
    in_parent && $0 ~ "^[[:space:]]+" key ":[[:space:]]*" { sub("^[[:space:]]+" key ":[[:space:]]*", "", $0); gsub(/^"/, "", $0); gsub(/"$/, "", $0); gsub(/^\047/, "", $0); gsub(/\047$/, "", $0); print $0; exit }
  ' "$file"
}

read_docker_arg() {
  local key="$1" file="$2"
  [[ -f "$file" ]] || return 0
  awk -v key="$key" '
    $1 == "ARG" {
      line=$0
      sub(/^ARG[[:space:]]+/, "", line)
      split(line, parts, "=")
      if (parts[1] == key) {
        sub("^[^=]*=", "", line)
        gsub(/^"/, "", line)
        gsub(/"$/, "", line)
        gsub(/^\047/, "", line)
        gsub(/\047$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

select_api_token() {
  if [[ -n "${FORGEJO_TOKEN:-}" ]]; then
    API_TOKEN="$FORGEJO_TOKEN"; API_TOKEN_SOURCE="FORGEJO_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    API_TOKEN="$GITHUB_TOKEN"; API_TOKEN_SOURCE="GITHUB_TOKEN"
  elif [[ -n "${ACTIONS_TOKEN:-}" ]]; then
    API_TOKEN="$ACTIONS_TOKEN"; API_TOKEN_SOURCE="ACTIONS_TOKEN"
  elif [[ -n "${CODEBERG_TOKEN:-}" ]]; then
    API_TOKEN="$CODEBERG_TOKEN"; API_TOKEN_SOURCE="CODEBERG_TOKEN"
  else
    fail "No API token available. Use Forgejo automatic token or set CODEBERG_TOKEN with write:repository."
  fi
}

api_get_status() {
  local url="$1" out="$2"
  curl -sS -o "$out" -w '%{http_code}' \
    -H "Authorization: token ${API_TOKEN}" \
    -H "Accept: application/json" \
    "$url" || true
}

setup_git_auth() {
  ASKPASS_FILE="$(mktemp)"
  cat > "$ASKPASS_FILE" <<'ASKPASS'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s\n' "${GIT_USERNAME:-forgejo-actions}" ;;
  *Password*) printf '%s\n' "${GIT_PASSWORD:-}" ;;
  *) printf '\n' ;;
esac
ASKPASS
  chmod 700 "$ASKPASS_FILE"
  export GIT_ASKPASS="$ASKPASS_FILE"
  export GIT_USERNAME="forgejo-actions"
  export GIT_PASSWORD="$API_TOKEN"
  export GIT_TERMINAL_PROMPT=0
}

cleanup() {
  for f in "${ASKPASS_FILE:-}" "${BODY_FILE:-}" "${LOOKUP_BODY:-}" "${CREATE_BODY:-}" "${USER_BODY:-}"; do
    [[ -n "$f" && -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

need_cmd awk; need_cmd curl; need_cmd git; need_cmd jq; need_cmd date
log "$RELEASE_SCRIPT_BANNER"
[[ -f "$CONFIG_YAML" ]] || fail "Missing $CONFIG_YAML"
if [[ ! -f "$BUILD_YAML" && ! -f "$DOCKERFILE" ]]; then
  fail "Missing both $BUILD_YAML and $DOCKERFILE. Need one source for upstream metadata."
fi
if [[ -f "$BUILD_YAML" ]]; then
  warn "$BUILD_YAML exists but is deprecated. Prefer Dockerfile ARG metadata."
fi

select_api_token
setup_git_auth
log "API token source: ${API_TOKEN_SOURCE}"

USER_BODY="$(mktemp)"
USER_STATUS="$(api_get_status "${CODEBERG_API}/user" "$USER_BODY")"
if [[ "$USER_STATUS" == "200" ]]; then
  API_USER="$(jq -r '.login // .username // .full_name // "unknown"' "$USER_BODY" 2>/dev/null || echo unknown)"
  log "API authenticated as: ${API_USER}"
else
  warn "API /user preflight returned HTTP ${USER_STATUS}. Release creation may fail. Response:"
  cat "$USER_BODY" >&2 || true
fi

ADDON_VERSION="$(read_yaml_scalar version "$CONFIG_YAML")"
[[ -n "$ADDON_VERSION" ]] || fail "Could not read .version from $CONFIG_YAML"
[[ "$ADDON_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || fail "Invalid add-on version: '$ADDON_VERSION'"

TAG="${TAG_PREFIX}${ADDON_VERSION}"
TITLE="$TAG"
TODAY="$(date -u +%Y-%m-%d)"
CURRENT_HEAD="$(git rev-parse HEAD)"

NTFY_VERSION=""
TS6_VERSION=""
TS6_MANAGER_REF=""
TS6_MANAGER_REPO=""

if [[ -f "$BUILD_YAML" ]]; then
  NTFY_VERSION="$(read_yaml_nested_scalar args NTFY_VERSION "$BUILD_YAML" || true)"
  TS6_VERSION="$(read_yaml_nested_scalar args TEAMSPEAK_VERSION "$BUILD_YAML" || true)"
  TS6_MANAGER_REF="$(read_yaml_nested_scalar args TS6_MANAGER_REF "$BUILD_YAML" || true)"
  TS6_MANAGER_REPO="$(read_yaml_nested_scalar args TS6_MANAGER_REPO "$BUILD_YAML" || true)"
fi

if [[ -f "$DOCKERFILE" ]]; then
  NTFY_VERSION="${NTFY_VERSION:-$(read_docker_arg NTFY_VERSION "$DOCKERFILE" || true)}"
  TS6_VERSION="${TS6_VERSION:-$(read_docker_arg TEAMSPEAK_VERSION "$DOCKERFILE" || true)}"
  TS6_MANAGER_REF="${TS6_MANAGER_REF:-$(read_docker_arg TS6_MANAGER_REF "$DOCKERFILE" || true)}"
  TS6_MANAGER_REPO="${TS6_MANAGER_REPO:-$(read_docker_arg TS6_MANAGER_REPO "$DOCKERFILE" || true)}"
fi

BODY_FILE="$(mktemp)"
{
  printf '## %s\n\n' "$TITLE"
  printf 'Generated automatically after merge to `%s`.\n\n' "$TARGET_BRANCH"
  printf -- '- Add-on version: `%s`\n' "$ADDON_VERSION"
  [[ -n "$NTFY_VERSION" ]] && printf -- '- Upstream ntfy: `%s`\n' "$NTFY_VERSION"
  [[ -n "$TS6_VERSION" ]] && printf -- '- Upstream TeamSpeak 6 Server: `%s`\n' "$TS6_VERSION"
  [[ -n "$TS6_MANAGER_REF" ]] && printf -- '- Upstream TS6 Manager ref: `%s`\n' "$TS6_MANAGER_REF"
  [[ -n "$TS6_MANAGER_REPO" ]] && printf -- '- Upstream TS6 Manager repo: `%s`\n' "$TS6_MANAGER_REPO"
  printf -- '- Source branch: `%s`\n' "$TARGET_BRANCH"
  printf -- '- Release date: `%s`\n' "$TODAY"
  if [[ -f "$CHANGELOG" ]]; then
    printf '\n---\n\n### Changelog excerpt\n\n'
    awk 'BEGIN { count=0; seen=0 } /^##[[:space:]]/ { if (seen) exit; seen=1 } seen { print; count++; if (count >= 60) exit }' "$CHANGELOG"
  fi
} > "$BODY_FILE"

log "Preparing Codeberg release ${TAG} for ${CODEBERG_OWNER}/${CODEBERG_REPO}"
log "Add-on directory: ${ADDON_DIR}"

git fetch --tags "$REMOTE_URL" >/dev/null 2>&1 || true
REMOTE_TAG_EXISTS=false
git ls-remote --exit-code --tags "$REMOTE_URL" "refs/tags/${TAG}" >/dev/null 2>&1 && REMOTE_TAG_EXISTS=true

if [[ "$REMOTE_TAG_EXISTS" == "true" ]]; then
  log "Git tag already exists remotely: ${TAG}"
else
  if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    LOCAL_TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
    if [[ "$LOCAL_TAG_COMMIT" != "$CURRENT_HEAD" ]]; then
      warn "Local tag ${TAG} points to ${LOCAL_TAG_COMMIT}, not current HEAD ${CURRENT_HEAD}. Recreating local tag before push."
      git tag -d "$TAG"
      git tag -a "$TAG" -m "Release ${TAG}"
    else
      log "Git tag already exists locally on current HEAD: ${TAG}"
    fi
  else
    log "Creating Git tag: ${TAG}"
    git config user.name "Forgejo Actions Bot"
    git config user.email "actions@noreply.codeberg.org"
    git tag -a "$TAG" -m "Release ${TAG}"
  fi
  if [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN=true: not pushing tag"
  else
    log "Pushing Git tag: ${TAG}"
    git push "$REMOTE_URL" "refs/tags/${TAG}:refs/tags/${TAG}"
  fi
fi

RELEASE_LOOKUP_URL="${CODEBERG_API}/repos/${CODEBERG_OWNER}/${CODEBERG_REPO}/releases/tags/${TAG}"
LOOKUP_BODY="$(mktemp)"
LOOKUP_STATUS="$(api_get_status "$RELEASE_LOOKUP_URL" "$LOOKUP_BODY")"
if [[ "$LOOKUP_STATUS" == "200" ]]; then
  log "Codeberg release already exists for tag ${TAG}. Nothing to do."
  exit 0
fi
if [[ "$LOOKUP_STATUS" != "404" ]]; then
  warn "Release lookup returned HTTP ${LOOKUP_STATUS}. Response:"
  cat "$LOOKUP_BODY" >&2 || true
  fail "Cannot safely determine whether release already exists."
fi

CREATE_URL="${CODEBERG_API}/repos/${CODEBERG_OWNER}/${CODEBERG_REPO}/releases"
PAYLOAD="$(jq -n --arg tag "$TAG" --arg title "$TITLE" --arg target "$TARGET_BRANCH" --rawfile body "$BODY_FILE" '{tag_name:$tag, target_commitish:$target, name:$title, body:$body, draft:false, prerelease:false}')"

log "Creating Codeberg release entry: ${TITLE}"
if [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]; then
  log "DRY_RUN=true: not creating release"
  printf '%s\n' "$PAYLOAD"
  exit 0
fi
CREATE_BODY="$(mktemp)"
CREATE_STATUS="$(curl -sS -o "$CREATE_BODY" -w '%{http_code}' \
  -X POST \
  -H "Authorization: token ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$PAYLOAD" \
  "$CREATE_URL" || true)"
case "$CREATE_STATUS" in
  200|201)
    log "Release created: ${CODEBERG_BASE_URL}/${CODEBERG_OWNER}/${CODEBERG_REPO}/releases/tag/${TAG}" ;;
  409|422)
    warn "Release may already exist or API rejected duplicate creation. HTTP ${CREATE_STATUS}:"
    cat "$CREATE_BODY" >&2 || true
    log "Treating duplicate-style response as non-fatal." ;;
  403)
    warn "Release creation failed with HTTP 403. Response:"
    cat "$CREATE_BODY" >&2 || true
    fail "Token has no repository write permission for release creation. Use Forgejo automatic token on push/workflow_dispatch or create CODEBERG_TOKEN with write:repository for this repo." ;;
  *)
    warn "Release creation failed. HTTP ${CREATE_STATUS}:"
    cat "$CREATE_BODY" >&2 || true
    fail "Codeberg release creation failed." ;;
esac
