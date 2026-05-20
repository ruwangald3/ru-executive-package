# Custom-Domain Playbook · Buyer-Branded Share URLs

How to make any artifact accessible at `<buyer>.sparkconnected.com` instead of the raw `*.vercel.app` URL.

System designed for reuse: powi, navitas, renesas, infineon, onsemi, ti — same flow every time.

---

## 1. Architecture

```
   ship.sh push                Vercel project              DNS @ sparkconnected.com
   ────────────────            ──────────────              ───────────────────────
   artifacts/<slug>/   ─►   spark-<buyer>-bu     ◄─►    <buyer>.sparkconnected.com
                                                            CNAME → cname.vercel-dns.com
```

The buyer-domain registry at `system/domain-registry.json` is the single source of truth for buyer → subdomain → vercel-project mapping.

---

## 2. Required credentials

| Credential | Where to set | Notes |
|---|---|---|
| `VERCEL_TOKEN` | `system/.env.deploy` | Get at https://vercel.com/account/tokens. Scope: full account or the team containing your projects. |
| `VERCEL_TEAM` | `system/.env.deploy` | Only if projects live under a team. Leave blank for personal account. |
| DNS provider access | wherever `sparkconnected.com` DNS lives | See section 4. |

---

## 3. Add a custom domain for a buyer

### One-line operation

```bash
cd "[OPS] Executive Artifact Deployment System"
./system/setup-custom-domain.sh powi
```

What it does:
1. Reads buyer config from `system/domain-registry.json`.
2. POSTs to `api.vercel.com/v10/projects/<project>/domains`.
3. Parses response → `verified` / `pending-verification` / error.
4. Writes `artifacts/<artifact>/deployed/domain-status.yml`.
5. Prints the exact DNS record to add at your provider.

### What you do next

Add the printed DNS record. Wait 5–30 min. Open `https://<buyer>.sparkconnected.com`. Done.

---

## 4. Find your DNS provider for sparkconnected.com

```bash
dig +short NS sparkconnected.com
# or
nslookup -type=NS sparkconnected.com
```

| NS pattern | Provider | Dashboard |
|---|---|---|
| `*.cloudflare.com` | Cloudflare | https://dash.cloudflare.com |
| `*.googledomains.com` | Google Domains / Squarespace | https://domains.squarespace.com |
| `*.domaincontrol.com` | GoDaddy | https://dcc.godaddy.com |
| `ns1.vercel-dns.com` | Vercel DNS | https://vercel.com/dashboard/domains |
| `*.namecheap.com` | Namecheap | https://ap.www.namecheap.com |

---

## 5. DNS records — by provider

### Cloudflare

1. Dashboard → sparkconnected.com → DNS → Records.
2. Add record:
   - Type: `CNAME`
   - Name: `powi` (the prefix only, not the full domain)
   - Target: `cname.vercel-dns.com`
   - Proxy status: DNS only (gray cloud — NOT orange; Vercel handles SSL)
   - TTL: Auto
3. Save.

### GoDaddy

1. My Products → DNS → Manage Zones → sparkconnected.com.
2. Add record:
   - Type: `CNAME`
   - Name: `powi`
   - Value: `cname.vercel-dns.com`
   - TTL: 600 seconds
3. Save.

### Namecheap

1. Domain List → Manage → Advanced DNS.
2. Add new record:
   - Type: `CNAME Record`
   - Host: `powi`
   - Value: `cname.vercel-dns.com`
   - TTL: Automatic
3. Save (green check).

### Vercel DNS (if sparkconnected.com itself is on Vercel)

Automatic — adding the domain via the script also creates the DNS record. No external step needed.

### Apex domain note

For the apex (`sparkconnected.com` itself, not a subdomain), CNAMEs are not allowed by DNS spec. Use A record → `76.76.21.21`. Not needed for buyer subdomains.

---

## 6. Verification

```bash
# 1. DNS resolved?
dig +short powi.sparkconnected.com
#    expect: cname.vercel-dns.com.

# 2. Cert issued + HTTPS reachable?
curl -sI https://powi.sparkconnected.com | head -3
#    expect: HTTP/2 200

# 3. Deck loads?
open https://powi.sparkconnected.com   # macOS
start https://powi.sparkconnected.com  # Windows
```

---

## 7. Add a new buyer

Edit `system/domain-registry.json`. Add an entry:

```json
"<buyer-slug>": {
  "artifact": "<artifact-folder-name>",
  "subdomain": "<buyer-slug>.sparkconnected.com",
  "vercel_project": "spark-<buyer-slug>-bu",
  "vercel_url": "https://spark-<buyer-slug>-bu.vercel.app",
  "status": "pending-setup",
  "notes": "<engagement context>"
}
```

Then:
1. Ship the artifact via `/ship <artifact>` (creates Vercel project on first push).
2. Run `./system/setup-custom-domain.sh <buyer-slug>` to wire the domain.
3. Add CNAME at DNS provider (script tells you exactly what).

---

## 8. Per-artifact metadata schema

After the domain script runs, every artifact gets `deployed/domain-status.yml`:

| Field | Description |
|---|---|
| `buyer` | Buyer slug from registry |
| `artifact` | Artifact folder name |
| `vercel_project` | Vercel project name |
| `canonical_url` | Primary share URL (`https://powi.sparkconnected.com`) — use everywhere |
| `vercel_url` | Raw Vercel URL — backup / diagnostic |
| `custom_domain` | Bare domain |
| `setup_status` | `verified` / `pending-verification` / `error-*` / `reserved` |
| `dns_status` | `pending-propagation` / `propagated` / `failed` |
| `configured_at` | ISO timestamp |
| `dns_records_required` | Exact records to add at DNS provider |
| `vercel_response` | Raw Vercel API response (debug) |

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `403 Forbidden` from Vercel API | Token scope too narrow / wrong team | Regenerate token, set `VERCEL_TEAM` |
| `domain_already_in_use` | Attached to another Vercel project | Remove from other project in dashboard first |
| `not_found` on project | Project name in registry mismatch | Update `vercel_project` to match actual Vercel project |
| DNS not resolving after 30 min | Cloudflare proxy orange-cloud | Set to DNS-only (gray cloud) |
| `522` / `523` | Cloudflare proxy between user and Vercel | Disable proxy on CNAME |
| Cert pending forever | CNAME target wrong | Verify exactly: `cname.vercel-dns.com` |

---

## 10. Future-proofing — what this handles cleanly

- New buyer: 30 sec (registry entry + script run + one DNS record)
- Re-deploying an artifact: nothing changes; domain stays attached
- Versioning (v4 → v5): root directory swap in Vercel; same custom domain serves new version
- Multi-version share: separate Vercel project per version, sub-subdomain like `v5.powi.sparkconnected.com`

---

## 11. Security notes

- `VERCEL_TOKEN` in `.env.deploy` MUST NOT be committed (already in `.gitignore`)
- CNAME to `cname.vercel-dns.com` is safe — Vercel auto-issues SSL via Let's Encrypt
- Custom domain doesn't expose any extra attack surface vs. raw `*.vercel.app`

---

Owner: Ruwanga Dassanayake · ruwanga@sparkconnected.com
