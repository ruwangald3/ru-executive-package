# PDF Export Instructions — ru-executive-package-v1

The packet is designed to print exactly 3 pages on US Letter, color-preserved,
with no rotate hint, no animations baked in, and no font fallback flash.

---

## Method 1 — Chrome (recommended)

1. Open the live Vercel URL in **Chrome** (not Safari — Safari distorts the
   page gutter).
2. Wait until fonts load (1–2 seconds — watch the hero name swap from
   fallback to Inter).
3. ⌘P / Ctrl+P → **Print**.
4. **Destination:** Save as PDF.
5. **Pages:** All.
6. **Layout:** Portrait.
7. **Paper size:** **Letter (8.5 × 11 in)**.
8. **Margins:** **None** (the artifact has its own padding).
9. **Scale:** Default (100%) — do NOT use "Fit to printable area" (will shrink).
10. **More settings → Options:** check **Background graphics**.
11. Save as: `ru-executive-package-v1.pdf` in `pdf/` folder of this artifact.

Expected output: 3 pages, ~600–900 KB, colors fully preserved.

## Method 2 — Headless (future automation)

When automated, the canonical export command is:

```bash
npx playwright@latest cdp --browser=chromium -- \
  page.pdf --format=Letter --print-background --margin=0 \
  "<live-url>" "pdf/ru-executive-package-v1.pdf"
```

(or equivalent Puppeteer / chromium --headless --print-to-pdf invocation
once wired into `system/`).

## Method 3 — Safari (last resort)

Acceptable if Chrome unavailable:

1. File → Export as PDF.
2. Verify all 3 pages present.
3. Check colors — Safari sometimes drops `print-color-adjust: exact` on older
   versions. If colors look washed out, switch to Chrome.

---

## Verification after export

Open the saved PDF and confirm:

- [ ] Exactly **3 pages**
- [ ] Page 1: Identity + Signal strip + TI Turing
- [ ] Page 2: 20-year timeline
- [ ] Page 3: Why Sivers fit matrix
- [ ] No rotate-hint visible anywhere
- [ ] No partial page / orphan content
- [ ] Logos crisp, not pixelated
- [ ] Background gradients and accent colors present (not flat white)
- [ ] File size 400 KB – 1.2 MB (anything outside this range is suspect)

---

## Naming convention

`<artifact-slug>-<version>.pdf`

Examples:
- `ru-executive-package-v1.pdf`
- `ru-executive-package-v2-tightened.pdf`

Store in: `artifacts/ru-executive-package-v1/pdf/`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| PDF is 4+ pages | Margins not set to None — re-export |
| Colors are flat / washed | "Background graphics" unchecked, or Safari — use Chrome |
| Layout shifted vs browser | Scale set to "Fit to printable area" — set to 100% / Default |
| Fonts wrong | Print started before fonts loaded — wait longer, reprint |
| Rotate hint shows in PDF | Bug — should be hidden by `@media print`. Report to system maintainer |
