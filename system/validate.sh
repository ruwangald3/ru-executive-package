#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# validate.sh — Phase 1: Static + responsive validation of an artifact root.
#
# Usage:  ./system/validate.sh <artifact-root>
# Example: ./system/validate.sh artifacts/ru-executive-package-v1/versions/sivers-custom-v1
#
# Exits non-zero if any required file is missing or any local asset reference
# fails to resolve. Prints a structured report to stdout.
# ----------------------------------------------------------------------------
set -u

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  echo "usage: $0 <artifact-root>" >&2
  exit 2
fi
if [ ! -d "$ROOT" ]; then
  echo "ERROR: artifact root not found: $ROOT" >&2
  exit 2
fi

cd "$ROOT" || exit 2

pass=0; fail=0
note(){ printf "  [%s] %s\n" "$1" "$2"; }
ok(){   note "OK" "$1"; pass=$((pass+1)); }
bad(){  note "FAIL" "$1"; fail=$((fail+1)); }
warn(){ note "WARN" "$1"; }

echo "===================================================================="
echo "  ARTIFACT VALIDATION"
echo "  root: $ROOT"
echo "===================================================================="

echo; echo "[1] Required files"
for f in index.html styles.css vercel.json README.md; do
  [ -f "$f" ] && ok "$f present" || bad "$f MISSING"
done
[ -d assets ] && ok "assets/ folder present" || bad "assets/ folder MISSING"

echo; echo "[2] index.html at root"
if [ -f index.html ]; then ok "index.html is at deployment root"; else bad "index.html is NOT at deployment root"; fi

echo; echo "[3] Local asset references resolve"
if [ -f index.html ]; then
  refs=$(grep -oE '(src|href)="[^"]+"' index.html | sed -E 's/^(src|href)="//;s/"$//')
  while IFS= read -r ref; do
    case "$ref" in
      http*://*|//*) : ;;  # remote — skip
      *)
        path="${ref%%\?*}"  # strip ?cache-bust
        [ -z "$path" ] && continue
        if [ -e "$path" ]; then ok "ref → $path"; else bad "ref MISSING → $path"; fi
        ;;
    esac
  done <<<"$refs"
fi

echo; echo "[4] Unused assets (informational)"
if [ -d assets ]; then
  for a in assets/*; do
    base=$(basename "$a")
    if ! grep -q "$base" index.html styles.css 2>/dev/null; then
      warn "asset not referenced: $a"
    fi
  done
fi

echo; echo "[5] Responsive CSS heuristics"
if [ -f styles.css ]; then
  mq=$(grep -cE '@media' styles.css || true)
  cl=$(grep -cE 'clamp\(' styles.css || true)
  pr=$(grep -cE '@media\s*print|@page|page-break' styles.css || true)
  fx=$(grep -cE 'position:\s*fixed' styles.css || true)
  pca=$(grep -cE 'print-color-adjust' styles.css || true)
  [ "$mq" -ge 2 ] && ok  "media queries: $mq"            || bad  "media queries: $mq (need ≥2)"
  [ "$cl" -ge 1 ] && ok  "clamp() typography: $cl"       || warn "clamp() typography: $cl"
  [ "$pr" -ge 1 ] && ok  "print rules present: $pr"      || bad  "print rules missing"
  [ "$fx" -eq 0 ] && ok  "no position:fixed (no overlap risk)" || warn "position:fixed used: $fx"
  [ "$pca" -ge 1 ] && ok "print-color-adjust set"        || warn "print-color-adjust not set — PDF may lose color"
fi

echo; echo "[6] HTTP serve sweep"
if command -v python3 >/dev/null 2>&1; then
  python3 -m http.server 8765 >/tmp/validate-httpd.log 2>&1 &
  pid=$!
  sleep 1
  fail_http=0
  for u in $(grep -oE '(src|href)="[^"]+"' index.html | sed -E 's/^(src|href)="//;s/"$//' | grep -vE '^https?://' ); do
    p="${u%%\?*}"
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8765/$p")
    if [ "$code" = "200" ]; then ok "200 /$p"; else bad "HTTP $code /$p"; fail_http=$((fail_http+1)); fi
  done
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
else
  warn "python3 not available, skipping HTTP sweep"
fi

echo
echo "===================================================================="
echo "  RESULT — pass: $pass   fail: $fail"
echo "===================================================================="
[ "$fail" -eq 0 ] && exit 0 || exit 1
