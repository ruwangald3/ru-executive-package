---
name: vercel-deployment-executive-packaging
description: Autonomously ship executive HTML artifacts (decks, packets, resumes, landing pages) to a live Vercel URL. Invoke when the user says "Ship this to Vercel", "deploy this artifact", "publish this packet", "ship this", or asks to publish any folder under `artifacts/*/versions/*`. Performs validation, responsive QA, GitHub commit + push, deployment routing, polling for live URL, and writes the full QA paper trail. No manual steps after one-time setup.
classification: OPS
owner: Claude
autonomy: full   # after one-time setup
inputs:
  - artifact-root (path) containing index.html at root
  - system/.env.deploy (credentials — populated by `system/setup.sh`)
outputs:
  - live Vercel URL
  - deployed/deployment-notes.txt (URL + manifest)
  - qa/{pre,post,mobile}-qa-checklist.md
  - pdf/pdf-export-instructions.md
---

# [OPS] Vercel Deployment + Executive Packaging — Autonomous Skill

## Trigger phrases

- "Ship this to Vercel"
- "Deploy this packet/deck/resume/site"
- "Publish this artifact"
- "Ship it"

## Architecture (deploy routing)

The Cowork sandbox cannot reach `vercel.com` (egress allowlist blocks it).
`github.com` and `registry.npmjs.org` ARE reachable. Therefore the
autonomous deploy path is:

```
   Cowork sandbox           GitHub                Vercel
   --------------           ------                ------
   ship.sh validates  →  git push origin  →  GitHub webhook fires
                              ↓                     ↓
                         commit SHA            Vercel build + deploy
                              ↓                     ↓
   ship.sh polls       ←  check-runs API   ←  posts deployment URL
                              ↓
                       writes deployment-notes.txt + prints LIVE URL
```

When `ship.sh` is run on a host that *can* reach `vercel.com` (e.g. the
operator's local Windows machine), it bypasses the polling path and uses
the Vercel CLI directly with `$VERCEL_TOKEN`. Same script, two paths.

## Workflow — Phases 1–5

| Phase | What happens | On failure |
|-------|--------------|------------|
| 1. VALIDATE | `system/validate.sh` runs all file + asset + responsive checks | Hard stop. No deploy. |
| 2. PACKAGE | Auto-generate `vercel.json` + `README.md` if missing; write manifest | Logged but non-fatal |
| 3. GIT | Init repo if needed → commit → push to `origin` (GitHub) | Skip remaining if no push and no Vercel CLI |
| 4. DEPLOY | If vercel.com reachable + `VERCEL_TOKEN` set → CLI deploy; else poll GitHub check-runs for Vercel auto-deploy URL | Surface precise blocker |
| 5. RECORD | Write `deployed/deployment-notes.txt` with live URL | — |

## One-time setup (~10 min, never repeated)

```bash
./system/setup.sh
```

Then fill in `system/.env.deploy`:

```
GITHUB_USERNAME=<your-gh-handle>
GITHUB_TOKEN=<fine-grained PAT, scope: Contents R/W on the artifacts repo>
GITHUB_REPO=<owner/repo-name>
GITHUB_DEFAULT_BRANCH=main

# Optional — only needed if running ship.sh on a host that CAN reach vercel.com:
VERCEL_TOKEN=<https://vercel.com/account/tokens>
VERCEL_TEAM=<team-slug or empty>
```

**One-time Vercel ↔ GitHub link** (via Vercel dashboard, ~2 min):

1. Go to <https://vercel.com/new>
2. Import the GitHub repo configured above
3. **Root Directory:** set to the first artifact path you intend to deploy
   (e.g. `artifacts/ru-executive-package-v1/versions/sivers-custom-v1`)
4. Framework preset: **Other**
5. Deploy.

After this, every `git push` from the Cowork sandbox auto-deploys.

## Running the skill (autonomous, every time after setup)

User: **"Ship this to Vercel"** (while 