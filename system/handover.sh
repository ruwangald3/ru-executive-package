#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# handover.sh — Executive Session Handover Protocol
#
# Generates a token-efficient continuation summary so a fresh Claude session
# can pick up exactly where the prior session left off.
#
# Usage:
#   ./system/handover.sh              # print full doc to stdout
#   ./system/handover.sh --write      # also write to system/handover/latest.md
#   ./system/handover.sh --terse      # one-paragraph boot prompt only
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"
ENV_FILE="$SYS_DIR/.env.deploy"

WRITE=no; TERSE=no
for a in "$@"; do
  [ "$a" = "--write" ] && WRITE=yes
  [ "$a" = "--terse" ] && TERSE=yes
done

# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# Mirror ship.sh's case-folder exclusion list (deprecated / archived folders)
should_skip_case() {
  case "$1" in
    _archive-*|sivers-executive-packet-v1) return 0;;
    *) return 1;;
  esac
}

TS="$(date -Iseconds)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Find latest commit (prefer staging fallback for mount-blocked git)
COMMIT=""
if git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  COMMIT="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
fi
if [ -z "$COMMIT" ]; then
  for d in /tmp/*-staging; do
    [ -d "$d/.git" ] || continue
    sha="$(git -C "$d" rev-parse HEAD 2>/dev/null)"
    [ -n "$sha" ] && COMMIT="$sha" && break
  done
fi

CREDS="missing"
if [ -f "$ENV_FILE" ]; then
  grep -q '^GITHUB_TOKEN=github_pat' "$ENV_FILE" 2>/dev/null && CREDS="github-pat ok"
  if grep -qE '^VERCEL_TOKEN=.+$' "$ENV_FILE" 2>/dev/null; then
    CREDS="$CREDS, vercel-token ok"
  fi
fi

SKILLS=()
for s in "$SYS_DIR"/*.sh; do
  [ -f "$s" ] && SKILLS+=("$(basename "$s")")
done

# Accumulate strings with real newlines (avoids printf \n parsing issues)
NL=$'\n'
ART_LINES=""
DEPLOY_LINES=""
BLOCKER_LINES=""
ACTIVE_CASES=""

for case in "$PROJECT_ROOT/artifacts/"*/; do
  [ -d "$case" ] || continue
  cname="$(basename "$case")"
  should_skip_case "$cname" && continue
  ACTIVE_CASES="${ACTIVE_CASES}${cname},"

  versions=""
  if [ -d "$case/versions" ]; then
    for v in "$case/versions/"*/; do
      [ -d "$v" ] || continue
      vname="$(basename "$v")"
      case "$vname" in _archive-*) continue;; esac
      versions="$versions $vname"
    done
  fi
  versions="$(echo "$versions" | sed 's/^ //;s/ /, /g')"
  [ -z "$versions" ] && versions="(none)"
  ART_LINES="${ART_LINES}| ${cname} | ${versions} |${NL}"

  notes="$case/deployed/deployment-notes.txt"
  if [ -f "$notes" ]; then
    url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^[:space:]]*' "$notes" | head -1)
    commit_short=$(grep -oE 'commit:[[:space:]]+[a-f0-9]+' "$notes" | head -1 | awk '{print $2}' | cut -c1-7)
    if [ -n "$url" ]; then
      DEPLOY_LINES="${DEPLOY_LINES}- **${cname}** → ${url} (commit ${commit_short:-?})${NL}"
    fi
    if grep -qE 'BLOCKED|DEPLOYMENT_NOT_FOUND|404|cannot be found' "$notes" 2>/dev/null; then
      reason=$(grep -E 'BLOCKED|DEPLOYMENT_NOT_FOUND|404|cannot be found' "$notes" | head -1 | sed 's/^[[:space:]]*//')
      BLOCKER_LINES="${BLOCKER_LINES}- **${cname}**: ${reason}${NL}"
    fi
  fi
done
ACTIVE_CASES="${ACTIVE_CASES%,}"
[ -z "$ART_LINES" ]      && ART_LINES="| _(no active artifacts)_ | — |${NL}"
[ -z "$DEPLOY_LINES" ]   && DEPLOY_LINES="_no deployments recorded yet_${NL}"
HAVE_BLOCKERS=no
if [ -n "$BLOCKER_LINES" ]; then
  HAVE_BLOCKERS=yes
else
  BLOCKER_LINES="_none detected_${NL}"
fi

# Next actions
if [ "$HAVE_BLOCKERS" = "yes" ]; then
  NEXT_LINES="1. Resolve blockers above (most common: complete one-time vercel.com/new project link)${NL}2. Re-run ./system/ship.sh <artifact-root> --prod to retrigger auto-deploy${NL}3. Verify live URL in browser${NL}"
  BOOT_NEXT="verify deployment status and resolve any 404s"
else
  NEXT_LINES="1. Pick an artifact under artifacts/ to iterate on${NL}2. Run ./system/ship.sh artifacts/<case>/versions/<version> --prod${NL}3. Use ./system/archive.sh before major layout edits${NL}"
  BOOT_NEXT="await user instruction"
fi

# ---- emit ----
SHORT_SHA="${COMMIT:0:7}"

if [ "$TERSE" = "yes" ]; then
  OUT="RESUME [OPS] Executive Artifact Deployment System
ts:${TS} commit:${SHORT_SHA} creds:${CREDS}
artifacts:${ACTIVE_CASES}
skills:$(IFS=,; echo "${SKILLS[*]}")
status:$([ "$HAVE_BLOCKERS" = "yes" ] && echo BLOCKED || echo OK)
read: system/handover/latest.md"
else
  OUT="# Executive Session Handover — ${PROJECT_NAME}
generated: ${TS}

## Project state (one line)
[OPS] Executive Artifact Deployment System — autonomous Cowork → GitHub → Vercel pipeline for HTML executive artifacts. Single-command shipping via \`./system/ship.sh\`.

## Active artifacts
| Case folder | Versions |
|-------------|----------|
${ART_LINES}
## Deployment status
${DEPLOY_LINES}
## Repo + commit
- GitHub: ${GITHUB_REPO:+https://github.com/${GITHUB_REPO}}
- Branch: ${GITHUB_DEFAULT_BRANCH:-main}
- HEAD: ${SHORT_SHA}${COMMIT:+ (${COMMIT})}

## Credentials state
- system/.env.deploy: ${CREDS}

## Reusable skills (system/)
$(for s in "${SKILLS[@]}"; do echo "- $s"; done)

## Blockers / dependencies
${BLOCKER_LINES}
## Immediate next actions
${NEXT_LINES}
## Boot prompt for next session
Paste this as the first message in a fresh Cowork session:

\`\`\`
Resume the [OPS] Executive Artifact Deployment System project.
Read system/handover/latest.md for full state.
HEAD commit: ${SHORT_SHA}
Active artifacts: ${ACTIVE_CASES}
Next action: ${BOOT_NEXT}
\`\`\`
"
fi

printf '%s\n' "$OUT"

if [ "$WRITE" = "yes" ]; then
  HV_DIR="$SYS_DIR/handover"
  mkdir -p "$HV_DIR"
  printf '%s\n' "$OUT" > "$HV_DIR/latest.md"
  cp "$HV_DIR/latest.md" "$HV_DIR/$(date +%Y%m%d-%H%M%S).md"
  echo
  echo "[handover] wrote: $HV_DIR/latest.md"
fi
