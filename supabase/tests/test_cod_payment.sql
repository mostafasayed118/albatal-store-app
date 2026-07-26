-- ============================================================
-- SQL test fixture for the confirm_cod_payment RPC (migration 018).
--
-- This file is NOT a migration. It is a self-contained test
-- script that validates the `confirm_cod_payment` RPC introduced
-- in migration 018. Run it against a staging database that has
-- migration 018 applied, e.g.:
--
--   supabase db execute supabase/migrations/test_cod_payment.sql
--
-- or paste into the SQL editor. It creates throwaway test
-- data in a transaction and rolls back at the end, so it is
-- safe to run on staging. It proves:
--   1.  An authenticated owner can confirm a pending COD order.
--   2.  The confirmation is idempotent (second call returns already_confirmed).
--   3.  A non-owner is rejected with 'not_owner'.
--   4.  An anonymous caller (no auth.uid()) is rejected with
--       'authentication_required'.
--   5.  A non-COD order is rejected with 'payment_not_cod'.
--   6.  A cancelled order is rejected with 'order_not_pending'.
--   7.  An already-paid order returns 'already_confirmed'.
--   8.  The payment status becomes 'success' after confirmation.
--   9.  The order status becomes 'paid' after confirmation.
--  10.  A server-generated transaction_id is returned.
--  11.  A payment in 'failed' state is rejected with 'payment_not_pending'.
--
-- The script expects the `profiles`, `orders`, `order_items`,
-- and `payments` tables from migration 001+ and the
-- `confirm_cod_payment` function from migration 018.
-- ============================================================

BEGIN;

-- ─── Seed a test category + product + variant ────────────
INSERT INTO categories (id, name, slug, sort_order)
  VALUES ('11111111-1111-1111-1111-111111111111', 'TestCat', 'test-cat', 0)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, category_id, name, slug, base_price)
  VALUES (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'TestProduct', 'test-product', 1000
  )
  ON CONFLICT (id) DO NOTHING;

INSERT INTO product_variants (id, product_id, size, color, stock)
  VALUES (
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    'M', 'Black', 10
  )
  ON CONFLICT (id) DO NOTHING;

-- ─── Seed test users (owner + non-owner) ─────────────────
-- auth.users is required for the profiles FK.
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
  VALUES (
    '44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated',
    'owner-test@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000'
  )
  ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
  VALUES (
    '55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated',
    'other-test@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000'
  )
  ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, full_name, is_admin)
  VALUES ('44444444-4444-4444-4444-444444444444', 'Owner', false)
  ON CONFLICT (id) DO UPDATE SET is_admin = false;

INSERT INTO profiles (id, full_name, is_admin)
  VALUES ('55555555-5555-5555-5555-555555555555', 'Other', false)
  ON CONFLICT (id) DO UPDATE SET is_admin = false;

-- ─── Seed a pending COD order + payment (happy path) ─────
-- Order 1: pending COD order owned by the owner user.
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  '66666666-6666-6666-6666-666666666666',
  '44444444-4444-4444-4444-444444444444',
  'pending', 1000, 0, 1000,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO order_items (
  id, order_id, product_id, variant_id,
  product_name, size, color, unit_price, quantity
) VALUES (
  '77777777-7777-7777-7777-777777777777',
  '66666666-6666-6666-6666-666666666666',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  'TestProduct', 'M', 'Black', 1000, 1
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  '88888888-8888-8888-8888-888888888888',
  '66666666-6666-6666-6666-666666666666',
  '44444444-4444-4444-4444-444444444444',
  'cash_on_delivery', 1000, 'pending'
)
  ON CONFLICT (id) DO NOTHING;

-- ─── Seed a pending Paymob (non-COD) order ───────────────
-- Order 2: pending but payment_method is paymob_card.
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  '66666666-6666-6666-6666-666666667777',
  '44444444-4444-4444-4444-444444444444',
  'pending', 2000, 0, 2000,
  'paymob_card', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  '88888888-8888-8888-8888-888888889999',
  '66666666-6666-6666-6666-666666667777',
  '44444444-4444-4444-4444-444444444444',
  'paymob_card', 2000, 'pending'
)
  ON CONFLICT (id) DO NOTHING;

-- ─── Seed a cancelled COD order ──────────────────────────
-- Order 3: cancelled COD order.
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  '66666666-6666-6666-6666-666666668888',
  '44444444-4444-4444-4444-444444444444',
  'cancelled', 500, 0, 500,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

-- ─── Seed a COD order with a failed payment ──────────────
-- Order 4: pending COD order but payment already failed.
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  '66666666-6666-6666-6666-666666669999',
  '44444444-4444-4444-4444-444444444444',
  'pending', 750, 0, 750,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  '88888888-8888-8888-8888-888888880001',
  '66666666-6666-6666-6666-666666669999',
  '44444444-4444-4444-4444-444444444444',
  'cash_on_delivery', 750, 'failed'
)
  ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- TESTS
-- ============================================================

-- ─── Test 1: Owner confirms pending COD order ─────────────
-- Set the JWT claims so auth.uid() returns the owner's UUID.
SELECT set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);

SELECT 'T1 before', p.status AS pay_status, o.status AS order_status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = '66666666-6666-6666-6666-666666666666';

SELECT confirm_cod_payment('66666666-6666-6666-6666-666666666666');
-- Expected: ok=true, code='confirmed', transaction_id starts with 'COD-'

SELECT 'T1 after', p.status AS pay_status, p.transaction_id, o.status AS order_status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = '66666666-6666-6666-6666-666666666666';
-- Expected: pay_status='success', transaction_id starts with 'COD-',
--           order_status='paid'

-- ─── Test 2: Second call is idempotent ───────────────────
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666666666');
-- Expected: ok=true, code='already_confirmed', transaction_id same as T1

-- ─── Test 3: Non-owner is rejected ────────────────────────
-- Switch to the other user's JWT.
SELECT set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555"}', true);

-- Order 1 is owned by 4444... not 5555... so this must fail.
-- But Order 1 is already 'paid' from T1, so we need a fresh
-- pending order owned by 4444... to test the ownership check
-- before the status check. Use Order 4 (pending, owner=4444).
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666669999');
-- Expected: ok=false, code='not_owner'

-- ─── Test 4: Anonymous caller is rejected ────────────────
-- Clear the JWT claims so auth.uid() returns NULL.
SELECT set_config('request.jwt.claims', '', true);

SELECT confirm_cod_payment('66666666-6666-6666-6666-666666666666');
-- Expected: ok=false, code='authentication_required'

-- Restore the owner's JWT for the remaining tests.
SELECT set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);

-- ─── Test 5: Non-COD order is rejected ────────────────────
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666667777');
-- Expected: ok=false, code='payment_not_cod'

-- ─── Test 6: Cancelled order is rejected ─────────────────
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666668888');
-- Expected: ok=false, code='order_not_pending'

-- ─── Test 7: Already-paid order returns already_confirmed ─
-- Order 1 was confirmed in T1. Calling again should return
-- already_confirmed (same as T2, but validates the paid-state
-- idempotency path explicitly).
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666666666');
-- Expected: ok=true, code='already_confirmed'

-- ─── Test 11: Failed payment is rejected ─────────────────
-- Order 4 has a payment in 'failed' state. The RPC should
-- reject it with 'payment_not_pending' (the payment is not
-- in a confirmable state).
-- Note: this test is after T3 which used the other user's
-- JWT on this same order and was rejected with not_owner.
-- Now with the owner's JWT, the ownership check passes but
-- the payment status check must fail.
SELECT confirm_cod_payment('66666666-6666-6666-6666-666666669999');
-- Expected: ok=false, code='payment_not_pending'

-- ============================================================
-- SUMMARY
-- ============================================================
-- T1   owner confirms pending COD         → ok=true,  code='confirmed'
-- T2   second call (idempotent)            → ok=true,  code='already_confirmed'
-- T3   non-owner rejected                  → ok=false, code='not_owner'
-- T4   anonymous rejected                  → ok=false, code='authentication_required'
-- T5   non-COD order rejected              → ok=false, code='payment_not_cod'
-- T6   cancelled order rejected            → ok=false, code='order_not_pending'
-- T7   already-paid order (idempotent)     → ok=true,  code='already_confirmed'
-- T11  failed payment rejected             → ok=false, code='payment_not_pending'
--
-- State assertions (verified via SELECT after T1):
-- T8   payment.status = 'success'
-- T9   order.status = 'paid'
-- T10  transaction_id is non-null and starts with 'COD-'
-- ============================================================

ROLLBACK;
