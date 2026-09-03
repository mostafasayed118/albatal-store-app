# Release Next Steps — Owner Runbook

> Status after 2026-09-03 completion wave: staging fully verified through
> migration 035 + `paymob-initiate` v6, everything committed/merged to
> `master`, README portfolio-ready. What remains is **external-account
> work only** — every step below needs credentials only you hold.

---

## 1. Production cutover (Supabase) — ✅ EXECUTED 2026-09-03

Executed via authenticated Supabase CLI (v2.109.1), linked to `alxwvyflasewslinufqe`:

| Step | Result |
|---|---|
| Link | ✅ `alxwvyflasewslinufqe` |
| Migration list | ✅ prod was already at 034 (docs assumption of ≤030 was stale) |
| Dry run | ✅ exactly 035 + 036 pending |
| Backup | ✅ `outputs/db-backups/prod-pre035-036-20260903-124857.sql` (87 KB, Docker started for pg_dump) |
| `db push` | ✅ 035 + 036 applied — parity **35/35** (no pending) |
| 5 functions deploy | ✅ checkout, paymob-initiate, paymob-callback, cancel-expired-orders, send-order-notification — all ACTIVE |
| Secrets | ✅ all 10 app secrets present (names verified) |
| verify_jwt matrix | ✅ checkout+paymob-initiate=true; callback+cancel+notification=false |
| REST smoke | ✅ paymob-initiate without JWT → HTTP 401 `UNAUTHORIZED_NO_AUTH_HEADER` |

**Still open (owner, dashboard-only):**
- [ ] PITR / backups confirmation (dashboard → Database → Backups)
- [ ] SQL editor sanity: `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime';` → must include `public.payments`; `SELECT jobname, active FROM cron.job;` → 4 jobs + retention
- [ ] Paymob dashboard: repoint integration callback/redirect URLs to
      `https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback`,
      then run ONE sandbox transaction and confirm the order flips to paid automatically

Original runbook retained below for reference.

---

```bash
# 0. Link CLI to production
supabase link --project-ref alxwvyflasewslinufqe

# 1. Confirm PITR / daily backups are enabled on production (dashboard → Database → Backups)

# 2. Push pending migrations (031 … 036) — review dry-run first
supabase db push --dry-run
supabase db push
supabase migration list          # expect local/remote parity through 036

# 3. Deploy all five Edge Functions
supabase functions deploy checkout
supabase functions deploy paymob-initiate        # v6+ — atomic claim RPC
supabase functions deploy paymob-callback
supabase functions deploy cancel-expired-orders
supabase functions deploy send-order-notification

# 4. Verify secrets exist (names only)
supabase secrets list
# Required: PAYMOB_API_KEY, PAYMOB_INTEGRATION_ID, PAYMOB_HMAC_SECRET,
#           PAYMOB_IFRAME_ID, SUPABASE_SERVICE_ROLE_KEY, SCHEDULER_SECRET,
#           CORS_ALLOWED_ORIGINS, NOTIFICATIONS_INTERNAL_KEY

# 5. Realtime + cron sanity
#    SQL editor: SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime';
#    → must include public.payments
#    SQL editor: SELECT jobname, active FROM cron.job;
#    → 4 jobs + audit-retention-90d active

# 6. REST smoke: hit paymob-initiate without JWT → expect 401 UNAUTHORIZED_NO_AUTH_HEADER

# 7. Paymob dashboard: repoint integration callback/redirect URLs to
#    https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback
#    Then run ONE sandbox transaction and confirm order flips to paid
#    automatically (no manual bridge replay).
```

**Gate:** record results in `docs/evidence/prod-cutover-031-033/VERIFICATION.md`
(replace every `TBD prod`).

⚠️ Note: production DB credential was rotated on 2026-08-23 (old value
still recoverable in git history — see §4).

---

## 2. Google Play upload

Artifact status: CI (`android-release.yml`) already builds **signed AAB +
APK** on every release run — no build work needed.

- [ ] Download `release-aab` artifact from the latest green `android-release` run
- [ ] Play Console → create app `Al Batal Elite` (package `com.albatal.elite`)
- [ ] Upload AAB to **Internal testing** track first
- [ ] Store listing: app name, 2+ phone screenshots (use `docs/screenshots/home.png` as reference quality), feature graphic 1024×500, icon 512×512
- [ ] Privacy policy URL — host `DATA_POLICY.md` content on a public URL
- [ ] Data safety form: declare Supabase (email, name, phone, address), Paymob (payment tokens — collected by provider), Sentry (crash logs)
- [ ] Content rating questionnaire (e-commerce, no restricted content)
- [ ] App category: Shopping
- [ ] Roll out to internal testers → smoke-test real install → promote to production when satisfied

---

## 3. Notification delivery (deferred T4)

`send-order-notification` currently only inserts rows into
`notifications`. To make it real:

1. Create a Resend account (or any SMTP/transactional provider) → get API key
2. `supabase secrets set RESEND_API_KEY=...` on BOTH projects
3. Extend the function: after the notifications INSERT, POST to
   `https://api.resend.com/emails` with the localized template
4. Localized templates: the current 6 templates are hardcoded English —
   port them to AR/EN pairs keyed off the order's locale
5. Push notifications (FCM) remain a separate future work item

---

## 4. Git history scrub (optional, do before going fully public)

The old production DB password exists in git history (rotated 2026-08-23,
so it is dead — this is hygiene, not an incident):

```bash
# Preferred: BFG (history rewrite + force-push — COORDINATE with any clones)
java -jar bfg.jar --delete-files secrets-staging.env .
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force origin master
```

Only run when no open PRs depend on history. Requires owner approval
before force-push.

---

## 5. Remaining product backlog (post-launch)

| Item | Scope | Where |
|---|---|---|
| Reviews & ratings | `reviews` table + RLS + submit UI + moderation; products carry static seed `rating` | new migration + storefront UI |
| Coupons / promo codes | cart-level discount codes, validation RPC | new migration + checkout RPC change |
| Refunds | refund flow + Paymob refund API call | new migration + admin UI |
| Tracking number schema | `orders.payment_id` currently stores tracking number — needs a proper `tracking_number` column + RPC/UI updates | migration 037 candidate |
| Cart/wishlist/addresses cloud sync | local-first today; Supabase repos not yet written | data layer |
| FAQ + voice search | both are "coming soon" placeholders | `support_pages.dart:137`, `stitch_search_bar.dart:82` |
| Color names from DB | hardcoded color name derivation | `catalog_filters.dart:28` |
| iOS build verification | untested; needs macOS/Xcode | `ios/` |
| Web/PWA verification | unverified | `web/` |
