# Ruwanga Dassanayake — Executive Positioning Packet

Three-page responsive HTML packet prepared for **Sivers Wireless / Sivers Semiconductors**, MD/GM — Wireless Business.

- **Page 1** · Technical Credibility — Identity, core strategic signal, TI Turing Phase 1 platform definition
- **Page 2** · Operator Scale — 20-year semiconductor leadership timeline with impact metrics per company
- **Page 3** · Why Sivers — Sivers Needs × Ruwanga Signal × Proof fit matrix + CEO positioning close

Built as a static site — no build step, no dependencies. Drop the folder anywhere that serves static files.

---

## Files

```
.
├── index.html              # The packet (3 sections, one document)
├── styles.css              # All styling, motion, and print rules
├── vercel.json             # Vercel routing + cache headers (optional)
├── assets/
│   ├── profile.jpg         # Headshot
│   ├── ti-video-thumb.jpg  # ti.com video thumbnail (page 1)
│   ├── ti.png              # Texas Instruments
│   ├── spark.png           # Spark Connected
│   ├── semtech.png         # Semtech
│   ├── nokia.png           # Nokia
│   ├── siemens.png         # Siemens
│   ├── ai-engage.png       # AI Engage (board advisory)
│   └── filps.png           # Filps (board advisory)
└── README.md               # This file
```

Previous design iterations preserved in the project as `Resume Packet v1.html` … `v4.html` — these can be deleted before deploying if you only want the final.

---

## Deploy to Vercel — durable shareable link

You have three options. **Option A (drag-and-drop)** is the fastest.

### Option A · Drag-and-drop the folder onto Vercel

1. Go to https://vercel.com/new
2. Sign in (GitHub, Google, or email)
3. Click **"Import / Add New… → Project"**, then in the upload box drag this whole folder in
4. Project name: `ruwanga-dassanayake-sivers` (or whatever you like)
5. Framework Preset: **Other** (Vercel will detect plain HTML)
6. Build & Output Settings: leave blank (no build step)
7. Click **Deploy**

You'll get a URL like `https://ruwanga-dassanayake-sivers.vercel.app` within ~20 seconds. That is the **durable shareable link** — it lives until you delete the project. Send that URL to recruiters / Vickram / executive search.

### Option B · Vercel CLI (one command)

```bash
npm i -g vercel          # one-time install
cd /path/to/this/folder
vercel                   # follow the prompts; press Enter for all defaults
vercel --prod            # promote the preview to a production URL
```

The first `vercel` gives you a preview URL. `vercel --prod` aliases it onto your durable production domain.

### Option C · GitHub → Vercel auto-deploy

1. Push this folder to a GitHub repo (`gh repo create … --public --source=. --push`)
2. On https://vercel.com/new, import the repo
3. Click Deploy — every future push redeploys automatically

### Custom domain (optional)

In your Vercel project: **Settings → Domains → Add**. Point your DNS at Vercel and you can serve this packet from `resume.ruwanga.com` or similar.

---

## Generate the print-ready PDF

The HTML is print-tuned. Each section is a Letter page that page-breaks cleanly, with `print-color-adjust: exact` so the dark navy panels and accent details render in the PDF.

### Chrome / Edge / Brave (best output)

1. Open `index.html` (locally or your live URL)
2. **Cmd-P** (Mac) or **Ctrl-P** (Windows / Linux)
3. **Destination:** Save as PDF
4. **Pages:** All
5. **Layout:** Portrait
6. **Paper size:** Letter (8.5 × 11 in)
7. **Margins:** **None**
8. **Scale:** **100%** (or "Default")
9. **More settings → Background graphics: ON** ← critical, otherwise the dark panels print white
10. **Save** → `Ruwanga_Dassanayake_Sivers.pdf`

You'll get exactly **3 pages**, no clipping, all logos/photos preserved.

### Safari

File → Export as PDF — Safari respects `@page Letter; margin: 0;` and prints background colors by default.

### Firefox

Hamburger → Print → Page Setup → tick **"Print backgrounds"** before saving.

---

## Final QA Checklist

Verified before packaging:

| Check                                              | Status |
| -------------------------------------------------- | ------ |
| Three pages render at exactly 8.5 × 11 in (816 × 1056 px) | ✅      |
| Zero internal overflow on any page                 | ✅      |
| No horizontal scrollbar at desktop / iPad / iPhone widths | ✅      |
| Mobile (≤ 920 px): pages collapse to single column, full-width visibility | ✅      |
| Phone (≤ 480 px): signal-strip metrics wrap 2 × 2  | ✅      |
| All logos & headshot present and crisp             | ✅      |
| PDF export = exactly 3 clean pages, no cuts        | ✅      |
| Dark navy panels + accent stripes render in PDF (with backgrounds ON) | ✅      |
| No header/footer overlap on any page               | ✅      |
| Motion respects `prefers-reduced-motion`           | ✅      |
| Motion frozen at final state during print          | ✅      |
| TI video link points to https://www.ti.com/video/3881562064001 | ✅      |
| No "pre-silicon" text anywhere                     | ✅      |

---

## Design system (for reference)

- **Type:** Inter (display) + JetBrains Mono (metrics, labels, eyebrows)
- **Ink:** `#08131f` dark navy / charcoal
- **Paper:** `#ffffff` / `#f6f8fb` cool-neutral
- **Accent:** `#2563eb` electric blue / `#14b8a6` teal (used sparingly)
- **Motion:** subtle fade-up on enter, travelling glow on Page 1 process flow, vertical rail-fill on Page 2 timeline, row-sweep on Page 3 fit matrix

---

## Contact

**Ruwanga Dassanayake**
+1 (214) 235-5325 · ruwangald3@gmail.com · linkedin.com/in/ruwanga
Dallas, TX · open to Silicon Valley relocation
