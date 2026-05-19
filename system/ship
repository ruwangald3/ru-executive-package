#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# ship-cmd.sh — slug-resolution wrapper for the canonical /ship command.
#
# Usage:
#   ./system/ship-cmd.sh <artifact-slug> [--version <v>] [--prod] [--project <p>]
#
# Examples:
#   ./system/ship-cmd.sh veyra-systems-team-vision
#   ./system/ship-cmd.sh sivers-resume --version v2 --prod
#   ./system/ship-cmd.sh ai-engage-investor-brief --prod
#
# Behavior:
#   1. Resolves <slug> to artifacts/<slug>/versions/<latest>/
#   2. Picks newest non-archive version unless --version is given
#   3. Hands off to ship.sh for the full Phase 1–5 pipeline
#   4. Errors clearly if slug doesn't exist or no versions present
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"

SLUG=""; VERSION=""; PROD=""; PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2;;
    --prod)    PROD="--prod"; shift;;
    --project) PROJECT="--project $2"; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) [ -z "$SLUG" ] && SLUG="$1" || { echo "unknown arg: $1" >&2; exit 2; }; shift;;
  esac
done

[ -z "$SLUG" ] && { echo "usage: $0 <artifact-slug> [--version <v>] [--prod] [--project <p>]" >&2; exit 2; }

# Strip leading slash if user typed /slug
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

# Resolve version
if [ -n "$VERSION" ]; then
  TARGET="$VERSIONS_DIR/$VERSION"
  [ -d "$TARGET" ] || { echo "ERROR: version '$VERSION' not found at $TARGET" >&2; exit 2; }
else
  # Pick newest non-archive version by mtime (find avoids bracket-as-glob bugs)
  TARGET=""
  while IFS= read -r v; do
    bn="$(basename "$v")"
    case "$bn" in _archive-*) continue;; esac
    TARGET="$v"
    break
  done < <(find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\n" 2>/dev/null | sort -nr | awk '{$1=""; sub(/^ /,""); print}')
  [ -z "$TARGET" ] && { echo "ERROR: no deployable versions found under $VERSIONS_DIR" >&2; exit 2; }
fi

REL_TARGET="$(realpath --relative-to="$PROJECT_ROOT" "$TARGET")"
echo "[ship-cmd] artifact: $SLUG"
echo "[ship-cmd] version : $(basename "$TARGET")"
echo "[ship-cmd] target  : $REL_TARGET"
echo "[ship-cmd] -> ./system/ship.sh \"$REL_TARGET\" $PROD $PROJECT"
echo

# Hand off
# shellcheck disable=SC2086
exec bash "$SYS_DIR/ship.sh" "$TARGET" $PROD $PROJECT
