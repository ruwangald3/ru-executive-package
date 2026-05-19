#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# ship.sh — "Ship this to Vercel" — autonomous end-to-end deployment.
#
# Usage:
#   ./system/ship.sh <artifact-root> [--prod] [--project <name>]
#
# Phases:
#   1. VALIDATE  — validate.sh: file structure, asset 200s, responsive heuristics
#   2. PACKAGE   — package.sh: vercel.json, README, manifest
#   3. GIT       — commit + push to GitHub (uses /tmp staging if mount blocks .git)
#   4. DEPLOY    — Vercel CLI if reachable, else rely on GitHub→Vercel auto-deploy
#   5. RECORD    — deployment-notes.txt with commit SHA + likely URL
#
# Credentials: system/.env.deploy
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"
ENV_FILE="$SYS_DIR/.env.deploy"

# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

ROOT=""; PROJECT=""; PROD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --prod)    PROD="--prod"; shift;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
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

# Resolve the relative path from PROJECT_ROOT to ART_ROOT (used for Vercel Root Directory)
REL_ART_PATH="${ART_ROOT#$PROJECT_ROOT/}"

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

# ---- Phase 3 — git (auto-stage if mount blocks .git)
log; log ">>> Phase 3 — GIT"

# Detect if the project root mount can host a .git directory.
# The FUSE-style mount used by Cowork blocks .git/config.lock writes,
# which breaks `git init`. If so, we fall back to /tmp staging.
USE_STAGING=no
if [ -d "$PROJECT_ROOT/.git" ] && git -C "$PROJECT_ROOT" status >/dev/null 2>&1; then
  log "[ship] project-root .git is healthy — using it"
  WORK_DIR="$PROJECT_ROOT"
elif ( cd "$PROJECT_ROOT" && git init -q -b main 2>/dev/null && \
       git config user.email "${GITHUB_USERNAME:-deploy}@local" 2>/dev/null && \
       git config user.name  "${GITHUB_USERNAME:-deploy}" 2>/dev/null ); then
  log "[ship] initialized .git at project root"
  WORK_DIR="$PROJECT_ROOT"
else
  log "[ship] mount blocks .git — using /tmp staging workspace"
  USE_STAGING=yes
  STAGE_ROOT="${SHIP_STAGE_DIR:-/tmp/$CASE_NAME-staging}"
  BR="${GITHUB_DEFAULT_BRANCH:-main}"
  if [ ! -d "$STAGE_ROOT/.git" ]; then
    rm -rf "$STAGE_ROOT"
    # Prefer clone (so we inherit existing remote history); fall back to init.
    if [ -n "${GITHUB_REPO:-}" ] && [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_USERNAME:-}" ]; then
      CLONE_URL="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
      if GIT_TERMINAL_PROMPT=0 git clone -q --branch "$BR" "$CLONE_URL" "$STAGE_ROOT" 2>/dev/null; then
        log "[ship] cloned existing repo into staging: $STAGE_ROOT"
      else
        log "[ship] clone failed (empty repo?) — initializing fresh"
        mkdir -p "$STAGE_ROOT"
        git -C "$STAGE_ROOT" init -q -b "$BR"
      fi
    else
      mkdir -p "$STAGE_ROOT"
      git -C "$STAGE_ROOT" init -q -b "$BR"
    fi
    git -C "$STAGE_ROOT" config user.email "${GITHUB_USERNAME:-deploy}@local"
    git -C "$STAGE_ROOT" config user.name  "${GITHUB_USERNAME:-deploy}"
  else
    log "[ship] reusing staging workspace — fetching latest from origin"
    GIT_TERMINAL_PROMPT=0 git -C "$STAGE_ROOT" fetch origin "$BR" 2>/dev/null && \
      git -C "$STAGE_ROOT" reset --hard "origin/$BR" 2>/dev/null || \
      log "[ship] (fetch skipped — proceeding with cached state)"
  fi
  log "[ship] syncing project -> staging"
  rsync -a --delete \
    --exclude='.git' \
    --exclude='system/.env.deploy' \
    --exclude='artifacts/_archive-*' \
    --exclude='artifacts/sivers-executive-packet-v1' \
    --exclude='**/_archive-*' \
    --exclude='**/*.log' \
    --exclude='**/.DS_Store' \
    --exclude='**/Thumbs.db' \
    "$PROJECT_ROOT/" "$STAGE_ROOT/"
  # Ensure .gitignore lives at staging root
  [ ! -f "$STAGE_ROOT/.gitignore" ] && [ -f "$PROJECT_ROOT/.gitignore" ] && \
    cp "$PROJECT_ROOT/.gitignore" "$STAGE_ROOT/.gitignore"
  WORK_DIR="$STAGE_ROOT"
fi

cd "$WORK_DIR"
git add -A
COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo)"
if git diff --cached --quiet 2>/dev/null; then
  log "[ship] no changes to commit (HEAD = ${COMMIT_SHA:-none})"
else
  git commit -q -m "deploy: $CASE_NAME / $VERSION_NAME ($(date -Iseconds))" >>"$LOG" 2>&1 || true
  COMMIT_SHA="$(git rev-parse HEAD)"
  log "[ship] commit recorded: ${COMMIT_SHA:0:7}"
fi

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
  if GIT_TERMINAL_PROMPT=0 git push origin "HEAD:$BR" >>"$LOG" 2>&1; then
    PUSHED=yes
    log "[ship] push OK — commit ${COMMIT_SHA:0:7}"
  else
    log "[ship] WARN: git push failed (check GITHUB_TOKEN scopes, repo exists)"
  fi
else
  log "[ship] GitHub credentials missing in .env.deploy — skipping push"
fi

# ---- Phase 4 — Deploy
log; log ">>> Phase 4 — DEPLOY"

# Check Vercel reachability
VERCEL_REACHABLE=no
code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://api.vercel.com/v2/user 2>/dev/null || echo 000)
[ "$code" != "000" ] && [ -n "$code" ] && VERCEL_REACHABLE=yes

URL=""
DEPLOY_MODE="none"

if [ "$VERCEL_REACHABLE" = "yes" ] && [ -n "${VERCEL_TOKEN:-}" ]; then
  DEPLOY_MODE="vercel-cli"
  log "[ship] vercel.com reachable + token present -> Vercel CLI direct"
  VBIN="$(command -v vercel || echo "npx --yes vercel")"
  cd "$ART_ROOT"
  TEAM_ARG=""
  [ -n "${VERCEL_TEAM:-}" ] && TEAM_ARG="--scope $VERCEL_TEAM"
  # shellcheck disable=SC2086
  $VBIN deploy --yes $PROD --token "$VERCEL_TOKEN" $TEAM_ARG --name "$PROJECT" 2>&1 | tee -a "$LOG"
  URL="$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^ ]*' "$LOG" | tail -1)"
elif [ "$PUSHED" = "yes" ]; then
  DEPLOY_MODE="github-webhook"
  log "[ship] vercel.com not reachable — relying on GitHub->Vercel webhook"
  # Try to poll api.github.com for the Vercel deployment URL (often blocked, but cheap to try)
  TRIES=12
  while [ $TRIES -gt 0 ]; do
    sleep 5
    resp=$(curl -sS --connect-timeout 3 --max-time 8 \
              -H "Authorization: token $GITHUB_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/repos/${GITHUB_REPO}/commits/${COMMIT_SHA}/check-runs?per_page=30" 2>/dev/null)
    vurl=$(echo "$resp" | grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app[^"]*' | head -1)
    if [ -n "$vurl" ]; then URL="$vurl"; break; fi
    TRIES=$((TRIES-1))
  done
  [ -z "$URL" ] && log "[ship] could not poll Vercel URL (api.github.com likely blocked)"
  [ -z "$URL" ] && URL="https://${PROJECT}.vercel.app"  # best-guess primary alias
  [ -z "$URL" ] || log "[ship] presumed URL: $URL (verify in browser)"
else
  log "[ship] BLOCKED: vercel.com unreachable AND no GitHub push completed"
fi

# ---- Phase 5 — record
log; log ">>> Phase 5 — RECORD"
{
  echo "DEPLOYMENT NOTES — $CASE_NAME / $VERSION_NAME"
  echo "================================================================"
  echo 