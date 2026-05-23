#!/usr/bin/env bash
set -euo pipefail

ADDON_DIR="${ADDON_DIR:-teamspeak6}"
GH_REPO="${GH_REPO:-teamspeak/teamspeak6-server}"
CODEBERG_API="${CODEBERG_API:-https://codeberg.org/api/v1}"
CODEBERG_REPO="${CODEBERG_REPO:-Pol4rFuchs/teamspeak6-ha-app}"
BASE_BRANCH="${BASE_BRANCH:-main}"
UPDATE_MODE="${UPDATE_MODE:-candidate}"        # candidate | local
CREATE_RELEASE="${CREATE_RELEASE:-false}"     # intentionally blocked for safe HA updates
CREATE_PR="${CREATE_PR:-false}"               # optional; branch creation is the hard safety boundary
TARGET_TS6_VERSION="${TARGET_TS6_VERSION:-}"
VALIDATE_DOCKER="${VALIDATE_DOCKER:-auto}"
INCLUDE_PRERELEASES="${INCLUDE_PRERELEASES:-true}"

BUILD_YAML="${ADDON_DIR}/build.yaml"
DOCKERFILE="${ADDON_DIR}/Dockerfile"
CONFIG_YAML="${ADDON_DIR}/config.yaml"
CHANGELOG="${ADDON_DIR}/CHANGELOG.md"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

normalize_ts6_version() {
  # TeamSpeak used both raw tags like "v6.0.0/beta8" and newer tags like
  # "v6.0.0-beta9". Docker images and the HA add-on use the dash form.
  local raw="$1"
  raw="${raw#v}"
  raw="${raw//\//-}"
  printf '%s' "$raw"
}

is_supported_ts6_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._-]+)?$ ]]
}

semver_key() {
  local v="$1"
  local major minor patch pre weight num
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([A-Za-z0-9._-]+))?$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    pre="${BASH_REMATCH[5]:-}"
    if [[ -z "$pre" ]]; then
      weight=999999
    elif [[ "$pre" =~ ^alpha([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
      weight=$((100000 + 10#$num))
    elif [[ "$pre" =~ ^beta([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
      weight=$((200000 + 10#$num))
    elif [[ "$pre" =~ ^rc([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
      weight=$((300000 + 10#$num))
    else
      weight=1
    fi
    printf '%06d.%06d.%06d.%06d' "$major" "$minor" "$patch" "$weight"
    return 0
  fi
  return 1
}

release_url_for_tag() {
  local tag="$1"
  local encoded
  encoded="$(jq -nr --arg s "$tag" '$s|@uri')"
  printf 'https://github.com/%s/releases/tag/%s' "$GH_REPO" "$encoded"
}

need_cmd curl
need_cmd jq
need_cmd yq
need_cmd git
need_cmd sort
need_cmd cut
need_cmd awk

read_docker_arg() {
  local key="$1" file="$2"
  awk -v key="$key" '
    $1 == "ARG" {
      line=$0
      sub(/^ARG[[:space:]]+/, "", line)
      split(line, parts, "=")
      if (parts[1] == key) {
        sub("^[^=]*=", "", line)
        gsub(/^"/, "", line); gsub(/"$/, "", line)
        gsub(/^\047/, "", line); gsub(/\047$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

set_docker_arg() {
  local key="$1" value="$2" file="$3"
  if grep -Eq "^ARG[[:space:]]+${key}=" "$file"; then
    sed -i -E "s#^ARG[[:space:]]+${key}=.*#ARG ${key}=${value}#" "$file"
  else
    fail "Dockerfile has no ARG ${key}=... line to update"
  fi
}

setup_git_askpass() {
  ASKPASS_FILE="$(mktemp)"
  cat > "$ASKPASS_FILE" <<'ASKPASS'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s
' "forgejo-actions" ;;
  *Password*) printf '%s
' "$CODEBERG_TOKEN" ;;
  *) printf '
' ;;
esac
ASKPASS
  chmod 700 "$ASKPASS_FILE"
  export GIT_ASKPASS="$ASKPASS_FILE"
  export GIT_TERMINAL_PROMPT=0
}

cleanup() {
  [[ -n "${ASKPASS_FILE:-}" && -f "${ASKPASS_FILE:-}" ]] && rm -f "$ASKPASS_FILE"
}
trap cleanup EXIT

push_branch_with_askpass() {
  local branch="$1" remote remote_sha
  [[ -n "${CODEBERG_TOKEN:-}" ]] || fail "CODEBERG_TOKEN secret is required to push the candidate branch"
  remote="https://codeberg.org/${CODEBERG_REPO}.git"
  setup_git_askpass
  remote_sha="$(CODEBERG_TOKEN="$CODEBERG_TOKEN" git ls-remote --heads "$remote" "$branch" | awk '{print $1}' || true)"
  if [[ -n "$remote_sha" ]]; then
    log "Remote candidate branch already exists at ${remote_sha}; updating it with explicit --force-with-lease"
    CODEBERG_TOKEN="$CODEBERG_TOKEN" git push --force-with-lease="refs/heads/${branch}:${remote_sha}" "$remote" "HEAD:refs/heads/${branch}"
  else
    log "Remote candidate branch does not exist yet; creating it"
    CODEBERG_TOKEN="$CODEBERG_TOKEN" git push "$remote" "HEAD:refs/heads/${branch}"
  fi
}

[[ -f "$CONFIG_YAML" ]] || fail "Missing $CONFIG_YAML"
[[ -f "$DOCKERFILE" ]] || fail "Missing $DOCKERFILE"
[[ -f "$CHANGELOG" ]] || fail "Missing $CHANGELOG"
if [[ -f "$BUILD_YAML" ]]; then
  warn "$BUILD_YAML exists but is deprecated. Remove it; this updater uses Dockerfile ARG metadata."
fi

log "TS6 safe updater v10: build.yaml-free Dockerfile ARG candidate flow, slash-tag aware, remote-branch-safe push"

if [[ -n "$TARGET_TS6_VERSION" ]]; then
  LATEST_TAG="${TARGET_TS6_VERSION}"
  LATEST_VERSION="$(normalize_ts6_version "$TARGET_TS6_VERSION")"
  LATEST_NAME="${LATEST_TAG}"
  LATEST_BODY="Manual target version from TARGET_TS6_VERSION=${TARGET_TS6_VERSION}."
  LATEST_DATE="$(date -u +%Y-%m-%d)"
else
  log "Fetching TeamSpeak 6 server releases from github.com/${GH_REPO}"
  RELEASES_JSON="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GH_REPO}/releases?per_page=100")"

  if [[ "$(printf '%s\n' "$RELEASES_JSON" | jq -r 'type')" != "array" ]]; then
    warn "GitHub releases endpoint did not return an array. Falling back to tags."
    warn "Response excerpt: $(printf '%s' "$RELEASES_JSON" | jq -c '.' 2>/dev/null | cut -c1-240)"
    RELEASES_JSON='[]'
  fi

  TMP_CANDIDATES="$(mktemp)"
  while IFS=$'\t' read -r tag prerelease draft published name; do
    [[ -n "$tag" && "$tag" != "null" ]] || continue
    [[ "$draft" != "true" ]] || continue
    if [[ !( "$INCLUDE_PRERELEASES" == "true" || "$INCLUDE_PRERELEASES" == "1" || "$INCLUDE_PRERELEASES" == "yes" ) && "$prerelease" == "true" ]]; then
      continue
    fi

    normalized="$(normalize_ts6_version "$tag")"
    if ! is_supported_ts6_version "$normalized"; then
      warn "Skipping upstream release with unsupported tag format: '${tag}' -> '${normalized}'"
      continue
    fi
    key="$(semver_key "$normalized")" || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$key" "$normalized" "$tag" "$published" "$name" >> "$TMP_CANDIDATES"
  done < <(echo "$RELEASES_JSON" | jq -r '.[] | [.tag_name, (.prerelease|tostring), (.draft|tostring), (.published_at // ""), (.name // .tag_name)] | @tsv')

  # Fallback: some GitHub repos have unusual release metadata. Tags are still
  # a safe source for version discovery, but they do not include release notes.
  if [[ ! -s "$TMP_CANDIDATES" ]]; then
    warn "No usable GitHub releases found. Falling back to repository tags."
    TAGS_JSON="$(curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GH_REPO}/tags?per_page=100")"
    while IFS=$'\t' read -r tag; do
      [[ -n "$tag" && "$tag" != "null" ]] || continue
      normalized="$(normalize_ts6_version "$tag")"
      if ! is_supported_ts6_version "$normalized"; then
        warn "Skipping upstream tag with unsupported format: '${tag}' -> '${normalized}'"
        continue
      fi
      key="$(semver_key "$normalized")" || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$key" "$normalized" "$tag" "" "$tag" >> "$TMP_CANDIDATES"
    done < <(echo "$TAGS_JSON" | jq -r '.[] | [.name] | @tsv')
  fi

  [[ -s "$TMP_CANDIDATES" ]] || fail "No usable upstream release/tag found for ${GH_REPO}"
  SELECTED_LINE="$(sort -t $'\t' -k1,1 "$TMP_CANDIDATES" | tail -n 1)"
  rm -f "$TMP_CANDIDATES"

  LATEST_KEY="$(cut -f1 <<< "$SELECTED_LINE")"
  LATEST_VERSION="$(cut -f2 <<< "$SELECTED_LINE")"
  LATEST_TAG="$(cut -f3 <<< "$SELECTED_LINE")"
  LATEST_DATE="$(cut -f4 <<< "$SELECTED_LINE" | cut -d'T' -f1)"
  LATEST_NAME="$(cut -f5 <<< "$SELECTED_LINE")"
  # jq pitfall fixed in v4:
  #   `.[] | select(...) | first` applies `first` to the selected object and fails with
  #   "Cannot index object with number". We first collect matches, then take the first item.
  LATEST_JSON="$(printf '%s\n' "$RELEASES_JSON" | jq -c --arg tag "$LATEST_TAG" '[.[] | select(.tag_name == $tag)] | first // empty')"
  if [[ -n "$LATEST_JSON" && "$LATEST_JSON" != "null" ]]; then
    LATEST_NAME="$(echo "$LATEST_JSON" | jq -r '.name // .tag_name')"
    LATEST_BODY="$(echo "$LATEST_JSON" | jq -r '.body // ""')"
  else
    LATEST_BODY="No GitHub release body available for selected tag ${LATEST_TAG}."
  fi
fi

is_supported_ts6_version "$LATEST_VERSION" \
  || fail "Invalid latest TeamSpeak 6 version/tag after normalization: raw='${LATEST_TAG}', normalized='${LATEST_VERSION}'"
LATEST_KEY="$(semver_key "$LATEST_VERSION")" || fail "Could not create sort key for version '${LATEST_VERSION}'"
LATEST_RELEASE_URL="$(release_url_for_tag "$LATEST_TAG")"
log "Upstream selected: ${LATEST_VERSION} (raw tag: ${LATEST_TAG})"

CURRENT_VERSION="$(normalize_ts6_version "$(read_docker_arg TEAMSPEAK_VERSION "$DOCKERFILE")")"
log "Current build version: '${CURRENT_VERSION}'"
CURRENT_KEY="$(semver_key "$CURRENT_VERSION")" || fail "Could not create sort key for current version '${CURRENT_VERSION}'"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  log "Already up-to-date. Nothing to do."
  exit 0
fi
if [[ "$CURRENT_KEY" > "$LATEST_KEY" ]]; then
  warn "Current TeamSpeak version '${CURRENT_VERSION}' is newer than selected upstream '${LATEST_VERSION}'. Refusing to downgrade."
  exit 0
fi

SAFE_BRANCH_VERSION="$(printf '%s' "$LATEST_VERSION" | sed -E 's/[^A-Za-z0-9._-]+/-/g')"

if [[ "$UPDATE_MODE" == "candidate" ]]; then
  : "${CODEBERG_TOKEN:?CODEBERG_TOKEN must be set for candidate mode}"
  CANDIDATE_BRANCH="${CANDIDATE_BRANCH:-auto/ts6-v${SAFE_BRANCH_VERSION}}"

  REMOTE_URL="https://codeberg.org/${CODEBERG_REPO}.git"
  setup_git_askpass
  log "Preparing safe candidate branch: ${CANDIDATE_BRANCH} from ${BASE_BRANCH}"
  CODEBERG_TOKEN="$CODEBERG_TOKEN" git fetch "$REMOTE_URL" "${BASE_BRANCH}" --depth=50 || CODEBERG_TOKEN="$CODEBERG_TOKEN" git fetch "$REMOTE_URL" "${BASE_BRANCH}"
  git checkout -B "${CANDIDATE_BRANCH}" FETCH_HEAD
elif [[ "$UPDATE_MODE" == "local" ]]; then
  CANDIDATE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo local)"
  log "Local mode: modifying current branch '${CANDIDATE_BRANCH}' without push"
else
  fail "Unsupported UPDATE_MODE='${UPDATE_MODE}'. Use candidate or local."
fi

log "New version detected: ${CURRENT_VERSION:-<none>} -> ${LATEST_VERSION}"
set_docker_arg TEAMSPEAK_VERSION "$LATEST_VERSION" "$DOCKERFILE"

ADDON_VERSION="$(yq -r '.version' "$CONFIG_YAML")"
IFS='.' read -r -a VERSION_PARTS <<< "$ADDON_VERSION"
if (( ${#VERSION_PARTS[@]} < 3 )); then
  fail "Unsupported add-on version format: ${ADDON_VERSION}"
fi
LAST_INDEX=$((${#VERSION_PARTS[@]} - 1))
VERSION_PARTS[$LAST_INDEX]="$(( VERSION_PARTS[$LAST_INDEX] + 1 ))"
NEW_ADDON_VERSION="$(IFS='.'; echo "${VERSION_PARTS[*]}")"
log "Addon version: ${ADDON_VERSION} -> ${NEW_ADDON_VERSION}"
NEW_ADDON_VERSION="$NEW_ADDON_VERSION" yq -i '.version = strenv(NEW_ADDON_VERSION)' "$CONFIG_YAML"

TODAY="$(date -u +%Y-%m-%d)"
TMP="$(mktemp)"
{
  echo "## ${NEW_ADDON_VERSION} — ${TODAY} (TeamSpeak 6 Server ${LATEST_VERSION})"
  echo
  echo "- Candidate update to TeamSpeak 6 Server \`${LATEST_VERSION}\`."
  echo "- Upstream release: [${LATEST_NAME}](${LATEST_RELEASE_URL})"
  echo "- Safety: this version is generated on branch \`${CANDIDATE_BRANCH}\` first. Home Assistant does not see it until merged into \`${BASE_BRANCH}\`."
  echo
  cat "$CHANGELOG"
} > "$TMP"
mv "$TMP" "$CHANGELOG"

log "Running validation before any push"
ADDON_DIR="$ADDON_DIR" VALIDATE_DOCKER="$VALIDATE_DOCKER" bash scripts/validate-addon.sh

git config user.name "Forgejo Actions Bot"
git config user.email "actions@noreply.codeberg.org"

git add "$DOCKERFILE" "$CONFIG_YAML" "$CHANGELOG"
if git diff --cached --quiet; then
  log "No committed changes after validation. Nothing to push."
  exit 0
fi

git commit -m "chore(ts6): candidate bump to TeamSpeak 6 Server ${LATEST_VERSION}

Generated by safe Forgejo auto-update.
Branch-only candidate: ${CANDIDATE_BRANCH}
Upstream: ${LATEST_RELEASE_URL}"

if [[ "$UPDATE_MODE" == "local" ]]; then
  log "Local mode complete. Review and commit/push manually."
  exit 0
fi

log "Pushing candidate branch only: ${CANDIDATE_BRANCH}"
push_branch_with_askpass "$CANDIDATE_BRANCH"

BRANCH_URL="https://codeberg.org/${CODEBERG_REPO}/src/branch/${CANDIDATE_BRANCH}"
log "Candidate branch ready: ${BRANCH_URL}"

if [[ "$CREATE_PR" == "true" || "$CREATE_PR" == "1" || "$CREATE_PR" == "yes" ]]; then
  log "CREATE_PR enabled — creating pull request if possible"
  PR_BODY="$(jq -n \
    --arg head "$CANDIDATE_BRANCH" \
    --arg base "$BASE_BRANCH" \
    --arg title "chore(ts6): bump to TeamSpeak 6 Server ${LATEST_VERSION}" \
    --arg body "Safe auto-update candidate for TeamSpeak 6 Server ${LATEST_VERSION}. Validation ran before branch push. Merge only after review/testing with a Home Assistant backup available." \
    '{head: $head, base: $base, title: $title, body: $body}')"

  if ! curl -fsSL -X POST \
    -H "Authorization: token ${CODEBERG_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PR_BODY" \
    "${CODEBERG_API}/repos/${CODEBERG_REPO}/pulls" >/dev/null; then
    warn "Pull request creation failed or already exists. Candidate branch is still available: ${BRANCH_URL}"
  fi
fi

if [[ "$CREATE_RELEASE" == "true" || "$CREATE_RELEASE" == "1" || "$CREATE_RELEASE" == "yes" ]]; then
  fail "CREATE_RELEASE is intentionally blocked in safe mode. Create releases only after merge to ${BASE_BRANCH}."
fi

log "Done — no main push, no release, no HA-visible update until manual merge."
