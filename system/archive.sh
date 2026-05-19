#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# archive.sh — Snapshot a version into the case's versions/ folder.
#
# Usage:  ./system/archive.sh <case-dir> <new-version-name>
# Example: ./system/archive.sh artifacts/ru-executive-package-v1 v2-tightened
#
# Copies the latest version into a new versions/<name>/ folder so the original
# is preserved untouched. Use this before iterating on layout changes.
# ----------------------------------------------------------------------------
set -u
CASE="${1:-}"; NEW="${2:-}"
[ -z "$CASE" ] || [ -z "$NEW" ] && { echo "usage: $0 <case-dir> <new-version-name>" >&2; exit 2; }
[ -d "$CASE/versions" ] || { echo "ERROR: $CASE/versions not found" >&2; exit 2; }

# Pick the most recent version folder
LATEST="$(ls -1dt "$CASE"/versions/*/ 2>/dev/null | head -1)"
[ -z "$LATEST" ] && { echo "ERROR: no version folders in $CASE/versions" >&2; exit 2; }

DEST="$CASE/versions/$NEW"
[ -e "$DEST" ] && { echo "ERROR: $DEST already exists — choose a new name" >&2; exit 2; }

cp -R "$LATEST" "$DEST"
echo "[archive] $LATEST  →  $DEST"
