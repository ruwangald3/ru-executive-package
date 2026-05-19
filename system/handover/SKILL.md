---
name: executive-session-handover-protocol
slash: /handover
description: Generate a token-efficient continuation summary so a fresh Claude/Cowork session can resume operational work without re-explaining context. Trigger with "/handover", "session handover", "create handover", "snapshot project state", or "summarize for next session". Scans current project state, deployments, blockers, and produces a structured markdown doc plus a boot prompt ready for the next session.
classification: OPS
owner: Claude
scope: Enspire operational infrastructure (canonical implementation lives in [OPS] Executive Artifact Deployment System; pattern is reusable across all CORE/OPS/PRODUCT projects)
inputs:
  - none (auto-detects project state from working directory)
outputs:
  - system/handover/latest.md         (overwrites — always current)
  - system/handover/<timestamp>.md    (append-only history)
  - chat-rendered summary
---

# /handover — Executive Session Handover Protocol

## What it does

Turns the current session's accumulated context into a structured, token-efficient
document that the next session can ingest in ~5 seconds.

Eliminates "let me catch you up on what we did last time" preamble. The next
session reads `system/handover/latest.md` and is immediately operational.

## Trigger phrases

- `/handover`
- `session handover`
- `create handover`
- `snapshot project state`
- `summarize for next session`
- `prepare handover`

## Invocation

Claude runs:

```bash
./system/handover.sh --write       # full output + writes to system/handover/latest.md
./system/handover.sh --terse       # ultra-compressed (one-paragraph boot prompt)
./system/handover.sh               # prints to stdout, doesn't persist
```

Default behavior when triggered by user: `--write` (full + persisted).

## Output schema (auto-generated, exact sections)

1. **Project state** — one-line description
2. **Active artifacts** — table of case folders + versions
3. **Deployment status** — live URL per artifact, latest commit
4. **Repo + commit** — GitHub URL, branch, HEAD SHA
5. **Credentials state** — what's configured in `system/.env.deploy`
6. **Reusable skills** — every `system/*.sh` script present
7. **Blockers / dependencies** — auto-detected from deployment-notes
8. **Immediate next actions** — branched by blocker presence
9. **Boot prompt for next session** — copy-paste ready

## When to invoke

- End of a working session before closing Cowork
- Mid-session checkpoint before a risky operation
- Right before context-window pressure forces a fresh session
- Onboarding a teammate to continue the work
- Before handing off to a different Claude variant (Code/Chat/Cowork)

## What it intentionally does NOT include

- Full command transcripts (those live in deploy logs)
- Source-code context (the repo itself is the source of truth)
- Speculative future tasks not already in the task list
- Anything the next session can derive from `git log` or file inspection

## Boot prompt format (copy-paste into next session)

The bottom of every handover doc contains:

```
Resume the [OPS] Executive Artifact Deployment System project.
Read system/handover/latest.md for full state.
HEAD commit: <sha>
Active artifacts: <comma-separated>
Next action: <one-line>
```

Paste this verbatim as the first message in a fresh Cowork session and Claude
will read `latest.md` and be operational without further explanation.

## Why this lives in [OPS] Executive Artifact Deployment System

This is the **canonical implementation** of the Enspire-wide Session Handover
Protocol. The pattern (state-scan → structured-summary → boot-prompt) is
intended to be reused across CORE / OPS / PRODUCT projects.

When other Enspire projects need session handover, they should:

1. Copy `system/handover.sh` and `system/handover/SKILL.md` into their `system/`
2. Adjust the project-state one-liner at the top of `handover.sh`
3. Adjust the artifact-scan paths if their folder convention differs
4. Trigger phrases stay identical (`/handover`)

Do NOT fork this into a separate project. Treat this as the reference
implementation; other projects depend on the same trigger phrases and output
schema so handovers stay consistent across the whole Enspire org.

## Anti-patterns to avoid

- Don't write the handover doc by hand. Always invoke the script — it stays
  current with file system reality.
- Don't include credentials, tokens, or secrets in the handover. The script
  intentionally reports credential *presence*, never values.
- Don't store more than ~5 timestamped handover snapshots. Older ones add
  noise. Cron / manual cleanup recommended.

## Status

Production. Tested end-to-end against this project.
