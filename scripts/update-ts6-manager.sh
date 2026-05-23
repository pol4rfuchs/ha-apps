#!/usr/bin/env bash
set -euo pipefail

ADDON_DIR="${ADDON_DIR:-ts6_manager}"
GH_REPO="${GH_REPO:-clusterzx/ts6-manager}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
CODEBERG_REPO="${CODEBERG_REPO:-Pol4rFuchs/ha-apps}"
BASE_BRANCH="${BASE_BRANCH:-main}"
UPDATE_MODE="${UPDATE_MODE:-candidate}"
CREATE_RELEASE="${CREATE_RELEASE:-false}"
CREATE_PR="${CREATE_PR:-false}"
TARGET_TS6_MANAGER_REF="${TARGET_TS6_MANAGER_REF:-}"
VALIDATE_DOCKER="${VALIDATE_DOCKER:-auto}"

CONFIG_YAML="${ADDON_DIR}/config.yaml"
DOCKERFILE="${ADDON_DIR}/Dockerfile"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"
UPDATE_SCRIPT="scripts/update-ts6-manager.sh"
VALIDATE_SCRIPT="scripts/validate-addon.sh"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

is_sha40() { [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]; }
short_sha() { printf '%s' "$1" | cut -c1-12; }

bump_addon_version() {
  local old="$1" a b c d
  IFS='.' read -r a b c d <<< "$old"
  [[ -n "${a:-}" && -n "${b:-}" && -n "${c:-}" ]] || fail "Cannot bump add-on version: '$old'"
  if [[ -n "${d:-}" ]]; then
    d=$((10#$d + 1)); printf '%s.%s.%s.%s' "$a" "$b" "$c" "$d"
  else
    c=$((10#$c + 1)); printf '%s.%s.%s' "$a" "$b" "$c"
  fi
}

get_docker_arg() {
  local file="$1" name="$2"
  awk -v name="$name" '$1 == "ARG" { line=$0; sub(/^ARG[[:space:]]+/, "", line); split(line, parts, "="); if (parts[1] == name) { sub("^[^=]*=", "", line); print line; exit } }' "$file"
}

set_docker_arg() {
  local file="$1" name="$2" value="$3"
  python3 -S - "$file" "$name" "$value" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1]); name = sys.argv[2]; value = sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines()
needle = f"ARG {name}="; replacement = f"ARG {name}={value}"
for i, line in enumerate(lines):
    if line.startswith(needle):
        lines[i] = replacement
        break
else:
    insert_at = 0
    while insert_at < len(lines) and (lines[insert_at].startswith("#") or lines[insert_at].strip() == "" or lines[insert_at].startswith("ARG ")):
        insert_at += 1
    lines.insert(insert_at, replacement)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

resolve_upstream_ref() {
  local ref="$1" url json sha date message author
  [[ -n "$ref" ]] || fail "resolve_upstream_ref called with empty ref"
  url="https://api.github.com/repos/${GH_REPO}/commits/${ref}"
  json="$(curl -fsSL -H "Accept: application/vnd.github+json" "$url")"
  [[ "$(printf '%s\n' "$json" | jq -r 'type')" == "object" ]] || fail "GitHub commit endpoint did not return an object for ref '${ref}'"
  sha="$(printf '%s\n' "$json" | jq -r '.sha // empty')"
  is_sha40 "$sha" || fail "GitHub did not return a valid commit SHA for ref '${ref}'"
  date="$(printf '%s\n' "$json" | jq -r '.commit.author.date // .commit.committer.date // ""' | cut -d'T' -f1)"
  message="$(printf '%s\n' "$json" | jq -r '.commit.message // ""' | head -n 1)"
  author="$(printf '%s\n' "$json" | jq -r '.commit.author.name // .commit.committer.name // "unknown"')"
  printf '%s\t%s\t%s\t%s\n' "$sha" "$date" "$author" "$message"
}

push_branch_with_askpass() {
  local branch="$1" askpass remote remote_sha
  [[ -n "${CODEBERG_TOKEN:-}" ]] || fail "CODEBERG_TOKEN secret is required to push the candidate branch"
  remote="https://codeberg.org/${CODEBERG_REPO}.git"

  askpass="$(mktemp)"
  cat > "$askpass" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s
' "forgejo-actions" ;;
  *Password*) printf '%s
' "$CODEBERG_TOKEN" ;;
  *) printf '
' ;;
esac
EOF
  chmod 700 "$askpass"

  remote_sha="$(GIT_ASKPASS="$askpass" CODEBERG_TOKEN="$CODEBERG_TOKEN" git ls-remote --heads "$remote" "$branch" | awk '{print $1}' || true)"

  if [[ -n "$remote_sha" ]]; then
    log "Remote candidate branch already exists at ${remote_sha}; updating it with explicit --force-with-lease"
    GIT_ASKPASS="$askpass" CODEBERG_TOKEN="$CODEBERG_TOKEN" git push \
      --force-with-lease="refs/heads/${branch}:${remote_sha}" \
      "$remote" "HEAD:refs/heads/${branch}"
  else
    log "Remote candidate branch does not exist yet; creating it"
    GIT_ASKPASS="$askpass" CODEBERG_TOKEN="$CODEBERG_TOKEN" git push \
      "$remote" "HEAD:refs/heads/${branch}"
  fi

  rm -f "$askpass"
}

need_cmd curl; need_cmd jq; need_cmd yq; need_cmd git; need_cmd cut; need_cmd sed; need_cmd date; need_cmd python3
[[ -f "$CONFIG_YAML" ]] || fail "Missing $CONFIG_YAML"
[[ -f "$DOCKERFILE" ]] || fail "Missing $DOCKERFILE"
[[ -f "$UPDATE_SCRIPT" ]] || fail "Missing $UPDATE_SCRIPT"
[[ -f "$VALIDATE_SCRIPT" ]] || fail "Missing $VALIDATE_SCRIPT"
[[ -f "$CHANGELOG" ]] || touch "$CHANGELOG"

if [[ -f "${ADDON_DIR}/build.yaml" ]]; then
  warn "${ADDON_DIR}/build.yaml exists but is deprecated. This updater uses Dockerfile ARG defaults as source of truth. Remove build.yaml after verifying the workflow."
fi

log "TS6 Manager safe updater v8: build.yaml-free Dockerfile ARG candidate flow, remote-branch-safe push"
TARGET_REF="${TARGET_TS6_MANAGER_REF:-$UPSTREAM_BRANCH}"
log "Resolving upstream ${GH_REPO}@${TARGET_REF}"
IFS=$'\t' read -r LATEST_SHA LATEST_DATE LATEST_AUTHOR LATEST_MESSAGE < <(resolve_upstream_ref "$TARGET_REF")
LATEST_SHORT="$(short_sha "$LATEST_SHA")"
LATEST_URL="https://github.com/${GH_REPO}/commit/${LATEST_SHA}"
[[ -n "$LATEST_DATE" ]] || LATEST_DATE="$(date -u +%Y-%m-%d)"
[[ -n "$LATEST_MESSAGE" ]] || LATEST_MESSAGE="No upstream commit message available."
log "Upstream selected: ${LATEST_SHA} (${LATEST_MESSAGE})"

CURRENT_REF="$(get_docker_arg "$DOCKERFILE" "TS6_MANAGER_REF")"
log "Current TS6 Manager ref: '${CURRENT_REF:-unset}'"

if [[ "$CURRENT_REF" == "$LATEST_SHA" ]]; then
  log "Already up-to-date. Nothing to do."
  exit 0
fi

CURRENT_ADDON_VERSION="$(yq -r '.version // "1.0.0"' "$CONFIG_YAML")"
[[ "$CURRENT_ADDON_VERSION" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]] || fail "Add-on version must look like 1.2.3 or 1.2.3.4: '$CURRENT_ADDON_VERSION'"
NEW_ADDON_VERSION="$(bump_addon_version "$CURRENT_ADDON_VERSION")"
BRANCH_NAME="auto/ts6-manager-${LATEST_SHORT}"

log "Updating add-on version: ${CURRENT_ADDON_VERSION} -> ${NEW_ADDON_VERSION}"
log "Updating TS6 Manager ref: ${CURRENT_REF:-unset} -> ${LATEST_SHA}"

yq -i ".version = \"${NEW_ADDON_VERSION}\"" "$CONFIG_YAML"
set_docker_arg "$DOCKERFILE" "BUILD_VERSION" "$NEW_ADDON_VERSION"
set_docker_arg "$DOCKERFILE" "TS6_MANAGER_REPO" "https://github.com/${GH_REPO}.git"
set_docker_arg "$DOCKERFILE" "TS6_MANAGER_BRANCH" "${UPSTREAM_BRANCH}"
set_docker_arg "$DOCKERFILE" "TS6_MANAGER_REF" "${LATEST_SHA}"

if ! grep -q '^# Changelog' "$CHANGELOG" 2>/dev/null; then
  cat > "$CHANGELOG" <<'EOF'
# Changelog

EOF
fi
TMP_CHANGELOG="$(mktemp)"
{
  printf '# Changelog\n\n'
  printf '## %s\n\n' "$NEW_ADDON_VERSION"
  printf '%s\n' "- Update upstream clusterzx/ts6-manager to ${LATEST_SHA}."
  printf '%s\n' "- Upstream commit: ${LATEST_URL}"
  printf '%s\n' "- Commit date: ${LATEST_DATE}"
  printf '%s\n' "- Commit author: ${LATEST_AUTHOR}"
  printf '%s\n\n' "- Commit subject: ${LATEST_MESSAGE}"
  sed '1{/^# Changelog$/d;}' "$CHANGELOG" | sed '/./,$!d'
} > "$TMP_CHANGELOG"
mv "$TMP_CHANGELOG" "$CHANGELOG"

log "Running validator before branch push"
VALIDATE_DOCKER="$VALIDATE_DOCKER" ADDON_DIR="$ADDON_DIR" bash "$VALIDATE_SCRIPT"

if [[ "$UPDATE_MODE" == "local" ]]; then
  log "UPDATE_MODE=local: leaving changes in working tree; no branch push."
  exit 0
fi
[[ "$UPDATE_MODE" == "candidate" ]] || fail "Unsupported UPDATE_MODE='${UPDATE_MODE}'"
if [[ "$CREATE_RELEASE" == "true" || "$CREATE_RELEASE" == "1" || "$CREATE_RELEASE" == "yes" ]]; then
  fail "CREATE_RELEASE is intentionally blocked for safe HA updates. Merge candidate branches manually first."
fi

if ! git diff --quiet; then
  git config user.name "Forgejo Safe Updater"
  git config user.email "forgejo-safe-updater@users.noreply.codeberg.org"
  log "Creating candidate branch ${BRANCH_NAME}"
  git checkout -B "$BRANCH_NAME"
  git add "$CONFIG_YAML" "$DOCKERFILE" "$CHANGELOG"
  git commit -m "chore(ts6-manager): update upstream to ${LATEST_SHORT}"
  log "Pushing candidate branch ${BRANCH_NAME}"
  push_branch_with_askpass "$BRANCH_NAME"
else
  log "No file changes after update calculation. Nothing to push."
fi

if [[ "$CREATE_PR" == "true" || "$CREATE_PR" == "1" || "$CREATE_PR" == "yes" ]]; then
  warn "CREATE_PR requested, but automatic PR creation is intentionally not implemented here. Create/review the candidate branch manually."
fi
log "Safe candidate ready: ${BRANCH_NAME}"
