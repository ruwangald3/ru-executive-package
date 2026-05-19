# Mobile QA Checklist — ru-executive-package-v1

Mobile-first verification. Recipients on phone shouldn't have to pinch-zoom,
drag horizontally, or see half-page rendering. The artifact must read cleanly
in the top fold.

---

## Device matrix

| Device | Viewport | Status |
|--------|----------|--------|
| iPhone 14 Pro portrait | 393 × 852 | [ ] |
| iPhone 14 Pro landscape | 852 × 393 | [ ] |
| iPhone SE portrait | 375 × 667 | [ ] |
| Pixel 7 portrait | 412 × 915 | [ ] |
| Galaxy S22 portrait | 360 × 780 | [ ] |
| iPad mini portrait | 744 × 1133 | [ ] |
| iPad portrait | 768 × 1024 | [ ] |
| iPad landscape | 1024 × 768 | [ ] |

## Required checks per device

### Layout

- [ ] No horizontal scroll
- [ ] No content clipped at right edge
- [ ] Profile photo + name + tagline all fit in first viewport
- [ ] Signal strip ($200M+ / 6–86 GHz / 10 Gbps / 65) wraps cleanly
- [ ] TI Turing flow steps stack vertically below 920px
- [ ] Timeline cards readable, logos visible
- [ ] Fit matrix cells don't truncate text mid-word
- [ ] Footer / closer block fully visible

### Typography

- [ ] Hero name reads at minimum 20px on smallest phone
- [ ] Body copy ≥ 14px effective (`font-size: 14px` set in 920px breakpoint)
- [ ] No font fallback flash (Inter loads before content paint)
- [ ] No text overflow on the Sivers fit-matrix headers

### Rotate hint

- [ ] Appears on iPhone portrait at narrow widths (≤ 480px portrait)
- [ ] Hidden on landscape
- [ ] Hidden on iPad and tablets
- [ ] Hidden in print preview / PDF

### Performance

- [ ] First contentful paint < 1.5s over 4G
- [ ] No layout shift after fonts load (Inter swaps in cleanly)
- [ ] `ti-video-thumb.jpg` (216 KB) doesn't block initial paint
- [ ] Travelling glow animations smooth on phone GPU

### Print preview from phone

- [ ] iOS Share → Print → preview shows 3-page Letter PDF
- [ ] Colors preserved
- [ ] No rotate-hint in printout

---

## How to verify in browser devtools

Chrome → DevTools → Toggle device toolbar (Ctrl/Cmd+Shift+M) → cycle each
device above. For iOS-specific checks, use Safari on a real device — Chrome
DevTools doesn't perfectly emulate iOS rendering of fixed positioning,
gradient interpolation, or print preview.

## Known design choices (intentional, not bugs)

- `.page` width is `8.5in` on desktop — this is locked to Letter print size.
  Below 920px viewport it expands to 100% — expected.
- Rotate hint appears only on narrow portrait phones — by design.
- Negative-positioned animation glows are inside `overflow: hidden` containers —
  no horizontal scroll, but visible as moving accents.

## Sign-off

- [ ] All 8 device viewports verified
- [ ] Reviewer initials: ______
- [ ] Date: ______
