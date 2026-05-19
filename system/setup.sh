#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# [OPS] Executive Artifact Deployment System
# setup.sh — one-time bootstrap for autonomous deploys.
#
# Run this once. After this, every "Ship this to Vercel" works autonomously.
#
# Sets up:
#   1. Vercel CLI (installed globally via npm if missing)
#   2. system/.env.deploy from .example (if missing)
#   3. .git repo initialized at project root (if missing)
#   4. GitHub remote configured (using GITHUB_REPO from .env.deploy)
#   5. Sanity test: gh API auth, vercel CLI presence
#
# Usage:  ./system/setup.sh
# ----------------------------------------------------------------------------
set -u

SYS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SYS_DIR/.." && pwd)"
ENV_FILE="$SYS_DIR/.env.deploy"
EXAMPLE_FILE="$SYS_DIR/.env.deploy.example"

say(){ printf "[setup] %s\n" "$*"; }
fail(){ printf "[setup] ERROR: %s\n" "$*" >&2; exit 1; }
ok(){   printf "[setup]   ok — %s\n" "$*"; }

say "========================================="
say "  Bootstrap — autonomous deploy setup"
say "========================================="

# ---- 1. Vercel CLI
say "Step 1 — Vercel CLI"
if command -v vercel >/dev/null 2>&1; then
  ok "vercel CLI present ($(vercel --version))"
elif command -v npx >/dev/null 2>&1; then
  say "  installing vercel globally (npm i -g vercel)"
  if npm i -g vercel 2>&1 | tail -3; then
    ok "vercel CLI installed"
  else
    say "  global install may have failed — npx fallback will still work"
  fi
else
  fail "neither vercel nor npx found — install Node.js first"
fi

# ---- 2. .env.deploy
say "Step 2 — credentials file"
if [ -f "$ENV_FILE" ]; then
  ok "$ENV_FILE present"
else
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  ok "created $ENV_FILE from example — FILL IN values before deploying"
fi

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

# ---- 3. git init
say "Step 3 — git repository"
cd "$PROJECT_ROOT"
if [ -d .git ]; then
  ok ".git already initialized"
else
  git init -q -b main
  ok "git initialized (branch: main)"
fi

# ---- 4. GitHub remote
say "Step 4 — GitHub remote"
if [ -n "${GITHUB_REPO:-}" ] && [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_USERNAME:-}" ]; then
  REMOTE_URL="https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
    ok "updated origin → github.com/$GITHUB_REPO"
  else
    git remote add origin "$REMOTE_URL"
    ok "added origin → github.com/$GITHUB_REPO"
  fi
else
  say "  GITHUB_REPO / GITHUB_USERNAME / GITHUB_TOKEN not set — fill .env.deploy and rerun"
fi

# ---- 5. Sanity
say "Step 5 — sanity checks"
if [ -n "${GITHUB_TOKEN:-}" ]; then
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user)
  if [ "$code" = "200" ]; then
    user=$(curl -sS -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -oE '"login":\s*"[^"]+"' | head -1 | sed -E 's/.*"login":\s*"([^"]+)".*/\1/')
    ok "GitHub token valid (authenticated as: $user)"
  else
    say "  GitHub token check returned HTTP $code — verify scopes (Contents: read & write)"
  fi
else
  say "  no GITHUB_TOKEN — skipping API check"
fi

say "========================================="
say "  Setup complete."
say "========================================="
echo
echo "Next: ./system/ship.sh artifacts/<case>/versions/<v> --prod"
