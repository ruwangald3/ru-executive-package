#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# ship.sh — "Ship this to Vercel" — autonomous end-to-end deployment.
#
# Usage:
#   ./system/ship.sh <artifact-root> [--prod] [--project <name>]
#
# Behavior:
#   Phase 1 — VALIDATE   (validate.sh)
#   Phase 2 — PACKAGE    (package.sh)
#   Phase 3 — GIT        (commit + push to GitHub)
#   Phase 4 — DEPLOY     (auto-route based on what is reachable)
#                          (a) sandbox / vercel.com unreachable -> rely on
#                              GitHub -> Vercel auto-deploy + poll
#                          (b) vercel.com reachable + token     -> vercel CLI
#   Phase 5 — RECORD     (write deployment-notes.txt + manifest + log)
#
# Credentials loaded from: system/.env.deploy
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"
ENV_FILE="$SYS_DIR/.env.deploy"

# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# ---- arg parse
ROOT=""; PROJECT=""; PROD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --prod)    PROD="--prod"; shift;;
    -h|--help) sed -n '2,25p' "$0"; exit 0;;
    *) [ -z "$ROOT" ] && ROOT="$1" || { echo "unknown arg: $1" >&2; exit 2; }; shift;;
  esac
done

[ -z "$ROOT" ] && { echo "usage: $0 <artifact-root> [--project name] [--prod]" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "ERROR: $ROOT not a directory" >&2; exit 2; }

ART_ROOT="$(cd "$ROOT" && pwd)"
CASE_DIR="$ART_ROOT"
[[ "$ART_ROOT" == */versions/* ]] && CASE_DIR="${ART_ROOT%/versions/*}"
VERSION_NAME="$(basename "$ART_ROOT")"
CASE_NAME="$(basename "$CASE_DIR")"
[ -z "$PROJECT" ] && PROJECT="${VERCEL_PROJECT_NAME:-$CASE_NAME}"
TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CASE_DIR/deployed" "$CASE_DIR/qa" "$CASE_DIR/pdf"
LOG="$CASE_DIR/deployed/deploy-${VERSION_NAME}-${TS}.log"
NOTES="$CASE_DIR/deployed/deployment-notes.txt"

log(){ printf "%s\n" "$*" | tee -a "$LOG"; }

log "================================================================"
log "  SHIP — $CASE_NAME / $VERSION_NAME"
log "  started: $(date -Iseconds)"
log "================================================================"

# ---- Phase 1
log; log ">>> Phase 1 — VALIDATE"
if ! bash "$SYS_DIR/validate.sh" "$ART_ROOT" >>"$LOG" 2>&1; then
  tail -15 "$LOG"
  log "[ship] validation FAILED — aborting"
  exit 1
fi
log "[ship] validation passed"

# ---- Phase 2
log; log ">>> Phase 2 — PACKAGE"
bash "$SYS_DIR/package.sh" "$ART_ROOT" >>"$LOG" 2>&1
log "[ship] packaged"

# ---- Phase 3 — git commit + push
log; log ">>> Phase 3 — GIT"
cd "$PROJECT_ROOT"
if [ ! -d .git ]; then
  log "[ship] no git repo — initializing"
  git init -q -b main
fi

git add -A
if git diff --cached --quiet; then
  log "[ship] no changes to commit"
else
  git -c user.email="${GITHUB_USERNAME:-deploy}@local" \
      -c user.name="${GITHUB_USERNAME:-deploy}" \
      commit -m "deploy: $CASE_NAME / $VERSION_NAME ($(date -Iseconds))" >>"$LOG" 2>&1 || true
  log "[ship] commit recorded"
fi
COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

PUSHED=no
if [ -n "${GITHUB_REPO:-}" ] && [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_USERNAME:-}" ]; then
  REMOTE_URL="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
  else
    git remote add origin "$REMOTE_URL"
  fi
  BR="${GITHUB_DEFAULT_BRANCH:-main}"
  log "[ship] pushing to github.com/$GITHUB_REPO ($BR)"
  if git push origin "HEAD:$BR" >>"$LOG" 2>&1; then
    PUSHED=yes
    log "[ship] push OK — commit $COMMIT_SHA"
  else
    log "[ship] WARN: git push failed (check GITHUB_TOKEN scopes, repo exists)"
  fi
else
  log "[ship] GitHub credentials not in .env.deploy — skipping push"
fi

# ---- Phase 4 — deploy
log; log ">>> Phase 4 — DEPLOY"

# Detect Vercel reachability
VERCEL_REACHABLE=no
code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://api.vercel.com/v2/user 2>/dev/null || echo 000)
[ "$code" != "000" ] && [ -n "$code" ] && VERCEL_REACHABLE=yes

URL=""

if [ "$VERCEL_REACHABLE" = "yes" ] && [ -n "${VERCEL_TOKEN:-}" ]; then
  log "[ship] vercel.com reachable + token present -> using Vercel CLI"
  VERCEL_BIN="$(command -v vercel || echo npx --yes vercel)"
  cd "$ART_ROOT"
  TEAM_ARG=""
  [ -n "${VERCEL_TEAM:-}" ] && TEAM_ARG="--scope $VERCEL_TEAM"
  # shellcheck disable=SC2086
  $VERCEL_BIN deploy --yes $PROD --token "$VERCEL_TOKEN" $TEAM_ARG --name "$PROJECT" 2>&1 | tee -a "$LOG"
  URL="$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^ ]*' "$LOG" | tail -1)"
elif [ "$PUSHED" = "yes" ]; then
  log "[ship] vercel.com not reachable from here — relying on GitHub->Vercel auto-deploy"
  log "[ship] polling GitHub checks API for $COMMIT_SHA"
  TRIES=60
  while [ $TRIES -gt 0 ]; do
    sleep 5
    resp=$(curl -sS -H "Authorization: token $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github+json" \
                 "https://api.github.com/repos/${GITHUB_REPO}/commits/${COMMIT_SHA}/check-runs?per_page=30" 2>/dev/null)
    vurl=$(echo "$resp" | grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^"]*' | head -1)
    if [ -n "$vurl" ]; then URL="$vurl"; break; fi
    sresp=$(curl -sS -H "Authorization: token $GITHUB_TOKEN" \
                 "https://api.github.com/repos/${GITHUB_REPO}/statuses/${COMMIT_SHA}" 2>/dev/null)
    vurl=$(echo "$sresp" | grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^"]*' | head -1)
    if [ -n "$vurl" ]; then URL="$vurl"; break; fi
    TRIES=$((TRIES-1))
    [ $((TRIES % 6)) -eq 0 ] && log "[ship] waiting for Vercel deployment URL... ($((TRIES*5))s remaining)"
  done
  if [ -z "$URL" ]; then
    log "[ship] WARN: did not capture Vercel URL within 5 min"
    log "[ship]       check Vercel dashboard: https://vercel.com/dashboard"
    log "[ship]       (one-time setup: vercel.com -> Add New Project -> import this repo)"
  else
    log "[ship] captured Vercel URL via GitHub check"
  fi
else
  log "[ship] BLOCKED: vercel.com unreachable AND no GitHub push completed"
  log "[ship]   remediation: fill system/.env.deploy with GITHUB_* values and rerun"
fi

# ---- Phase 5 — record
log; log ">>> Phase 5 — RECORD"
{
  echo "DEPLOYMENT NOTES"
  echo "================"
  echo "artifact:    $CASE_NAME"
  echo "version:     $VERSION_NAME"
  echo "project:     $PROJECT"
  echo "commit:      $COMMIT_SHA"
  echo "pushed:      $PUSHED"
  echo "deployed:    $(date -Iseconds)"
  echo "url:         ${URL:-NOT-CAPTURED}"
  echo "log:         $LOG"
  echo
  echo "Production:  ${URL:-not-deployed}"
  echo "Mobile QA:   ${URL:-N/A}"
} > "$NOTES"
log "[ship] notes -> $NOTES"

[ -n "$URL" ] && log "[ship] LIVE URL: $URL"
[ -n "$URL" ] && exit 0 || exit 1
