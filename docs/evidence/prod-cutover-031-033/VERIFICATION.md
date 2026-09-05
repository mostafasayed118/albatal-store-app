# T0 Production Cutover Dry-Run — 031·032·033 VERIFICATION

**Date:** 2026-08-24  
**Plan ref:** `docs/superpowers/plans/2026-08-24-backend-platform-plan.md` **Task 10 Steps 2–3**  
**Production project:** `alxwvyflasewslinufqe` (Supabase `alxw…` — prod, owner-gated)  
**Staging project (reference):** `zvpjngdgbpnkkqrorkul` — migrations 001–030 verified 44/44 RLS  
**Branch:** `feat/backend-platform-t0-t1` · **Base:** `f38753d`  
**Worktree:** `C:/flutter_projects/albatal-platform-t0t1`  
**Mode:** **DRY-RUN ONLY — owner-gated**. **No `supabase db push` or `supabase secrets set` was executed against `alxwvyflasewslinufqe` in this commit.** All checks below are either replayable local/staging probes or `TBD prod` placeholders to be filled when the owner runs the cutover in a separate, authorized terminal. Values (anon key, HMAC secrets) are **never recorded here**.

> **Owner-gated notice:** The actual production push (Step 2 in the plan) requires the owner to run `supabase link --project-ref alxwvyflasewslinufqe && supabase db push` plus function deploys and secret rotation from 1Password in an isolated shell. This file is the **evidence scaffold** for that run; every prod-sensitive row is marked `TBD prod` until the live run replaces it with observed output (no secret values).

---

## 1. Preconditions & Backup (PITR)

**Why:** production cutover assumes a restorable baseline before 031–033 land.

| Check | Command / Dashboard | Expected before push | Status |
|-------|---------------------|----------------------|--------|
| PITR enabled | Supabase Dashboard → `alxwvyflasewslinufqe` → Database → Backups → PITR | `Enabled` (≥7-day window) | `TBD prod` — owner to confirm screenshot |
| Latest physical backup completed | Same panel → Last backup `completed` within 24h | `completed` | `TBD prod` |
| `supabase link` preflight | `supabase link --project-ref alxwvyflasewslinufqe` (local, read-only) | `Linked` | `TBD prod` |
| Git frozen candidate | `git log --oneline -1` → `f38753d` | matches base | `PASS` — `f38753d feat(catalog+payments): … (T1+T0)` |

**Record on live run:**
```bash
# owner terminal only — read-only until this point
supabase link --project-ref alxwvyflasewslinufqe
supabase projects list   # confirm alxwvyflasewslinufqe present
# Dashboard screenshot: PITR + last backup timestamp → paste link here
```
*Status for this docs-only commit:* `PENDING owner-gated` — PITR screenshot link: `TBD prod`

---

## 2. Supabase DB Push Dry-Run — Pending 031 / 032 / 033

Per plan Task 10 Step 2: dry-run must list exactly 031, 032, 033 pending against prod (001–030 already parity through `030_batch_checkout_variants.sql`).

**Local migration parity (this worktree):**

| Migration | File | Status in worktree |
|-----------|------|--------------------|
| `031_realtime_and_cron_fix.sql` | `supabase/migrations/031_*.sql` | **pending** (created by Task 1, expected present after T0 landing) |
| `032_flash_sales_and_product_images.sql` | `supabase/migrations/032_*.sql` | **pending** (Task 2) |
| `033_admin_catalog_rpcs.sql` | `supabase/migrations/033_*.sql` | **pending** (Task 3) |

*Note:* At commit `f38753d` the local ledger is through `030_batch_checkout_variants.sql` (see `supabase/migrations/` listing). 031–033 are additive and idempotent; `config.toml` project_id already points to `alxwvyflasewslinufqe`.

**Dry-run command (owner-gated, no mutation):**

```bash
supabase link --project-ref alxwvyflasewslinufqe
supabase db push --dry-run --project-ref alxwvyflasewslinufqe
# Expected stdout (exact):
# Remote database is up to date with local migrations through 030.
# Pending migrations: 031_realtime_and_cron_fix, 032_flash_sales_and_product_images, 033_admin_catalog_rpcs
```

| Probe | Expected | Status |
|-------|----------|--------|
| `db push --dry-run` lists 3 pending | `031`, `032`, `033` only | `TBD prod` |
| No drift in 001–030 | no unexpected pending/drift | `TBD prod` |
| `supabase migration list --linked` shows `030` as high-water before push | `030` | `TBD prod` |

**Live push (owner-gated, separate terminal — NOT executed here):**

```bash
supabase db push --project-ref alxwvyflasewslinufqe
supabase migration list --linked --project-ref alxwvyflasewslinufqe  # high-water should become 033
psql "$PROD_DB_URL" -f supabase/tests/test_031_realtime_and_cron.sql
psql "$PROD_DB_URL" -f supabase/tests/test_032_flash_sales.sql
psql "$PROD_DB_URL" -f supabase/tests/test_033_admin_catalog.sql
```

*Result for this commit:* `PENDING owner-gated` — output block reserved below:

```
TBD prod — paste `supabase db push --dry-run` output here on live run (redact URL/keys)
```

---

## 3. Edge Functions Inventory — 5 ACTIVE with `verify_jwt`

Target parity from `supabase/config.toml` (`fc0b2a2` frozen + Task 10) and plan Step 2:

| Function | `verify_jwt` (config.toml) | Expected status after cutover | `ezbr_sha256` bundle digest |
|----------|----------------------------|-------------------------------|------------------------------|
| `checkout` | `true` | `ACTIVE` | `TBD prod` |
| `paymob-initiate` | `true` | `ACTIVE` | `TBD prod` |
| `paymob-callback` | `false` — HMAC verified in-function (`hmac.ts` 20-field canonical SHA-512) | `ACTIVE` | `TBD prod` |
| `cancel-expired-orders` | `false` — `x-scheduler-secret` (fallback `CANCEL_EXPIRED_ORDERS_SECRET`) | `ACTIVE` | `TBD prod` |
| `send-order-notification` | `false` — `NOTIFICATIONS_INTERNAL_KEY` (`pg_net.http_post` + FCM/Resend) | `ACTIVE` | `TBD prod` |

**Verify commands (owner terminal):**

```bash
supabase functions list --project-ref alxwvyflasewslinufqe
# Expected: 5 rows, all ACTIVE, verify_jwt per table above

# Optional per-function introspection (no secrets):
supabase functions list --project-ref alxwvyflasewslinufqe --output json | jq '.[] | {slug, verify_jwt, status}'
```

**File digests (git blob + SHA-256, recorded here as placeholders to be replaced with live `TBD prod` after deploy):**

| Source file | git blob SHA (at `f38753d`) | SHA-256 (source) | ezbr_sha256 (deployed bundle) |
|-------------|------------------------------|------------------|-------------------------------|
| `supabase/functions/_shared/cors.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/_shared/secrets.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/checkout/index.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/paymob-initiate/index.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/paymob-callback/index.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/paymob-callback/hmac.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/cancel-expired-orders/index.ts` | `TBD prod` | `TBD prod` | `TBD prod` |
| `supabase/functions/send-order-notification/index.ts` | `TBD prod` | `TBD prod` | `TBD prod` |

> Populate `ezbr_sha256` from `supabase functions list` or dashboard artifact after the owner runs `supabase functions deploy paymob-callback cancel-expired-orders --project-ref alxwvyflasewslinufqe` (and any redeploy of the other three if bundle drift is detected). Do not paste secret values. See plan Step 2 and governance closure addendum precedent in `docs/evidence/staging-deployment-2026-07-28.md` §Governance Closure.

**Deploy commands (owner-gated, only if bundle digest mismatch):**

```bash
supabase functions deploy paymob-callback --project-ref alxwvyflasewslinufqe
supabase functions deploy cancel-expired-orders --project-ref alxwvyflasewslinufqe
# checkout / paymob-initiate / send-order-notification redeploy only if their digests drift
```

*Status for this commit:* `PENDING owner-gated` — live `supabase functions list` output: `TBD prod`

---

## 4. Realtime Publication — `pg_publication_tables` (`supabase_realtime`)

**Why:** `PaymobPaymentService.watchPaymentStatus` subscribes to `public.payments` realtime; if `payments` is absent from `supabase_realtime`, card-payment status never flips without poll fallback (P0 for card payments). 031 fixes this plus `REPLICA IDENTITY FULL`.

**Expected after 031:**

```sql
-- Run via: psql "$PROD_DB_URL" -c "SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname='supabase_realtime' ORDER BY tablename;"
-- Realtime fix (031) expectations:
SELECT 'payments in publication' AS check,
  (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='payments') AS cnt; -- expect 1

SELECT 'payments replica identity' AS check,
  (SELECT relreplident FROM pg_class WHERE relname='payments') AS ri; -- expect 'f' (FULL)

-- 031 also adds support_* when those tables exist (T4):
-- supabase_realtime should contain support_messages / support_tickets after T4 migrations
```

| Check | Expected after 031 | Status |
|-------|--------------------|--------|
| `payments` in `supabase_realtime` | `count = 1` | `TBD prod` |
| `payments` `relreplident = 'f'` (FULL) | `f` | `TBD prod` |
| `config.toml [realtime] enabled = true` | `true` (already at `f38753d`) | `PASS` |

**Local file guard:** `supabase/config.toml:34-35` → `[realtime] enabled = true` — verified in worktree.

*Live evidence block (paste `psql` output on prod after push):*

```
TBD prod — SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime' (redacted host)
```

---

## 5. Cron Schedules — `cron.job` (`cancel-expired-every-5m`)

Migration 031 schedules four `pg_cron` jobs idempotently (unschedule-if-exists → schedule).

| jobname | schedule | command | Expected |
|---------|----------|---------|----------|
| `cancel-expired-every-5m` | `*/5 * * * *` | `SELECT public.expire_pending_order()` | `1` row |
| `analytics-rollup-daily` | `0 3 * * *` | `REFRESH MATERIALIZED VIEW IF EXISTS analytics_daily` | `1` row |
| `audit-retention-90d` | `0 4 * * *` | `DELETE FROM audit_logs WHERE created_at < now() - interval '90 days'` | `1` row |
| `analytics-retention-90d` | `0 4 * * *` | `DELETE FROM analytics_events WHERE created_at < now() - interval '90 days'` | `1` row |

**Verify:**

```sql
-- psql "$PROD_DB_URL"
SELECT jobname, schedule, active, command FROM cron.job ORDER BY jobname;
SELECT count(*) AS cnt FROM cron.job WHERE jobname='cancel-expired-every-5m'; -- expect 1
SELECT count(*) AS cnt FROM cron.job WHERE jobname='analytics-rollup-daily';  -- expect 1
-- Pre-031 staging gap note: was 0 before 031 (see memory: pg_cron unscheduled → cancel-expired-orders never fires)
```

| Check | Expected after 031 | Status |
|-------|--------------------|--------|
| `cancel-expired-every-5m` exists & active | `1`, `active = true` | `TBD prod` |
| Extension `pg_cron` + `pg_net` + `unaccent` present | `installed` | `TBD prod` |
| Manual kick succeeds | `SELECT expire_pending_order()` no error | `TBD prod` |

*Live evidence block:*

```
TBD prod — SELECT * FROM cron.job WHERE jobname='cancel-expired-every-5m'
```

---

## 6. Secrets Inventory — 7 names-only (no values)

**Policy:** names only, **never values**. Values live in Supabase Edge Function secrets (injected at runtime) and `config/env.production.local.json` (gitignored). See `config/README.md` and `docs/secret-hygiene-runbook.md`.

**Ratified staging scope (governance closure 2026-07-28) — 7 names:**

| # | Secret name | Required for | Present on prod (names-only probe) |
|---|-------------|--------------|-------------------------------------|
| 1 | `PAYMOB_API_KEY` | `paymob-initiate` + `paymob-callback` live | `TBD prod` |
| 2 | `PAYMOB_HMAC_SECRET` | `paymob-callback` HMAC 20-field | `TBD prod` |
| 3 | `PAYMOB_INTEGRATION_ID` | `paymob-initiate` live integration | `TBD prod` |
| 4 | `PAYMOB_IFRAME_ID` | `paymob-initiate` checkout URL (live iframe) | `TBD prod` |
| 5 | `CORS_ALLOWED_ORIGINS` | `_shared/cors.ts` fail-closed gate (`https://albatal.app`) | `TBD prod` |
| 6 | `SCHEDULER_SECRET` (fallback `CANCEL_EXPIRED_ORDERS_SECRET`) | `cancel-expired-orders` `x-scheduler-secret` | `TBD prod` |
| 7 | `NOTIFICATIONS_INTERNAL_KEY` | `send-order-notification` | `TBD prod` |

**Prod-extended set (if FCM/Resend cut over in same window — record as present/absent, still names-only):**

| # | Secret name | Status |
|---|-------------|--------|
| 8 | `FCM_SERVICE_ACCOUNT_JSON` | `TBD prod` (deferred to T4 if not yet) |
| 9 | `RESEND_API_KEY` | `TBD prod` (deferred to T4 if not yet) |
| 10 | `SUPABASE_SERVICE_ROLE_KEY` | platform-injected — not set by owner |

**Verify (names only):**

```bash
supabase secrets list --project-ref alxwvyflasewslinufqe
# Expected: the 7 names above appear (keys redacted by CLI). Do NOT run `secrets get`.
```

*Live evidence (paste `secrets list` keys only, redact values):*

```
TBD prod — supabase secrets list --project-ref alxwvyflasewslinufqe (names only)
```

**Rotation note:** `config/env.production.json` stays at placeholders (`REPLACE_WITH_*`) in git. Owner fills `config/env.production.local.json` locally from 1Password — never commit real `SUPABASE_URL`/`SUPABASE_ANON_KEY` to this repo (history check at `config/README.md`).

---

## 7. REST Smoke — `curl` anon `products` select

**Why:** RLS-safe anon read must succeed after 031–033; verifies PostgREST + RLS + anon key plumbing without exposing secrets.

**Command (owner terminal, uses prod anon key from 1Password — do not paste key here):**

```bash
# Do not echo $PROD_ANON — export it locally only
curl -s -H "apikey: $PROD_ANON" \
     -H "Authorization: Bearer $PROD_ANON" \
     "https://alxwvyflasewslinufqe.supabase.co/rest/v1/products?select=id&limit=1" \
  | jq 'length'

# Expected: 0 or 1 (depends on seed), but HTTP 200 with JSON array (not 401/403)
# Also probe product_images embed (post-032):
curl -s -H "apikey: $PROD_ANON" \
     -H "Authorization: Bearer $PROD_ANON" \
     "https://alxwvyflasewslinufqe.supabase.co/rest/v1/products?select=id,product_images(storage_path,sort_order)&limit=1" \
  | jq '.'

# And anon flash sales read (post-032/033):
curl -s -H "apikey: $PROD_ANON" \
     -H "Authorization: Bearer $PROD_ANON" \
     "https://alxwvyflasewslinufqe.supabase.co/rest/v1/flash_sales?select=*&limit=1" \
  | jq '.'
# Or via RPC (post-033):
curl -s -X POST -H "apikey: $PROD_ANON" -H "Authorization: Bearer $PROD_ANON" -H "Content-Type: application/json" \
     "https://alxwvyflasewslinufqe.supabase.co/rest/v1/rpc/get_active_flash_sales" \
     -d '{}' | jq '.'
```

| Probe | Expected HTTP | Status |
|-------|---------------|--------|
| `GET /rest/v1/products?select=id&limit=1` as anon | `200` JSON array | `TBD prod` |
| `GET` with `product_images` embed | `200` | `TBD prod` |
| `GET /flash_sales` or `POST /rpc/get_active_flash_sales` as anon | `200` (active-window filtered, may be `[]` if no active sale) | `TBD prod` |
| `GET` as missing/incorrect apikey | `401` | `TBD prod` (negative) |

*Live evidence block:*

```
TBD prod — curl -H "apikey: $PROD_ANON" …/products?select=id | jq length  →  HTTP 200, body length: __
```

---

## 8. Live Paymob Smoke — TODO owner-gated

> **TODO (owner-gated):** A live Paymob card smoke on **production** (`alxwvyflasewslinufqe`) flips `orders.status → paid` and `payments.status → success` via the real Paymob approval flow. **Do not run from this docs-only worktree.** This section is a placeholder for the authorized production smoke; staging already proved the flow (`521080502` APPROVED, Paymob F1–F4 21/21) per spec §7.

**When the owner authorizes the live smoke (separate session, real card or Paymob test card `5123456789012346` / `12/30` / `123` on the live iframe per memory guidance — only if the live integration is in sandbox mode):**

```bash
# 1. Create a checkout order as an authenticated user (order in pending-payment)
#    via the app or: psql with auth.uid() context / authenticated curl to create_checkout_order
# 2. Call paymob-initiate → get checkout_url
# 3. Complete card with 3DS → expect APPROVED
# 4. Observe Paymob server POST → paymob-callback flips payment (verify via DB/poll/realtime)
#    Paymob "Transaction processed callback" (server POST) must be set to:
#    https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback
#    "Transaction response callback" (browser GET) is separate and handled with dotted→flat key flattening
```

| Check | Probe | Expected | Status |
|-------|-------|----------|--------|
| Paymob callback HMAC canonical (20 fields, SHA-512) | forged-HMAC probe → `{"message":"Invalid signature"}` (not JWT 401) | `Invalid signature` from function HMAC layer | `TODO prod` |
| Live card approval | complete card → `payments.status = 'success'`, `orders.status = 'paid'` without manual replay | `success` / `paid` | `TODO prod` |
| Realtime payment status | `PaymobPaymentService.watchPaymentStatus` UPDATE `filter order_id=eq.X` fires (or 45s poll fallback) | realtime emitted | `TODO prod` |
| Duplicate/idempotency | replay same Paymob txn → no duplicate `payments` row | idempotent | `TODO prod` |

*Live evidence block (to be filled after authorized prod smoke, transaction IDs redacted except last 4):*

```
TODO owner-gated — no live Paymob transaction was executed in this dry-run commit.
On live run, paste: provider_txn_id, paymob_order_id (last 4), HMAC verification result, order_id → paid timestamp
```

---

## 9. Artifact Digests — `ezbr_sha256` `TBD prod`

Per governance closure precedent (`docs/evidence/staging-deployment-2026-07-28.md` §Governance Closure Addendum), every function deployment must be pinned by both git blob and `ezbr_sha256` bundle digest. This commit lands **no bundle**; digests below are placeholders.

```
TBD prod — run after owner deploys functions:
  for fn in checkout paymob-initiate paymob-callback cancel-expired-orders send-order-notification; do
    echo "--- $fn ---"
    supabase functions list --project-ref alxwvyflasewslinufqe | grep "$fn"
    # or dashboard → Edge Functions → $fn → bundle sha
  done
```

| Function | git blob @ `f38753d` | SHA-256 source | ezbr_sha256 deployed |
|----------|----------------------|----------------|----------------------|
| `checkout` | `TBD prod` | `TBD prod` | `TBD prod` |
| `paymob-initiate` | `TBD prod` | `TBD prod` | `TBD prod` |
| `paymob-callback` | `TBD prod` | `TBD prod` | `TBD prod` |
| `cancel-expired-orders` | `TBD prod` | `TBD prod` | `TBD prod` |
| `send-order-notification` | `TBD prod` | `TBD prod` | `TBD prod` |

*Source SHA-256 fill on live run (owner shell, no secrets):*

```bash
sha256sum supabase/functions/*/index.ts supabase/functions/_shared/*.ts supabase/functions/paymob-callback/hmac.ts
git ls-files -s supabase/functions | awk '{print $2, $4}'
```

---

## 10. Execution Notes & Sign-Off

- [ ] PITR + latest backup screenshot captured for `alxwvyflasewslinufqe` — `TBD prod`
- [ ] `supabase db push --dry-run` showed `031, 032, 033` pending — `TBD prod`
- [ ] `supabase db push` applied `031–033` — `TBD prod` (paste `migration list --linked` after)
- [ ] `supabase/tests/test_031*_*.sql` → `PASS` on prod — `TBD prod`
- [ ] `test_032_flash_sales.sql` → `PASS` — `TBD prod`
- [ ] `test_033_admin_catalog.sql` → `PASS` (anon `not_admin`, admin happy path) — `TBD prod`
- [ ] Functions list: 5 ACTIVE, `verify_jwt` per §3 — `TBD prod`
- [ ] `pg_publication_tables` → `payments` count 1, `relreplident f` — `TBD prod`
- [ ] `cron.job` → `cancel-expired-every-5m` count 1 — `TBD prod`
- [ ] `supabase secrets list` → 7 names present (values never logged) — `TBD prod`
- [ ] `curl` anon `products` → HTTP 200 — `TBD prod`
- [ ] Paymob live smoke → `TODO owner-gated` (section 8)
- [ ] Digests (`ezbr_sha256`) pinned — `TBD prod`

**Cutover executor (owner):** _TBD prod — name / date / approval ref_  
**Evidence file:** `docs/evidence/prod-cutover-031-033/VERIFICATION.md` (this file) — dry-run scaffold landed at `f38753d` + this commit; live `TBD prod` rows to be filled in a follow-up docs commit after the authorized prod run.  
**Follow-up commit:** after live run, amend this file in place and commit `docs(release): T0 production cutover evidence 031-033 — live fill` with the same path (no new file).

**Actual prod push is owner-gated — no mutation was performed by this `docs(release)` commit.**
