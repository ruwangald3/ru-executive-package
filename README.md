# [OPS] Executive Artifact Deployment System

Reusable deployment system for executive-grade HTML artifacts —
investor decks, positioning packets, AI Engage decks, DTX landing pages,
resumes, and any other client-facing HTML deliverable.

**Mission:** *Generate once → deploy everywhere — without manual rework per artifact.*

---

## What this project is

A long-term operating system for shipping HTML artifacts to Vercel with:

- consistent folder structure across every artifact
- automated validation + responsive QA before every deploy
- reusable shell scripts that wrap the full GitHub → Vercel pipeline
- archived version history per artifact
- standard PDF export procedure

Every new executive artifact lives in `artifacts/<artifact-name>/versions/<version>/`
and is shipped via a single command: **"Ship this to Vercel"** (see `system/ship.sh`).

---

## Folder convention

```
[OPS] Executive Artifact Deployment System/
├── README.md                    # this file
├── SKILL.md                     # invocation contract for the reusable skill
├── system/                      # reusable scripts (do not modify per-artifact)
│   ├── ship.sh                  # end-to-end deployment (Phases 1–5)
│   ├── validate.sh              # pre-deploy validation + QA heuristics
│   ├── package.sh               # ensure vercel.json + README + manifest
│   └── archive.sh               # snapshot a version
└── artifacts/
    └── <artifact-name>/         # one folder per executive artifact case
        ├── versions/
        │   ├── <customer>-custom-v1/   # deployable root — index.html lives here
        │   │   ├── index.html           # (e.g. sivers-custom-v1, acme-custom-v1)
        │   │   ├── styles.css
        │   │   ├── vercel.json
        │   │   ├── README.md
        │   │   └── assets/
        │   └── <customer>-custom-v2/    # iterate by archiving + editing
        ├── deployed/            # deployment-notes.txt, logs, manifests
        ├── qa/                  # pre/post/mobile checklists per version
        ├── pdf/                 # exported PDF + export instructions
        ├── screenshots/         # device-fit screenshots
        └── source-zip/          # original source bundle if any
```

The deployable root is **always** `artifacts/<name>/versions/<version>/`.
`index.html` MUST be at that root — Vercel deploys this directory directly.

---

## Quickstart — placing a new artifact

```bash
mkdir -p "artifacts/<artifact-name>/versions/sivers-custom-v1/assets"
cp your-built-files/* "artifacts/<artifact-name>/versions/sivers-custom-v1/"
```

Then ship it:

```bash
./system/ship.sh "artifacts/<artifact-name>/versions/sivers-custom-v1" --prod
```

The script will:

1. Validate the folder + every linked asset
2. Run responsive QA heuristics
3. Package (auto-generate vercel.json / README if missing)
4. Commit to git if `.git/` exists, push if `origin` is set
5. Deploy to Vercel using the local CLI (`vercel` or `npx vercel`)
6. Capture the live URL → write `deployed/deployment-notes.txt`

---

## Invoking deployment

### Option A — local CLI (recommended)

```bash
export VERCEL_TOKEN=<your-token>           # one-time
./system/ship.sh artifacts/<name>/versions/<v> --prod
```

Token source: <https://vercel.com/account/tokens>

### Option B — Claude / Cowork chat command

Tell Claude: **"Ship this to Vercel"** while focused on an artifact folder.
Claude follows the contract in `SKILL.md` — validate, package, deploy, record.

### Option C — fully manual (fallback)

1. `cd artifacts/<name>/versions/<v>`
2. `npx vercel deploy --prod`
3. Record the printed URL in `../../deployed/deployment-notes.txt`

---

## Version management

- **Never edit a deployed version in place.** Snapshot first:
  ```bash
  ./system/archive.sh artifacts/<name> v2-tightened
  ```
- Each version folder is independently deployable.
- Keep `versions/` named `<customer>-custom-v<n>` (e.g. `sivers-custom-v1`, `sivers-custom-v2`, `acme-custom-v1`).
- `deployed/deployment-notes.txt` accumulates one entry per ship.

---

## PDF storage

PDFs live in `artifacts/<name>/pdf/`.
Naming: `<artifact-slug>-<version>.pdf`
Export procedure: see `artifacts/<name>/pdf/pdf-export-instructions.md`
(autocreated on first deploy if not present).

---

## Recording live URLs

Every `ship.sh` run appends to `artifacts/<name>/deployed/deployment-notes.txt`:

```
artifact:   ru-executive-package-v1
version:    sivers-custom-v1
project:    ru-executive-package-v1
deployed:   2026-05-19T16:42:00+00:00
url:        https://ru-executive-package-v1-<hash>.vercel.app
```

Use the **production alias** (last deploy with `--prod`) as the canonical
shareable URL. Vercel keeps every prior deploy URL stable as well — use those
for archival reference / rollback.

---

## QA standards (enforced by validate.sh + checklist)

Required device-fit checks before any external share:

- Desktop 1440px
- Laptop 1366px
- iPad portrait + landscape
- iPhone portrait + landscape
- Print / PDF export (Letter, no color loss)

The validator flags: missing assets, no print rules, position:fixed risk,
no print-color-adjust, no media queries, broken local references.

The reviewer (human) still checks: overflow, clipping, footer overlap,
half-page mobile render, logo render, white-outline artifacts.

---

## Required integrations

| Capability       | Today                              | Future |
|------------------|------------------------------------|--------|
| GitHub           | local git → manual `git push`      | Auto-create repo + push via PAT |
| Vercel deploy    | local CLI with `VERCEL_TOKEN`      | Vercel API direct (no CLI) |
| Custom domains   | configured manually in Vercel UI   | Domain assignment via API |
| Analytics        | not wired                          | PostHog / Vercel Analytics |
| Version archive  | `archive.sh`                       | Auto-snapshot on each deploy |
| PDF generation   | manual (Chrome → Save as PDF)      | Playwright headless render |
| Rollback         | switch alias to prior deploy URL   | One-command rollback in ship.sh |

---

## Session continuity — `/handover`

This project hosts the canonical implementation of the **Executive Session
Handover Protocol** — an Enspire-wide pattern for handing operational
work between Claude sessions with zero re-explanation.

Trigger any of: `/handover`, `session handover`, `create handover`,
`snapshot project state`, `summarize for next session`.

```bash
./system/handover.sh --writ