---
name: ship-executive-artifact
slash: /ship
description: One-command publishing workflow for executive HTML artifacts. Resolve a single artifact slug to its latest version, run end-to-end validation + packaging + GitHub push + Vercel auto-deploy + QA + URL capture. Invoke with "/ship <artifact-slug>" (e.g. "/ship veyra-systems-team-vision"). Wraps the Vercel Executive Artifact Deployment Pipeline. Use whenever an artifact under artifacts/* needs to be published or republished.
classification: OPS
owner: Claude
scope: Enspire-wide operational infrastructure
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
  - optional: --project <name>
outputs:
  - live Vercel URL (or precise next-step if Vercel project link is pending)
  - deployed/deployment-notes.txt
  - deployed/deployment-manifest.txt
  - deployed/deploy-<version>-<ts>.log
---

# /ship — Vercel Executive Artifact Deployment Pipeline

One-command publishing for any executive HTML artifact under `artifacts/`.

## Usage

```bash
# In Cowork chat:
/ship veyra-systems-team-vision
/ship sivers-resume-v2 --version v2-tightened
/ship ai-engage-investor-brief --prod

# In shell:
./system/ship veyra-systems-team-vision --prod
./system/ship-cmd.sh sivers-resume --version v2 --prod
```

## What it does (12-step pipeline)

| # | Step | Owner |
|---|------|-------|
| 1 | Locate artifact (resolve slug → `artifacts/<slug>/`) | ship-cmd |
| 2 | Pick latest non-archive version (or `--version`) | ship-cmd |
| 3 | Validate folder structure | ship.sh / validate.sh |
| 4 | Confirm `index.html` at deployment root | validate.sh |
| 5 | Resolve every asset reference (200 check) | validate.sh |
| 6 | Run responsive CSS heuristics (≥2 media queries, print rules, no `position:fixed`) | validate.sh |
| 7 | Package (auto-gen `vercel.json`, `README.md`, manifest) | package.sh |
| 8 | Commit + push to GitHub (auto-stages to /tmp if mount blocks .git) | ship.sh |
| 9 | Deploy via Vercel CLI (if reachable + token) OR via GitHub→Vercel webhook | ship.sh |
| 10 | Capture / predict live URL | ship.sh |
| 11 | Write `deployment-notes.txt` + log | ship.sh |
| 12 | Return URL to operator | ship-cmd |

Mobile and PDF QA checklists are co-authored on first deploy and live in
`<case>/qa/` and `<case>/pdf/`. Static heuristics enforced by `validate.sh`.

## Standards enforced (every ship)

- No nested `index.html` — must be at version root
- No broken asset references (HTTP 200 sweep)
- No text overflow risk (responsive CSS heuristics)
- Fully responsive (≥2 media queries + clamp() typography)
- Mobile-safe (rotate-hint pattern when applicable; no `position:fixed` overlap)
- Print-safe (`@page`, `print-color-adjust: exact`)
- Reusable folder convention: `artifacts/<slug>/versions/<version>/`

## Slug → path resolution

Given `/ship <slug>`:

```
artifacts/<slug>/versions/<latest-non-archive>/
```

Latest = newest `mtime`. Override with `--version <name>`.

If slug doesn't exist, the command lists available slugs:

```
ERROR: artifact 'foo' not found
Available artifacts:
  - ru-executive-package-v1
  - veyra-systems-team-vision
  - ...
```

## Error modes (operator-friendly)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `artifact '<slug>' not found` | typo / not yet placed | check the listed available slugs |
| `no deployable versions found` | empty `versions/` folder | add a `versions/<name>/` with `index.html` |
| `validation FAILED` | index.html missing, broken asset, no media queries, etc. | see `validate.sh` output for the exact line |
| `git push failed` | bad PAT, repo gone | rerun `./system/setup.sh` |
| URL returns 404 | Vercel project not linked to this artifact's root dir | one-time `vercel.com/new` import |

## Files involved

- `system/ship-cmd.sh` (also exposed as `system/ship`) — slug resolver / wrapper
- `system/ship.sh` — end-to-end pipeline orchestrator
- `system/validate.sh` — Phase 1 validator
- `system/package.sh` — Phase 2 packager
- `system/.env.deploy` — credentials (gitignored)
- `system/ship-skill/SKILL.md` — this contract

## Status

Production. Tested against `ru-executive-package-v1/sivers-custom-v1` and
`veyra-systems-team-vision/v1-draft` (both pushed to GitHub `ruwangald3/ru-executive-package`).

## Goal

One-command executive artifact publishing across all Enspire entities.
Operator types `/ship <slug>` and the rest is automatic.
