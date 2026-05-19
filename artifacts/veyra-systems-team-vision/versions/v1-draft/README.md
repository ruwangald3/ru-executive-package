# Veyra Systems — Team Vision Overview

Self-contained shareable HTML artifact. Bundled at build time (Claude Artifacts
output): all CSS + JS + content inline in a single `index.html`.

Custom web component: `<deck-stage>` — defined inside the bundle.

## Files

- `index.html` — the artifact (self-contained, ~375KB)
- `styles.css` — minimal placeholder (satisfies validator; HTML is self-styled)
- `vercel.json` — cache + security headers
- `README.md` — this file
- `assets/` — empty (HTML is self-contained)

## Source

Extracted from: `source-zip/Enspire Consulting - Team Vision Overview.zip`
Canonical file used: `Veyra Vision Overview - shareable.html`

## Deploy

```bash
./system/ship.sh artifacts/veyra-systems-team-vision/versions/v1-draft --prod
```
