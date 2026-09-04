# Al Batal Elite — Backend Platform Design (Full Commerce — Option C)

**Date:** 2026-08-24
**Author:** brainstorming (solo-owner: Mustafa Sayed)
**Status:** Approved — ready for `writing-plans`
**Candidate refs:** frozen `fc0b2a2` / staging `ac69c54` on project `zvpjngdgbpnkkqrorkul` (eu-west-1); production `alxwvyflasewslinufqe` (to be promoted)
**Related gate:** `docs/RELEASE_GATE.md` GO `RELEASE-AC69C54-2026-08-24` (all technical gates PASS: RLS 44/44, races 53/53, COD 14/14, Paymob F1–F4 21/21 incl. live auto-callback `521080502`, Sentry `1ef12b03…` confirmed)

---

## 1. Goal & Non-Goals

**Goal:** turn the proven staging backend into a production commerce platform a solo owner can run from the app, then layer growth backends without re-architecting.

**In scope (C):**
- T0 hardened production cutover,
- T1 admin catalog + media + flash sales,
- T2 server search,
- T3 promotions/coupons/loyalty + reviews,
- T4 notifications (FCM + email) + support ticketing,
- T5 intelligence (audit, analytics), recommendations, multi-warehouse.

**Non-goals:**
- Native iOS/Android code — Flutter-first per `INSTRUCTIONS.md §B`.
- Replacing Supabase Auth/RLS with custom auth.
- External search vendor unless `pg_trgm` p95 > 80 ms at 10k SKUs.
- ML recommendation service in v1 — co-occurrence matview only.

**Success criteria:**
- Prod DB/Functions parity with staging 031, PITR enabled, Paymob live `APPROVED` flips `paid`/`success` without manual replay.
- Owner can create/edit products, variants, images, flash sales from `/admin/catalog` with no SQL.
- `search_products` p95 < 120 ms on seeded catalog, client-side filter removed for online path.
- Coupon applied server-side in `create_checkout_order` pricing; loyalty accrues on `delivered`.
- Order status transitions trigger FCM + email via `send-order-notification`; support tickets realtime.
- `analytics_daily` + `audit_logs` queryable; warehouse stock extensions backward-compatible.

---

## 2. Architecture & Decomposition

### 2.1 Platform posture

- Postgres is source of truth. PostgREST + `SECURITY DEFINER` RPCs are the only data surface. Edge Functions own Paymob + webhooks + fan-out. Realtime owns payment status + ticket messages. `pg_cron` owns expiry/rollups/retention. FCM (HTTP v1) + Resend own delivery.
- Clean Architecture preserved: `features/*/presentation → domain (Repository interface) → data (Supabase*Repository / Service)` via `lib/shared/services/service_locator.dart`. No widget or cubit touches Supabase directly.

### 2.2 Tracks (each is its own spec → plan → PR)

| Track | Name | Depends on | What it delivers | Est. |
|-------|------|------------|------------------|------|
| T0 | Hardened Production Cutover | — | Prod parity, PITR, cron, prod secrets/CORS, Paymob live cutover | 1–2d |
| T1 | Admin Catalog & Media | T0 | `admin_upsert_*`, `product_images` wiring, `flash_sales`, `StorageService` hardening | 3–4d |
| T2 | Search & Discovery | T1 | `search_products` FTS + trigram, GIN indexes | 2–3d |
| T3 | Promotions/Loyalty/Reviews | T1 | `coupons`, `promotions`, `loyalty_ledger`, `product_reviews`, pricing in checkout | 4–5d |
| T4 | Notifications + Support | T0 | `send-order-notification` rebuild (FCM+email), `support_tickets`/`messages` + realtime | 3–4d |
| T5 | Intelligence & Scale | T1–T4 | `audit_logs`, `analytics_events` rollups, co-occurrence matview, `warehouses` | 3–4d |

Order: **T0 → T1 → T2 → T3 ∥ T4 → T5**. First plan implements T0+T1.

### 2.3 Cross-cutting invariants

- RLS is the trust boundary; anon key is public. Write RPCs are `SECURITY DEFINER SET search_path=public,pg_temp` and authenticate via `auth.uid()` reading `request.jwt.claim.sub` (never `request.jwt.claims`). `STAGING_DB_URL`-guarded runners enforce staging-only mutation (proven 6/6).
- `payments` retains zero public INSERT policy (removed in 028). `paymob-callback` HMAC 20-field canonical (`supabase/functions/paymob-callback/hmac.ts`) is frozen; any field change bumps tests.
- Idempotency: `(user_id, idempotency_key)` on checkout, `(coupon_code, order_id)` on coupons, `(ticket_id, created_at)` ordering on messages.
- Price is server-authoritative — client never sends totals; `create_checkout_order` extension keeps invariant.

---

## 3. Data Model

All new tables: `id UUID PK DEFAULT gen_random_uuid()`, `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at` trigger, `ENABLE ROW LEVEL SECURITY`, explicit `GRANT`s, `IF NOT EXISTS` guards.

### 3.1 T1 — Admin Catalog & Media

```sql
-- Flash sales — replaces home_page.dart:36 client-side DateTime.now()+2h placeholder
CREATE TABLE flash_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  discount_pct INT NOT NULL CHECK (discount_pct BETWEEN 1 AND 90),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL CHECK (ends_at > starts_at),
  is_active BOOL NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX flash_sales_active_window ON flash_sales (ends_at) WHERE is_active;
-- RLS: SELECT anon/authenticated WHERE is_active AND now() BETWEEN starts_at AND ends_at; writes admin-only via RPC.

-- Product images wiring — table+bucket exist (001/005) but SupabaseCatalogRepository never embeds them
CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL UNIQUE CHECK (storage_path LIKE 'product-images/%'),
  sort_order INT NOT NULL DEFAULT 0,
  alt_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX product_images_product_sort ON product_images (product_id, sort_order);
-- Bucket product-images: public READ; admin-only INSERT/DELETE with prefix product-images/{product_id}/*
Storage: tighten 005 policies — drop permissive admin ALL; add 3 scoped policies (public SELECT `USING true`; admin INSERT/DELETE `USING is_admin()` + prefix check). `StorageService` wired into `getIt` (today unwired). Flash sale discount is computed at read time (`base_price * (1 - discount_pct/100.0)`) — `products.base_price` stays canonical, no stored discounted price.


### 3.2 T2 — Search

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

ALTER TABLE products ADD COLUMN IF NOT EXISTS search_vector TSVECTOR;
CREATE OR REPLACE FUNCTION products_search_vector_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.search_vector := to_tsvector('english', unaccent(coalesce(NEW.name,'')||' '||coalesce(NEW.description,'')||' '||coalesce(NEW.composition,''))); RETURN NEW; END $$;
DROP TRIGGER IF EXISTS trg_products_search_vector ON products;
CREATE TRIGGER trg_products_search_vector BEFORE INSERT OR UPDATE OF name, description, composition ON products
  FOR EACH ROW EXECUTE FUNCTION products_search_vector_update();
CREATE INDEX IF NOT EXISTS products_search_vector_gin ON products USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS products_name_trgm ON products USING GIN (name gin_trgm_ops);
```

### 3.3 T3 — Promotions / Loyalty / Reviews

CREATE TABLE coupons (
  code TEXT PRIMARY KEY,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('pct','fixed')),
  discount_value NUMERIC NOT NULL CHECK (discount_value > 0),
  -- pct: 1–100 (percent of subtotal); fixed: EGP amount (e.g. 50.00 = 50 EGP off)
  min_order NUMERIC NOT NULL DEFAULT 0,
  max_uses INT, used_count INT NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ, is_active BOOL NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE coupon_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_code TEXT NOT NULL REFERENCES coupons(code),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  order_id UUID NOT NULL REFERENCES orders(id),
  redeemed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (coupon_code, order_id)
);
CREATE TABLE promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL, discount_pct INT CHECK (discount_pct BETWEEN 1 AND 90),
  product_ids UUID[] , category TEXT,
  starts_at TIMESTAMPTZ NOT NULL, ends_at TIMESTAMPTZ NOT NULL, is_active BOOL DEFAULT true
);
CREATE INDEX promotions_product_ids_gin ON promotions USING GIN (product_ids);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS loyalty_points INT NOT NULL DEFAULT 0;
CREATE TABLE loyalty_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  order_id UUID REFERENCES orders(id),
  points INT NOT NULL, reason TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX loyalty_ledger_user ON loyalty_ledger (user_id, created_at DESC);

CREATE TABLE product_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  order_id UUID NOT NULL REFERENCES orders(id),
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body TEXT, is_approved BOOL NOT NULL DEFAULT false, created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (product_id, order_id)
);
CREATE INDEX product_reviews_approved ON product_reviews (product_id, is_approved, created_at DESC);
-- RLS: reviews SELECT anon/auth WHERE is_approved; INSERT via submit_review RPC only.
```

`create_checkout_order` signature extended: `p_coupon_code TEXT DEFAULT NULL` — pricing stays server-side; coupon consumption atomic via `coupon_redemptions` unique.

### 3.4 T4 — Support Ticketing

```sql
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  subject TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('open','pending','closed')) DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  sender_role TEXT NOT NULL CHECK (sender_role IN ('user','admin')),
  body TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX support_tickets_user_status ON support_tickets (user_id, status, created_at DESC);
CREATE INDEX support_messages_ticket_time ON support_messages (ticket_id, created_at);
-- RLS: user sees own tickets/messages; admin sees all; writes via RPC to enforce sender_role.
```

Notifications: reuse `notifications` (010) add `channel TEXT CHECK ('push','email')`, `payload JSONB`, `sent_at`.

### 3.5 T5 — Audit / Analytics / Warehouses

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL, entity TEXT NOT NULL, entity_id UUID,
  old_row JSONB, new_row JSONB, created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX audit_logs_entity ON audit_logs (entity, entity_id, created_at DESC);
-- Trigger audit_if_needed() on orders, order_items, products, product_variants, coupons.

CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  event_name TEXT NOT NULL, props JSONB, created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX analytics_events_name_time ON analytics_events USING BRIN (created_at);
-- Matview analytics_daily(event_name, day, count) refreshed by pg_cron.

CREATE TABLE warehouses (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, code TEXT UNIQUE NOT NULL, address JSONB);
CREATE TABLE warehouse_stock (
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE CASCADE,
  product_variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
  stock INT NOT NULL CHECK (stock >= 0), PRIMARY KEY (warehouse_id, product_variant_id)
);
-- Decrement/increment RPCs extended with p_warehouse_id UUID DEFAULT NULL (primary warehouse when null).
```

Retention: `pg_cron` deletes `analytics_events`/`audit_logs` where `created_at < now() - interval '90 days'` (90d policy).

### 3.6 Fixes for audit-found gaps

- Add `payments` to `supabase_realtime` publication (see §5) with `REPLICA IDENTITY FULL` — otherwise `PaymobPaymentService.watchPaymentStatus` is dead.
- Same publication add for `support_messages`, `support_tickets`.

---

## 4. RPCs & Edge Functions

### 4.1 RPCs

All `SECURITY DEFINER SET search_path=public,pg_temp`, `REVOKE FROM PUBLIC, anon`, `GRANT EXECUTE TO authenticated` (admin-checked inside) except where noted.

| RPC | Auth | Returns | Notes |
|-----|------|---------|-------|
| `admin_upsert_product(p_id, p_name, p_slug, p_description, p_composition, p_category_id, p_base_price, p_is_active)` | admin-only | `UUID` | `assert_admin()` helper `RAISE EXCEPTION 'not_admin' (code 42501)` |
| `admin_upsert_variant(p_product_id, p_size, p_color, p_stock, p_price_override)` | admin-only | `UUID` | validates product exists |
| `admin_set_product_images(p_product_id, p_paths TEXT[])` | admin-only | `void` | transactional delete+insert, prefix check |
| `get_active_flash_sales()` | `anon, authenticated` | `SETOF flash_sales` | `STABLE`, window filter |
| `search_products(p_query, p_category, p_price_min, p_price_max, p_sort, p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)` | `anon, authenticated` | `SETOF products` | `ts_rank` + trigram fallback for `char_length(p_query)<3`; `p_sort` enum `'relevance'|'price_asc'|'price_desc'|'newest'|'rating'`; returns `rank` + `total_count` |
| `apply_coupon(p_code, p_order_id)` | `authenticated` | `JSONB {ok, discount_amount, new_total}` | checks window/uses/dedup/min_order |
| `submit_review(p_product_id, p_order_id, p_rating, p_body)` | `authenticated` | `UUID` | requires `orders.status='delivered'` + contains product |
| `create_ticket(p_subject, p_body)` | `authenticated` | `UUID` | creates ticket + first message |
| `post_message(p_ticket_id, p_body)` | `authenticated` | `UUID` | enforces `sender_role` server-side |
| `list_my_tickets()` / `admin_list_tickets(p_status)` | `authenticated` / admin | `SETOF` | RLS second line |
| `record_analytics(p_event, p_props)` | `authenticated` | `void` | thin write |
| `get_analytics_daily(p_days)` | admin-only | `SETOF analytics_daily` |  |

`create_checkout_order` extended with `p_coupon_code TEXT DEFAULT NULL`; `decrement_stock`/`increment_stock` extended with `p_warehouse_id UUID DEFAULT NULL`.

### 4.2 Edge Functions (Deno, reuse `_shared/secrets.ts` + `cors.ts`)

| Function | `verify_jwt` | Trigger | Behavior |
|----------|--------------|---------|----------|
| `paymob-initiate` | `true` | Flutter `PaymobPaymentService` | unchanged — persists `paymob_order_id` before returning `checkout_url` |
| `paymob-callback` | `false` | Paymob server POST + browser GET | frozen 20-field HMAC + shape-aware extraction; no change except publication fix is DB-side |
| `checkout` | `true` | legacy | retained deprecated wrapper over `create_checkout_order` for rollout safety |
| `cancel-expired-orders` | `false` (`x-scheduler-secret`) | `pg_cron` every 5m | calls `expire_pending_order()` per expired pending order; today never fires — migration 031 schedules it |
| `send-order-notification` | `false` (`NOTIFICATIONS_INTERNAL_KEY`) | DB trigger via `pg_net.http_post` on `orders.status` change | rebuild: fan-out to FCM HTTP v1 + Resend email + audit `notifications` row. Today only inserts `notifications status='sent'` and has zero callers |
| `analytics-ingest` (new, optional) | `true` | batch client analytics | thin wrapper over `record_analytics` if direct RPC path not desired |

Secrets (prod): `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID` (new live iframe), `CORS_ALLOWED_ORIGINS=https://albatal.app`, `NOTIFICATIONS_INTERNAL_KEY`, `SCHEDULER_SECRET`, `FCM_SERVICE_ACCOUNT_JSON`, `RESEND_API_KEY`. (`CANCEL_EXPIRED_ORDERS_SECRET` retained as fallback alias for `SCHEDULER_SECRET`.)

---

## 5. Storage & Realtime

### 5.1 Storage hardening

- Bucket `product-images`: public `SELECT USING true`; admin-only `INSERT/DELETE` with `storage_path LIKE 'product-images/' || product_id || '/%'` prefix guard.
- Upload: `StorageService.uploadProductImage(productId, file)` → `product-images/{productId}/{uuid}.{ext}` `upsert:false` then `admin_set_product_images` to register. `getPublicUrl` with `Cache-Control: public, max-age=31536000, immutable`.
- Frontend: `SupabaseCatalogRepository` `select('*, categories!inner(...), product_variants(...), product_images(storage_path, sort_order)')` ordered by `sort_order`; map to `product.imageUrls` via `storage.getPublicUrl`; fallback placeholder color only when `product_images` empty. Register `StorageService` in `getIt`.

### 5.2 Realtime fix (P0 for card payments)

```sql
-- Migration 031 — idempotent
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='payments') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
  END IF;
END $$;
ALTER TABLE public.payments REPLICA IDENTITY FULL;
-- same for support_messages, support_tickets
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
ALTER TABLE public.support_messages REPLICA IDENTITY FULL;
```

`config.toml [realtime] enabled=true` already correct. `PaymobPaymentService.watchPaymentStatus` keeps `postgres_changes` on `public.payments` `UPDATE filter order_id=eq.X` but adds 45s timeout fallback doing `from('payments').select('status').eq('order_id', orderId).single()` if realtime never fires (covers publication propagation delay).

---

## 6. Security, Cron & Production Cutover

### 6.1 Security

- New tables RLS `ENABLE`, policies narrow (`USING`/`WITH CHECK` admin or owner). All write RPCs `SECURITY DEFINER`, revoked from `PUBLIC/anon`, `search_path` locked.
- `CONFIRM_COD` pattern (`auth.uid()` via `request.jwt.claim.sub`) reused for all new state-changing RPCs.
- `paymob-callback` HMAC canonical untouched; `cors.ts` fail-closed (`CORS_ALLOWED_ORIGINS` missing → 500) preserved.
- `audit_logs` trigger `audit_if_needed()` on `orders/order_items/products/product_variants/coupons`; admin read-only.

### 6.2 Cron

Requires `pg_cron` + `pg_net` (enable via dashboard). Migration 031:

```sql
SELECT cron.schedule('cancel-expired-every-5m', '*/5 * * * *', $$SELECT public.expire_pending_order()$$);
SELECT cron.schedule('analytics-rollup-daily', '0 3 * * *', $$REFRESH MATERIALIZED VIEW analytics_daily$$);
SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $$DELETE FROM audit_logs WHERE created_at < now() - interval '90 days'$$);
SELECT cron.schedule('analytics-retention-90d', '0 4 * * *', $$DELETE FROM analytics_events WHERE created_at < now() - interval '90 days'$$);
```

Verify `SELECT * FROM cron.job`.

### 6.3 Production cutover runbook (T0)

1. Backup prod `alxwvyflasewslinufqe`: `supabase db dump --linked --role postgres`, enable PITR in dashboard.
2. Link prod: `supabase link --project-ref alxwvyflasewslinufqe` → `supabase db push` (dry-run, then apply 014–031). Verify `SELECT * FROM supabase_migrations.schema_migrations ORDER BY version` = 31.
3. Deploy functions: `supabase functions deploy checkout paymob-initiate paymob-callback cancel-expired-orders send-order-notification analytics-ingest --project-ref alxw...` capture `ezbr_sha256`.
4. Secrets: `supabase secrets set PAYMOB_API_KEY=… PAYMOB_HMAC_SECRET=… PAYMOB_INTEGRATION_ID=… PAYMOB_IFRAME_ID=(new live iframe) CORS_ALLOWED_ORIGINS=https://albatal.app NOTIFICATIONS_INTERNAL_KEY=… SCHEDULER_SECRET=… FCM_SERVICE_ACCOUNT_JSON=… RESEND_API_KEY=… --project-ref alxw...`
5. Paymob dashboard: new live integration + iframe; set **Transaction processed callback** POST → `https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback` (`verify_jwt=OFF`), **Transaction response callback** GET → `https://albatal.app/payment/callback` (note dotted `source_data.*` vs flat `source_data_*` HMAC nuance).
6. Fill `config/env.production.json` (today `REPLACE_WITH_*` placeholders) from 1Password — `SUPABASE_URL` + `SUPABASE_ANON_KEY` for `alxw...`.
7. Smoke: `supabase functions list`, `migration list --linked` parity, `curl` anon `products` select, one live `create_checkout_order` + Paymob `APPROVED` → `paid`/`success` without manual replay.
8. Rotate any leaked prod DB password history note — `git history` still contains prior credential though current password rotated (see `STATE.md` wave 2).

---

## 7. Frontend Contracts & Rollout

### 7.1 Repository wiring

- New domain ports: `SearchRepository`, `SupportRepository`, `ReviewRepository`, `CouponRepository`, `AnalyticsRepository` — each behind interface, `LazySingleton` in `service_locator.dart`.
- Extended: `SupabaseCatalogRepository` (embed `product_images`, branch to `search_products` when `query` non-empty, offline fallback stays in-memory), `CheckoutService` (`p_coupon_code` passthrough), `SupabaseAdminRepository` (3 admin catalog methods + ticket admin), `StorageService` (now registered, used only by admin cubits).
- `SupabaseSupportRepository` replaces `LocalSupportRepository` (today hardcoded `wa.me/201000000000` + `support@albatal-store.example`).
- `SupabaseOrdersRepository`: keep `writeOrders` as `NO-OP` by contract; `OrdersCubit.place()` must call `readOrders()` after RPC to reconcile (today mutates memory only); `advance()` stops client-simulating `shipped→delivered` — call `update_order_status` or poll `get_order_details`.

### 7.2 State & UX

- Admin catalog replaces 4 TODO tiles (`admin_catalog_page.dart:22-48`) with product list (searchable via `search_products`), variant editor, image manager (sort_order drag, `StorageService` upload).
- Flash sale banner binds to `get_active_flash_sales()` (poll 60s, countdown from `ends_at`).
- Search page: debounced 300 ms → `search_products`, ranked, category chips call same RPC with `p_query=''`.
- Support: user `support_tickets` list + realtime `support_messages` thread; admin inbox `/admin/tickets`.
- Idempotency: fix `checkout_cubit.dart:111/133` TODO — persist `idempotencyKey` in `SharedPreferences` via `StorefrontPersistence`.

### 7.3 Error handling

New RPC codes mapped to `Result.failure(AppError)`: `not_admin`, `coupon_expired`, `coupon_max_uses`, `coupon_min_order`, `review_not_delivered`, `ticket_not_found` — cubits surface `Error`/`Empty` states already present.

### 7.4 Feature flags & rollout

- `FeatureFlag.coupons`, `notifications_v2`, `multi_warehouse` (bool in `shared/services/feature_flags.dart` or remote config). T3 behind `coupons`, T4 behind `notifications_v2`, T5 warehouse behind `multi_warehouse`.
- Sequence: T0 prod cutover → internal dogfood live Paymob smoke → T1 internal TestFlight → T2 search A/B (client filter vs server RPC) → T3 coupons flag → T4 support+FCM → T5.
- Each track gets its own `docs/superpowers/specs/YYYY-MM-DD-<track>-design.md` → `docs/superpowers/plans/...` → PR. This doc is the platform master.

### 7.5 Testing

- SQL: extend `supabase/tests/` with `test_search_products.sql`, `test_coupon_flow.sql`, `test_reviews.sql`, `test_support_rls.sql`, realtime publication check `SELECT * FROM pg_publication_tables`.
- Deno: `send_order_notification` FCM/Resend contract tests (no secret leak, internal-key gate).
- Dart: `supabase_search_repository_test.dart`, `coupon_application_test.dart`, `support_cubit_test.dart`, `storage_service_test.dart`, `admin_catalog_cubit_test.dart`; extend `paymob_http_probe.mjs` with realtime fallback check.
- Guards: all new `.mjs` runners reuse `STAGING_DB_URL` ref guard (proven 6/6).

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Paymob live cutover breaks existing prod callbacks (old integration `1062411` pointed at staging) | Keep staging integration `1062411` untouched; create new live integration for prod; dual-callback smoke before DNS switch |
| `pg_cron`/`pg_net` not available on project tier | Pre-check `SELECT * FROM pg_available_extensions`; fallback to external scheduler (GitHub Action cron calling `cancel-expired-orders` with `SCHEDULER_SECRET`) |
| `pg_trgm` search latency at 50k SKUs | Benchmark after T2; add `search_vector` materialized ranking + `LIMIT 20` pagination; Algolia fallback flagged but not built |
| Storage public-read abuse | Path-scoped admin writes + `product_images` table as registry; no direct path enumeration |
| Git history leaked prod password | Already rotated; add `.githistory` note in `secret-hygiene-runbook.md`; ensure `env.production.json` never committed with values |

---

## 9. Open Decisions (recorded, not blocking T0)

- Promote wishlist/cart/addresses from local (`SharedPreferences`) to server tables? Current tables exist but are local-only by design (audit §6). Decision deferred — keep local for T0–T2; revisit if multi-device demand appears.
- Analytics pipeline: direct `record_analytics` RPC vs `analytics-ingest` edge function batching? Spec supports both; implementation picks RPC for v1.
- Recommendation algorithm: co-occurrence matview `SELECT a.product_id, b.product_id, COUNT(*) FROM order_items a JOIN order_items b ...` refreshed nightly — sufficient for v1.

---

## 10. Plan Handoff

Next: `writing-plans` creates `docs/superpowers/plans/2026-08-24-backend-platform-plan.md` starting with **T0+T1** (hardened production cutover + admin catalog). Later tracks get their own plan files referencing this master design.
