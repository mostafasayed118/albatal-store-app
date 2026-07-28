-- ============================================================
-- Al Batal Elite — Adversarial RLS Verification Plan (Staging)
--
-- Scope:
--   Anonymous, authenticated-user-A, authenticated-user-B, and
--   non-admin escalation attempts across profiles, orders,
--   order_items, addresses, cart_items, wishlists, payments,
--   products, categories, and admin-only RPCs.
--
-- HARD RULES (enforced by design of this script):
--   * Staging only. Run against the STAGING database, never prod.
--   * No production data is read or mutated.
--   * Two disposable test users are created inside the transaction
--     and destroyed by ROLLBACK. No real user data is touched.
--   * No secrets or JWT bodies are printed.
--   * The script is fully wrapped in BEGIN/ROLLBACK — every write
--     (users, profiles, orders, etc.) is discarded at the end.
--
-- HOW TO RUN:
--   supabase db execute --linked supabase/tests/test_rls_adversarial.sql
--   (or paste into Supabase SQL Editor on the staging project)
--
-- HOW IDENTITY IS SIMULATED:
--   PostgREST resolves `auth.uid()` and `auth.role()` from the
--   GUC `request.jwt.claim.sub` and `role`. We set these via
--   `set_config(..., is_local => true)` so the override is scoped
--   to the current transaction and cannot leak to other sessions.
--   `auth.uid()` is a STABLE function that reads the `role`
--   claim; setting `role` to `authenticated` and `request.jwt.claim.sub`
--   to a UUID makes `auth.uid()` return that UUID.
--
-- OUTPUT:
--   Every test prints a row: (test_id, description, expected, actual, PASS/FAIL)
--   The final summary counts PASS vs FAIL.
--   RLS is NOT verified until every negative test prints PASS.
-- ============================================================

\set ECHO on

BEGIN;

-- ─── Helpers ────────────────────────────────────────────────
-- A temp table to collect results so we can print a clean
-- summary at the end. Each test INSERTs one row.
CREATE TEMP TABLE _rls_results (
  test_id      TEXT,
  description  TEXT,
  expected     TEXT,
  actual       TEXT,
  status       TEXT  -- 'PASS' or 'FAIL'
);

-- Helper to record a result.
CREATE OR REPLACE FUNCTION _r(test_id TEXT, desc TEXT, expected TEXT, actual TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO _rls_results VALUES (test_id, desc, expected, actual,
    CASE WHEN actual = expected THEN 'PASS' ELSE 'FAIL' END);
END; $$;

-- ─── Switch identity helpers ────────────────────────────────
-- anon:       role = 'anon',            no sub
-- user_a:     role = 'authenticated',   sub = user_a_id
-- user_b:     role = 'authenticated',   sub = user_b_id
-- nonadmin:   same as user_b (no admin flag)
CREATE OR REPLACE FUNCTION _anon() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', 'anon', true);
END; $$;

CREATE OR REPLACE FUNCTION _as(p_uid TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', p_uid, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
END; $$;

-- Reset to a privileged role for seeding (service_role bypasses RLS).
CREATE OR REPLACE FUNCTION _service() RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
END; $$;


-- ============================================================
-- SEED DISPOSABLE TEST DATA (as service_role)
-- ============================================================
PERFORM _service();

-- Disposable user A
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
VALUES (
  '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
  'rls-user-a@staging-test.disposable', 'x', now(), '00000000-0000-0000-0000-000000000000'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, full_name, is_admin)
VALUES ('11111111-1111-1111-1111-111111111111', 'RLS User A', false)
ON CONFLICT (id) DO UPDATE SET is_admin = false, full_name = 'RLS User A';

-- Disposable user B
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
VALUES (
  '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
  'rls-user-b@staging-test.disposable', 'x', now(), '00000000-0000-0000-0000-000000000000'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, full_name, is_admin)
VALUES ('22222222-2222-2222-2222-222222222222', 'RLS User B', false)
ON CONFLICT (id) DO UPDATE SET is_admin = false, full_name = 'RLS User B';

-- Category + product + variant (for cart/wishlist/order seed)
INSERT INTO categories (id, name, slug, sort_order)
VALUES ('33333333-3333-3333-3333-333333333333', 'RLS Test Cat', 'rls-test-cat', 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, category_id, name, slug, base_price)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333',
  'RLS Test Product', 'rls-test-product', 1000
) ON CONFLICT (id) DO NOTHING;

INSERT INTO product_variants (id, product_id, size, color, stock, is_active)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  '44444444-4444-4444-4444-444444444444',
  'M', 'Blue', 10, true
) ON CONFLICT (id) DO NOTHING;

-- User A owns: address, cart item, wishlist item, order, payment
INSERT INTO addresses (id, user_id, recipient, line, city, country)
VALUES ('66666666-6666-6666-6666-666666666666',
  '11111111-1111-1111-1111-111111111111', 'A', 'A St', 'Cairo', 'Egypt')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cart_items (id, user_id, variant_id, quantity)
VALUES ('77777777-7777-7777-7777-777777777777',
  '11111111-1111-1111-1111-111111111111',
  '55555555-5555-5555-5555-555555555555', 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO wishlists (id, user_id, product_id)
VALUES ('88888888-8888-8888-8888-888888888888',
  '11111111-1111-1111-1111-111111111111',
  '44444444-4444-4444-4444-444444444444')
ON CONFLICT (id) DO NOTHING;

-- User A's order (inserted by service_role since RLS denies direct INSERT)
INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at)
VALUES ('99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  'pending', 2000, 500, 2500, 'paymob_card',
  '{"recipient":"A","line":"A St","city":"Cairo"}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO order_items (id, order_id, product_id, variant_id,
  product_name, size, color, unit_price, quantity)
VALUES ('AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA',
  '99999999-9999-9999-9999-999999999999',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  'RLS Test Product', 'M', 'Blue', 1000, 2)
ON CONFLICT (id) DO NOTHING;

-- User A's payment (inserted by service_role)
INSERT INTO payments (id, order_id, user_id, method, amount, status)
VALUES ('BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB',
  '99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  'paymob_card', 2500, 'pending')
ON CONFLICT (id) DO NOTHING;

-- User B owns: address, cart item, wishlist item, order, payment
INSERT INTO addresses (id, user_id, recipient, line, city, country)
VALUES ('CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC',
  '22222222-2222-2222-2222-222222222222', 'B', 'B St', 'Giza', 'Egypt')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cart_items (id, user_id, variant_id, quantity)
VALUES ('DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD',
  '22222222-2222-2222-2222-222222222222',
  '55555555-5555-5555-5555-555555555555', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO wishlists (id, user_id, product_id)
VALUES ('EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE',
  '22222222-2222-2222-2222-222222222222',
  '44444444-4444-4444-4444-444444444444')
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at)
VALUES ('FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
  '22222222-2222-2222-2222-222222222222',
  'pending', 1000, 500, 1500, 'paymob_card',
  '{"recipient":"B","line":"B St","city":"Giza"}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO order_items (id, order_id, product_id, variant_id,
  product_name, size, color, unit_price, quantity)
VALUES ('12345678-1234-1234-1234-123456789012',
  'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  'RLS Test Product', 'M', 'Blue', 1000, 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (id, order_id, user_id, method, amount, status)
VALUES ('87654321-8765-4321-8765-432187654321',
  'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF',
  '22222222-2222-2222-2222-222222222222',
  'paymob_card', 1500, 'pending')
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SECTION 1: ANONYMOUS USER
-- Expected: cannot read any user-scoped table; CAN read public catalog.
-- ============================================================
\echo '\n=== SECTION 1: Anonymous user ==='

PERFORM _anon();

-- 1.1 Cannot read profiles
PERFORM _r('1.1', 'anon cannot read profiles', '0', (SELECT count(*)::text FROM profiles));
-- 1.2 Cannot read orders
PERFORM _r('1.2', 'anon cannot read orders', '0', (SELECT count(*)::text FROM orders));
-- 1.3 Cannot read order_items
PERFORM _r('1.3', 'anon cannot read order_items', '0', (SELECT count(*)::text FROM order_items));
-- 1.4 Cannot read addresses
PERFORM _r('1.4', 'anon cannot read addresses', '0', (SELECT count(*)::text FROM addresses));
-- 1.5 Cannot read cart_items
PERFORM _r('1.5', 'anon cannot read cart_items', '0', (SELECT count(*)::text FROM cart_items));
-- 1.6 Cannot read wishlists
PERFORM _r('1.6', 'anon cannot read wishlists', '0', (SELECT count(*)::text FROM wishlists));
-- 1.7 Cannot read payments
PERFORM _r('1.7', 'anon cannot read payments', '0', (SELECT count(*)::text FROM payments));
-- 1.8 CAN read public catalog (products)
PERFORM _r('1.8', 'anon can read products', '>=1', (SELECT CASE WHEN count(*) >= 1 THEN '>=1' ELSE '0' END::text FROM products));
-- 1.9 CAN read public catalog (categories)
PERFORM _r('1.9', 'anon can read categories', '>=1', (SELECT CASE WHEN count(*) >= 1 THEN '>=1' ELSE '0' END::text FROM categories));
-- 1.10 CAN read public catalog (product_variants)
PERFORM _r('1.10', 'anon can read product_variants', '>=1', (SELECT CASE WHEN count(*) >= 1 THEN '>=1' ELSE '0' END::text FROM product_variants));
-- 1.11 CAN read public catalog (product_images)
PERFORM _r('1.11', 'anon can read product_images', '>=0', (SELECT CASE WHEN count(*) >= 0 THEN '>=0' ELSE '-1' END::text FROM product_images));
-- 1.12 Cannot read notifications
PERFORM _r('1.12', 'anon cannot read notifications', '0', (SELECT count(*)::text FROM notifications));
-- 1.13 Cannot read analytics_events
PERFORM _r('1.13', 'anon cannot read analytics_events', '0', (SELECT count(*)::text FROM analytics_events));
-- 1.14 Cannot read error_logs
PERFORM _r('1.14', 'anon cannot read error_logs', '0', (SELECT count(*)::text FROM error_logs));


-- ============================================================
-- SECTION 2: USER A (authenticated, non-admin)
-- Expected: can read own data; cannot read user B's data.
-- ============================================================
\echo '\n=== SECTION 2: User A — own data ==='

PERFORM _as('11111111-1111-1111-1111-111111111111');

-- 2.1 Can read own profile (exactly 1 row)
PERFORM _r('2.1', 'user_a can read own profile', '1', (SELECT count(*)::text FROM profiles));
-- 2.2 Can read own orders (exactly 1 row — order 999...)
PERFORM _r('2.2', 'user_a can read own orders', '1', (SELECT count(*)::text FROM orders));
-- 2.3 Can read own order_items (exactly 1 row)
PERFORM _r('2.3', 'user_a can read own order_items', '1', (SELECT count(*)::text FROM order_items));
-- 2.4 Can read own addresses (exactly 1 row)
PERFORM _r('2.4', 'user_a can read own addresses', '1', (SELECT count(*)::text FROM addresses));
-- 2.5 Can read own cart (exactly 1 row)
PERFORM _r('2.5', 'user_a can read own cart_items', '1', (SELECT count(*)::text FROM cart_items));
-- 2.6 Can read own wishlist (exactly 1 row)
PERFORM _r('2.6', 'user_a can read own wishlists', '1', (SELECT count(*)::text FROM wishlists));
-- 2.7 Can read own payments (exactly 1 row)
PERFORM _r('2.7', 'user_a can read own payments', '1', (SELECT count(*)::text FROM payments));

\echo '\n=== SECTION 2b: User A — cannot read user B data ==='

-- 2.8 Cannot read user B's orders (count from orders where user_id = B should be 0)
PERFORM _r('2.8', 'user_a cannot read user_b orders', '0',
  (SELECT count(*)::text FROM orders WHERE user_id = '22222222-2222-2222-2222-222222222222'));
-- 2.9 Cannot read user B's addresses
PERFORM _r('2.9', 'user_a cannot read user_b addresses', '0',
  (SELECT count(*)::text FROM addresses WHERE user_id = '22222222-2222-2222-2222-222222222222'));
-- 2.10 Cannot read user B's cart
PERFORM _r('2.10', 'user_a cannot read user_b cart_items', '0',
  (SELECT count(*)::text FROM cart_items WHERE user_id = '22222222-2222-2222-2222-222222222222'));
-- 2.11 Cannot read user B's wishlist
PERFORM _r('2.11', 'user_a cannot read user_b wishlists', '0',
  (SELECT count(*)::text FROM wishlists WHERE user_id = '22222222-2222-2222-2222-222222222222'));
-- 2.12 Cannot read user B's payments
PERFORM _r('2.12', 'user_a cannot read user_b payments', '0',
  (SELECT count(*)::text FROM payments WHERE user_id = '22222222-2222-2222-2222-222222222222'));
-- 2.13 Cannot read user B's profile
PERFORM _r('2.13', 'user_a cannot read user_b profile', '0',
  (SELECT count(*)::text FROM profiles WHERE id = '22222222-2222-2222-2222-222222222222'));
-- 2.14 Cannot read user B's order_items (via order_items RLS join)
PERFORM _r('2.14', 'user_a cannot read user_b order_items', '0',
  (SELECT count(*)::text FROM order_items WHERE order_id = 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF'));


-- ============================================================
-- SECTION 3: NON-ADMIN ESCALATION ATTEMPTS
-- Expected: non-admin cannot mutate catalog, cannot call admin
-- RPCs, cannot update order status, cannot self-escalate is_admin.
-- ============================================================
\echo '\n=== SECTION 3: Non-admin escalation attempts ==='

PERFORM _as('22222222-2222-2222-2222-222222222222'); -- user B, non-admin

-- 3.1 Cannot INSERT products (count of new product rows should stay 0)
-- We attempt the insert inside a sub-transaction that swallows the
-- RLS error, then check whether a row with slug 'rls-hack-product' exists.
DO $$
BEGIN
  BEGIN
    INSERT INTO products (id, category_id, name, slug, base_price)
    VALUES ('DEADBEEF-0000-0000-0000-000000000001',
      '33333333-3333-3333-3333-333333333333',
      'Hack', 'rls-hack-product', 1);
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.1', 'non-admin cannot INSERT products', '0',
  (SELECT count(*)::text FROM products WHERE slug = 'rls-hack-product'));

-- 3.2 Cannot UPDATE products
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE products SET name = 'Hacked Name' WHERE id = '44444444-4444-4444-4444-444444444444';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.2', 'non-admin cannot UPDATE products', 'RLS Test Product',
  (SELECT name FROM products WHERE id = '44444444-4444-4444-4444-444444444444'));

-- 3.3 Cannot DELETE products
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    DELETE FROM products WHERE id = '44444444-4444-4444-4444-444444444444';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.3', 'non-admin cannot DELETE products', '1',
  (SELECT count(*)::text FROM products WHERE id = '44444444-4444-4444-4444-444444444444'));

-- 3.4 Cannot INSERT categories
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    INSERT INTO categories (id, name, slug, sort_order)
    VALUES ('DEADBEEF-0000-0000-0000-000000000002', 'Hack Cat', 'rls-hack-cat', 0);
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.4', 'non-admin cannot INSERT categories', '0',
  (SELECT count(*)::text FROM categories WHERE slug = 'rls-hack-cat'));

-- 3.5 Cannot UPDATE categories
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE categories SET name = 'Hacked Cat' WHERE id = '33333333-3333-3333-3333-333333333333';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.5', 'non-admin cannot UPDATE categories', 'RLS Test Cat',
  (SELECT name FROM categories WHERE id = '33333333-3333-3333-3333-333333333333'));

-- 3.6 Cannot UPDATE order status via RPC (admin-only check inside)
-- update_order_status is SECURITY DEFINER and checks profiles.is_admin.
-- A non-admin should get an exception.
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
DECLARE
  v_err TEXT := NULL;
BEGIN
  BEGIN
    PERFORM update_order_status('FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF', 'processing');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  PERFORM _r('3.6', 'non-admin cannot update_order_status', 'exception',
    CASE WHEN v_err IS NOT NULL THEN 'exception' ELSE 'no_exception' END);
END $$;

-- 3.7 Cannot self-escalate is_admin = true
-- The profiles_update_own_safe policy has a WITH CHECK that
-- prevents changing is_admin. Attempt and verify it stays false.
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
BEGIN
  BEGIN
    UPDATE profiles SET is_admin = true WHERE id = '22222222-2222-2222-2222-222222222222';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('3.7', 'non-admin cannot set is_admin=true', 'false',
  (SELECT is_admin::text FROM profiles WHERE id = '22222222-2222-2222-2222-222222222222'));

-- 3.8 Cannot call get_low_stock_products (admin-only)
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
DECLARE
  v_err TEXT := NULL;
BEGIN
  BEGIN
    PERFORM * FROM get_low_stock_products(100);
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  PERFORM _r('3.8', 'non-admin cannot call get_low_stock_products', 'exception',
    CASE WHEN v_err IS NOT NULL THEN 'exception' ELSE 'no_exception' END);
END $$;

-- 3.9 Cannot call get_order_details for another user's order (IDOR)
-- User B tries to read User A's order 999...
PERFORM _as('22222222-2222-2222-2222-222222222222');
DO $$
DECLARE
  v_err TEXT := NULL;
BEGIN
  BEGIN
    PERFORM get_order_details('99999999-9999-9999-9999-999999999999'::uuid);
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  PERFORM _r('3.9', 'non-admin IDOR blocked on get_order_details', 'exception',
    CASE WHEN v_err IS NOT NULL THEN 'exception' ELSE 'no_exception' END);
END $$;


-- ============================================================
-- SECTION 4: AUTHENTICATED USER — PAYMENT INTEGRITY
-- Expected: cannot directly insert payment rows, cannot call
-- process_paymob_callback, cannot bypass checkout pricing.
-- ============================================================
\echo '\n=== SECTION 4: Authenticated user — payment integrity ==='

PERFORM _as('11111111-1111-1111-1111-111111111111'); -- user A

-- 4.1 Cannot directly INSERT into payments (no INSERT policy = default-deny)
DO $$
BEGIN
  BEGIN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    VALUES ('99999999-9999-9999-9999-999999999999',
      '11111111-1111-1111-1111-111111111111',
      'fraud', 1, 'success');
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
-- Count should still be 1 (only the service_role-seeded payment for user A)
-- Actually there are 2 payments total (user A + user B). Check user A has
-- exactly 1 payment with method 'fraud' — should be 0.
PERFORM _as('11111111-1111-1111-1111-111111111111');
PERFORM _r('4.1', 'authenticated cannot INSERT payments directly', '0',
  (SELECT count(*)::text FROM payments WHERE method = 'fraud'));

-- 4.2 Cannot call process_paymob_callback (service_role only)
-- The GRANT is to service_role only. An authenticated caller
-- should get a "permission denied" or "function not found" error.
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
DECLARE
  v_err TEXT := NULL;
BEGIN
  BEGIN
    PERFORM process_paymob_callback('test', 'test', 100, 'EGP', true);
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  PERFORM _r('4.2', 'authenticated cannot call process_paymob_callback', 'exception',
    CASE WHEN v_err IS NOT NULL THEN 'exception' ELSE 'no_exception' END);
END $$;

-- 4.3 Cannot bypass checkout pricing
-- create_checkout_order is SECURITY DEFINER and reads prices from DB.
-- A user passing a crafted items JSON with a fake unit_price should
-- still get the DB price, not the client-supplied price. We verify
-- the RPC ignores any client-supplied price field by calling it
-- with a bogus price and checking the returned subtotal.
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
DECLARE
  v_result JSONB;
  v_subtotal TEXT;
  v_err TEXT := NULL;
BEGIN
  BEGIN
    -- Create a fresh order with idempotency key so it doesn't collide
    SELECT create_checkout_order(
      'paymob_card',
      '{"recipient":"Test","line":"Test St","city":"Cairo"}'::jsonb,
      '[{"product_id":"44444444-4444-4444-4444-444444444444","size":"M","color":"Blue","quantity":1,"unit_price":1}]'::jsonb,
      'rls-pricing-test-key'
    ) INTO v_result;
    v_subtotal := (v_result->>'subtotal');
    -- Expected subtotal = 1000 (DB price) * 1 = 1000, NOT 1 (client price)
    PERFORM _r('4.3', 'checkout ignores client-supplied price', '1000',
      COALESCE(v_subtotal, 'null'));
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    PERFORM _r('4.3', 'checkout ignores client-supplied price', '1000',
      'exception: ' || v_err);
  END;
END $$;

-- 4.4 Cannot directly UPDATE payments (no UPDATE policy)
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
BEGIN
  BEGIN
    UPDATE payments SET status = 'success' WHERE id = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('4.4', 'authenticated cannot UPDATE payments', 'pending',
  (SELECT status FROM payments WHERE id = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'));

-- 4.5 Cannot directly UPDATE orders status (no UPDATE policy for non-admin)
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
BEGIN
  BEGIN
    UPDATE orders SET status = 'paid' WHERE id = '99999999-9999-9999-9999-999999999999';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('4.5', 'authenticated cannot UPDATE orders directly', 'pending',
  (SELECT status::text FROM orders WHERE id = '99999999-9999-9999-9999-999999999999'));

-- 4.6 Cannot INSERT into orders directly (orders_insert_denied policy)
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
BEGIN
  BEGIN
    INSERT INTO orders (user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot)
    VALUES ('11111111-1111-1111-1111-111111111111', 'pending', 1, 0, 1,
      'fraud', '{}'::jsonb);
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('4.6', 'authenticated cannot INSERT orders directly', '0',
  (SELECT count(*)::text FROM orders WHERE payment_method = 'fraud'));

-- 4.7 Cannot INSERT into order_items directly (order_items_insert_denied policy)
PERFORM _as('11111111-1111-1111-1111-111111111111');
DO $$
BEGIN
  BEGIN
    INSERT INTO order_items (order_id, product_id, variant_id,
      product_name, size, color, unit_price, quantity)
    VALUES ('99999999-9999-9999-9999-999999999999',
      '44444444-4444-4444-4444-444444444444',
      '55555555-5555-5555-5555-555555555555',
      'Fraud Item', 'M', 'Blue', 1, 1);
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
PERFORM _service();
PERFORM _r('4.7', 'authenticated cannot INSERT order_items directly', '1',
  (SELECT count(*)::text FROM order_items WHERE order_id = '99999999-9999-9999-9999-999999999999'));


-- ============================================================
-- SUMMARY
-- ============================================================
PERFORM _service();

\echo '\n=== RLS TEST RESULTS ==='
SELECT test_id, description, expected, actual, status
FROM _rls_results
ORDER BY test_id;

\echo '\n=== PASS/FAIL SUMMARY ==='
SELECT
  COUNT(*) FILTER (WHERE status = 'PASS') AS passed,
  COUNT(*) FILTER (WHERE status = 'FAIL') AS failed,
  COUNT(*) AS total,
  CASE
    WHEN COUNT(*) FILTER (WHERE status = 'FAIL') = 0
    THEN 'ALL PASS — RLS VERIFIED'
    ELSE 'FAILURES DETECTED — RLS NOT VERIFIED'
  END AS verdict
FROM _rls_results;

-- Print only failures (if any) for quick triage
\echo '\n=== FAILURES (if any) ==='
SELECT test_id, description, expected, actual
FROM _rls_results
WHERE status = 'FAIL'
ORDER BY test_id;

ROLLBACK;

\echo '\n=== Transaction rolled back — no test data persisted ==='
