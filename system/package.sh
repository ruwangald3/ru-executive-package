#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# package.sh — Phase 2: Package deployment bundle.
#
# Usage:  ./system/package.sh <artifact-root>
#
# Confirms required files exist, generates vercel.json + README.md if missing,
# and writes a deployment manifest into the artifact's `deployed/` folder.
# Non-destructive — never overwrites existing files.
# ----------------------------------------------------------------------------
set -u

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo "usage: $0 <artifact-root>" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "ERROR: $ROOT not a directory" >&2; exit 2; }

cd "$ROOT" || exit 2
ART_ROOT="$(pwd)"
# Find the artifact "case" folder (containing versions/) for sibling output dirs
CASE_DIR="$ART_ROOT"
if [[ "$ART_ROOT" == */versions/* ]]; then
  CASE_DIR="${ART_ROOT%/versions/*}"
fi

mkdir -p "$CASE_DIR/deployed"

echo "[package] artifact root: $ART_ROOT"
echo "[package] case dir:      $CASE_DIR"

# ---- ensure vercel.json
if [ ! -f vercel.json ]; then
  cat > vercel.json <<'JSON'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "trailingSlash": false,
  "headers": [
    { "source": "/(.*)\\.(jpg|jpeg|png|webp|gif|svg|ico)",
      "headers": [ { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" } ] },
    { "source": "/styles.css",
      "headers": [ { "key": "Cache-Control", "value": "public, max-age=3600, must-revalidate" } ] },
    { "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" } ] }
  ]
}
JSON
  echo "[package] generated vercel.json"
fi

# ---- ensure README.md
if [ ! -f README.md ]; then
  cat > README.md <<'MD'
# Executive Artifact

Static HTML packet. Drop the folder anywhere that serves static files.
Deploy via Vercel — see project root `system/ship.sh`.
MD
  echo "[package] generated README.md"
fi

# ---- deployment manifest
MANIFEST="$CASE_DIR/deployed/deployment-manifest.txt"
{
  echo "ARTIFACT MANIFEST"
  echo "generated: $(date -Iseconds)"
  echo "root: $ART_ROOT"
  echo
  echo "FILES:"
  find . -type f -printf "  %P  (%s bytes)\n" | sort
} > "$MANIFEST"
echo "[package] manifest → $MANIFEST"

echo "[package] done"
