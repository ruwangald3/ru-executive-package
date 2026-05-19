# Post-Deploy Checklist — ru-executive-package-v1

Run this after every Vercel deploy. Block external sharing until every item is checked.

---

## 1. Live URL health

- [ ] Production URL returns HTTP 200 (`curl -I <url>`)
- [ ] Live URL matches `deployed/deployment-notes.txt`
- [ ] No mixed-content warnings in browser devtools
- [ ] Inter + JetBrains Mono fonts load (verify in Network tab)
- [ ] All 7 referenced images return 200 (no broken thumbnails)
- [ ] `vercel.json` cache headers applied (check `Cache-Control` on `/assets/profile.jpg`)

## 2. Visual fidelity — desktop

- [ ] 1440 × 900 — full layout renders cleanly, no horizontal scroll
- [ ] 1366 × 768 — Page 1 hero + TI Turing flow still in one viewport
- [ ] All three pages stack vertically with consistent margins
- [ ] No text clipped at right edge of `.page` (8.5in container)
- [ ] TI logo, all timeline company logos render crisply (no blur or stretch)
- [ ] Travelling glow animation runs (not janky)

## 3. Visual fidelity — tablet

- [ ] iPad portrait (768 × 1024) — `.page` switches to 100% width below 920px
- [ ] iPad landscape (1024 × 768) — desktop layout, all three pages legible
- [ ] No card overflow on signal strip / fit matrix
- [ ] Profile photo + identity block scale together (not detached)

## 4. Visual fidelity — phone

- [ ] iPhone portrait (390 × 844) — rotate-hint may appear briefly, single column
- [ ] iPhone landscape (844 × 390) — full desktop-ish layout, no half-page render
- [ ] No horizontal scroll on any narrow viewport
- [ ] Hero name uses `clamp(20px, 5.6vw, 26px)` — readable, doesn't overflow

## 5. Print / PDF export

- [ ] Chrome → Print → Save as PDF → Letter, no margins
- [ ] Exactly 3 pages output (one per `.page` div)
- [ ] Page-break-after applied correctly (no orphans / widows across pages)
- [ ] Colors preserved (print-color-adjust: exact in effect)
- [ ] Rotate-hint NOT visible in PDF
- [ ] Background gradients / accent colors visible

## 6. Shareability

- [ ] URL copy/paste into LinkedIn DM previews cleanly (Open Graph not required for this artifact but check)
- [ ] URL behaves identically over cellular vs WiFi
- [ ] No "site is not configured" Vercel placeholder
- [ ] Production alias matches the artifact name (not a hash-only URL)

## 7. Operational

- [ ] `deployed/deployment-notes.txt` updated with final URL
- [ ] PDF exported and saved to `pdf/ru-executive-package-v1.pdf`
- [ ] Screenshot of mobile view saved to `screenshots/`
- [ ] If you intend to revise, archive this version first:
      `./system/archive.sh artifacts/ru-executive-package-v1 v2-<note>`

---

## Sign-off

- [ ] Reviewer initials: ______
- [ ] Date: ______
- [ ] Approved for external send to Sivers
