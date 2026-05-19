---
name: ship-executive-artifact
slash: /ship
description: One-command, fully autonomous publishing for executive HTML artifacts. Resolve a single artifact slug, validate + package + push to GitHub. A GitHub Actions runner then auto-creates the Vercel project (if needed), deploys, and commits the live URL back. Invoke with "/ship <artifact-slug>" — e.g. "/ship veyra-systems-team-vision". No manual Vercel setup per artifact. Use whenever any artifact under artifacts/* needs to be published or republished.
classification: OPS
owner: Claude
scope: Enspire-wide canonical publishing command
trigger_phrases:
  - "/ship <slug>"
  - "ship <slug>"
  - "ship the <slug> artifact"
  - "publish <slug>"
  - "deploy <slug>"
inputs:
  - artifact slug (folder name under artifacts/)
  - optional: --version <name>
  - optional: --prod
  - optional: --no-wait  (return immediately after push, skip URL polling)
outputs:
  - live Vercel URL (printed + written to artifacts/<slug>/deployed/url.txt)
  - deployed/deployment-notes.txt
  - deployed/last-deploy.txt (slug, version, URL, commit, ts)
  - deployed/deploy-<version>-<ts>.log
---

# /ship — Vercel Executive Artifact Deployment Pipeline

## Single canonical command

```
/ship <artifact-slug>
```

That's it. There is no `/vercel-create`, no `/deploy-init`, no per-artifact
browser step. The system creates Vercel projects on demand via GitHub Actions.

## Architecture (3 actors, autonomous after 1 secret)

```
   Cowork sandbox          GitHub                    GitHub Action          Vercel
   --------------          ------                    -------------          ------
   /ship <slug>                                                              .
   ship-cmd.sh resolves    git push origin           on push:
   slug -> version    -->                       -->  detect changed art -->  vercel deploy --prod
                                                     run vercel CLI         (auto-creates project
                                                     capture URL             named after slug if
                           commit url.txt back  <--  commit url.txt          first deploy)
                           (skip-ci marker)          [skip ci]
   ship-cmd.sh polls
   git fetch +              read url.txt        <--
   reset --hard
                            
   prints LIVE URL ✓
```

Cowork sandbox cannot reach `vercel.com` / `api.vercel.com` (proxy-blocked).
GitHub Actions runners CAN. That's why Vercel automation lives in the Action,
not in the sandbox. The URL travels back via a git commit — the only
reverse-channel both layers can use.

## 14-step internal pipeline

| # | Step | Where |
|---|------|-------|
| 1 | Locate artifact by slug | ship-cmd (Cowork) |
| 2 | Validate folder structure | validate.sh (Cowork) |
| 3 | Confirm index.html at deployment root | validate.sh |
| 4 | Resolve every asset (200 sweep, font/script/img refs) | validate.sh |
| 5 | Run responsive QA heuristics (≥2 media queries, clamp, print rules) | validate.sh |
| 6 | (PDF QA static heuristics — print-color-adjust, @page) | validate.sh |
| 7 | Package: ensure vercel.json + manifest | package.sh |
| 8 | Check if Vercel project exists (Action does it) | GitHub Action |
| 9 | Auto-create project if missing (Vercel CLI with --name) | GitHub Action |
| 10 | Deploy via `vercel deploy --prod` | GitHub Action |
| 11 | Validate live deployment (CLI exits non-zero on failure) | GitHub Action |
| 12 | Commit URL → `artifacts/<slug>/deployed/url.txt` `[skip ci]` | GitHub Action |
| 13 | Cowork fetches commit, reads URL, updates notes | ship-cmd |
| 14 | Return URL to operator | ship-cmd |

## Examples

```bash
# Cowork chat / shell — fully autonomous, returns URL in ~30–90s
/ship veyra-systems-team-vision
/ship sivers-resume-v2 --version v2-tightened
/ship ai-engage-investor-brief --prod

# Skip the URL polling (just push and exit fast)
/ship some-artifact --no-wait
```

## One-time setup (NEVER repeated per artifact)

This is the only manual step in the entire system. After this, every future
artifact ships in one command.

### Step 1 — Generate Vercel token

1. Visit https://vercel.com/account/tokens
2. Click **Create Token**
3. Name: `cowork-ship-automation`
4. Scope: **Full Account** (or restrict to the team/project if preferred)
5. Copy the `vercel_xxxxxxxx` value

### Step 2 — Add as GitHub secret

1. Visit https://github.com/ruwangald3/ru-executive-package/settings/secrets/actions/new
2. Name: `VERCEL_TOKEN`
3. Value: paste the token from Step 1
4. Click **Add secret**

Done forever. Every future `/ship <slug>` is now end-to-end autonomous.

## Standards enforced (every ship, every artifact)

- No nested `index.html` — must be at version root
- No broken asset references (HTTP 200 sweep)
- No text overflow risk (responsive CSS heuristics)
- Fully responsive (≥2 media queries + clamp() typography)
- Mobile-safe (no `position:fixed` overlap; rotate-hint pattern when applicable)
- Print-safe (`@page`, `print-color-adjust: exact`)
- Reusable folder convention: `artifacts/<slug>/versions/<version>/`
- No duplicate Vercel projects (Action keys projects by slug — idempotent)

## Slug → path resolution

Given `/ship <slug>`:

```
artifacts/<slug>/versions/<latest-non-archive>/
```

`latest` = newest `mtime` of the version folders. Override with `--version <name>`.

If slug doesn't exist, command lists available slugs (from `artifacts/`).

## Error modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `artifact '<slug>' not found` | typo / not yet placed | check listed slugs |
| `no deployable versions found` | empty `versions/` folder | place a `versions/<name>/` with `index.html` |
| `validation FAILED` | structural issue | see `validate.sh` output |
| no URL after 3 min | Action failed | check Action logs at github.com/.../actions |
| Action error: `VERCEL_TOKEN not set` | first-time setup not done | follow One-time setup above |

## Files involved

- `system/ship-cmd.sh` (also `system/ship` alias) — slug resolver + URL poller
- `system/ship.sh` — Phase 1–3 (validate + package + push)
- `system/validate.sh` — Phase 1 static checks
- `system/package.sh` — Phase 2 packaging
- `.github/workflows/deploy.yml` — Phases 8–12 (Vercel via Action)
- `system/.env.deploy` — GitHub credentials (gitignored)

## Status

Production. The one-time `VERCEL_TOKEN` GitHub secret unlocks fully autonomous
publishing for every current and future artifact.

## Goal

One-command executive artifact publishing for all Enspire entities. Operator
types `/ship <slug>` — system returns a live URL. No exceptions.
