#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# ship-cmd.sh — /ship <slug> — fully autonomous publish pipeline.
#
# Pipeline:
#   1. Resolve slug -> artifacts/<slug>/versions/<latest-non-archive>/
#   2. Validate + package + commit + push (via ship.sh)
#   3. Poll GitHub for the Action's deploy-URL commit (up to 3 min)
#   4. Read artifacts/<slug>/deployed/url.txt
#   5. Update local deployment-notes.txt with the URL
#   6. Return the live URL
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"
ENV_FILE="$SYS_DIR/.env.deploy"
# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

SLUG=""; VERSION=""; PROD=""; PROJECT=""; NO_WAIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2;;
    --prod)     PROD="--prod"; shift;;
    --project)  PROJECT="--project $2"; shift 2;;
    --no-wait)  NO_WAIT=yes; shift;;
    -h|--help)  sed -n '2,12p' "$0"; exit 0;;
    *) [ -z "$SLUG" ] && SLUG="$1" || { echo "unknown arg: $1" >&2; exit 2; }; shift;;
  esac
done

[ -z "$SLUG" ] && { echo "usage: $0 <artifact-slug> [--version <v>] [--prod] [--no-wait]" >&2; exit 2; }
SLUG="${SLUG#/}"

CASE_DIR="$PROJECT_ROOT/artifacts/$SLUG"
if [ ! -d "$CASE_DIR" ]; then
  echo "ERROR: artifact '$SLUG' not found at: $CASE_DIR" >&2
  echo "Available artifacts:" >&2
  for d in "$PROJECT_ROOT/artifacts/"*/; do
    [ -d "$d" ] || continue
    bn="$(basename "$d")"
    case "$bn" in _archive-*|sivers-executive-packet-v1) continue;; esac
    echo "  - $bn" >&2
  done
  exit 2
fi

VERSIONS_DIR="$CASE_DIR/versions"
[ -d "$VERSIONS_DIR" ] || { echo "ERROR: $VERSIONS_DIR does not exist" >&2; exit 2; }

if [ -n "$VERSION" ]; then
  TARGET="$VERSIONS_DIR/$VERSION"
  [ -d "$TARGET" ] || { echo "ERROR: version '$VERSION' not found at $TARGET" >&2; exit 2; }
else
  TARGET=""
  while IFS= read -r v; do
    bn="$(basename "$v")"
    case "$bn" in _archive-*) continue;; esac
    TARGET="$v"; break
  done < <(find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\n" 2>/dev/null | sort -nr | awk '{$1=""; sub(/^ /,""); print}')
  [ -z "$TARGET" ] && { echo "ERROR: no deployable versions under $VERSIONS_DIR" >&2; exit 2; }
fi

REL_TARGET="$(realpath --relative-to="$PROJECT_ROOT" "$TARGET")"
VERSION_NAME="$(basename "$TARGET")"
echo "[ship] artifact: $SLUG"
echo "[ship] version : $VERSION_NAME"
echo "[ship] target  : $REL_TARGET"
echo

# Run the main ship pipeline (validate + commit + push)
bash "$SYS_DIR/ship.sh" "$TARGET" $PROD $PROJECT
RC=$?
[ $RC -ne 0 ] && exit $RC

if [ "$NO_WAIT" = "yes" ]; then
  echo "[ship] --no-wait set; skipping URL poll"
  exit 0
fi

# ---- Poll the GitHub repo for the Action's URL commit ----
echo
echo "[ship] waiting for GitHub Action to deploy + commit URL back..."
echo "[ship] (poll: fetch origin/main looking for artifacts/$SLUG/deployed/url.txt)"

STAGE_ROOT="${SHIP_STAGE_DIR:-/tmp/$SLUG-staging}"
[ -d "$STAGE_ROOT/.git" ] || STAGE_ROOT="/tmp/$(basename "$PROJECT_ROOT" | tr ' ' '-')-staging"

URL=""
START=$(date +%s)
DEADLINE=$((START + 180))   # 3-minute budget

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  sleep 10
  if [ -d "$STAGE_ROOT/.git" ]; then
    GIT_TERMINAL_PROMPT=0 git -C "$STAGE_ROOT" fetch -q origin main 2>/dev/null || true
    GIT_TERMINAL_PROMPT=0 git -C "$STAGE_ROOT" reset --hard -q origin/main 2>/dev/null || true
    url_file="$STAGE_ROOT/artifacts/$SLUG/deployed/url.txt"
    if [ -f "$url_file" ]; then
      candidate="$(tr -d '\n' < "$url_file")"
      if echo "$candidate" | grep -qE '^https://[a-zA-Z0-9.-]+\.vercel\.app'; then
        URL="$candidate"
        break
      fi
    fi
  fi
  elapsed=$(( $(date +%s) - START ))
  echo "[ship]   ... ${elapsed}s elapsed (Action runs typically take 30-90s)"
done

if [ -n "$URL" ]; then
  echo
  echo "[ship] LIVE URL: $URL"
  # Update local deployment-notes.txt
  notes="$CASE_DIR/deployed/deployment-notes.txt"
  if [ -f "$notes" ]; then
    # Replace any "Production:" line with the real URL
    tmp=$(mktemp)
    sed "s|^Production:.*|Production:   $URL|; s|^url:.*|url:          $URL|" "$notes" > "$tmp"
    mv "$tmp" "$notes"
    echo "[ship] updated $notes"
  fi
  exit 0
else
  echo
  echo "[ship] WARN: no URL recorded after 3 min."
  echo "[ship]   - Check Action run: https://github.com/${GITHUB_REPO:-?}/actions"
  echo "[ship]   - If first deploy of a NEW artifact and Action FAILED:"
  echo "[ship]     verify VERCEL_TOKEN is set at"
  echo "[ship]     https://github.com/${GITHUB_REPO:-?}/settings/secrets/actions"
  exit 1
fi
