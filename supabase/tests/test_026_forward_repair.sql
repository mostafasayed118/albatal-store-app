-- ============================================================
-- SQL test fixture for migration 026 forward repair.
--
-- Tests the approved Decision 2 behavior:
--   1. create_checkout_order creates pending COD payment row
--   2. confirm_cod_payment rejects payment_not_found when
--      no valid pending COD payment row exists
--   3. confirm_cod_payment succeeds when valid pending COD
--      payment row exists (created by create_checkout_order)
--   4. Idempotency: already_confirmed on re-confirmation
--   5. Privilege matrix is correct
--
-- Run against staging after migration 026 is applied:
--   supabase db execute supabase/tests/test_026_forward_repair.sql
--
-- Safe to run on staging (uses ROLLBACK).
-- ============================================================

BEGIN;

-- ─── Seed test data ──────────────────────────────────────
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

-- ─── Seed test users ─────────────────────────────────────
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

-- ═══════════════════════════════════════════════════════════
-- TEST 1: create_checkout_order creates pending COD payment
-- ═══════════════════════════════════════════════════════════
-- When a COD order is created via create_checkout_order,
-- a pending COD payment row must be created automatically.

SELECT set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);

SELECT create_checkout_order(
  'Cash on Delivery',
  '{"recipient":"Test User","line":"123 Main St","city":"Cairo"}'::jsonb,
  '[{"product_id":"22222222-2222-2222-2222-222222222222","size":"M","color":"Black","quantity":1}]'::jsonb,
  'test-idempotency-001'
);

-- Verify: a pending COD payment row should exist
SELECT 'T1 payment exists', COUNT(*) AS payment_count
  FROM payments
  WHERE order_id IN (
    SELECT id FROM orders WHERE idempotency_key = 'test-idempotency-001'
  )
  AND method = 'cash_on_delivery'
  AND status = 'pending';
-- Expected: payment_count = 1


-- ═══════════════════════════════════════════════════════════
-- TEST 2: confirm_cod_payment succeeds with valid payment
-- ═══════════════════════════════════════════════════════════
-- The pending COD payment row created by TEST 1 should be
-- confirmable.

SELECT confirm_cod_payment(
  (SELECT id FROM orders WHERE idempotency_key = 'test-idempotency-001')
);
-- Expected: ok=true, code='confirmed', transaction_id starts with 'COD-'

-- Verify: payment status should be 'success'
SELECT 'T2 payment status', p.status AS pay_status, o.status AS order_status
  FROM payments p
  JOIN orders o ON o.id = p.order_id
  WHERE o.idempotency_key = 'test-idempotency-001';
-- Expected: pay_status='success', order_status='paid'


-- ═══════════════════════════════════════════════════════════
-- TEST 3: confirm_cod_payment rejects payment_not_found
-- ═══════════════════════════════════════════════════════════
-- A COD order WITHOUT a payment row should be rejected.

-- Create a COD order without a payment row (simulate old behavior)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, idempotency_key, expires_at, placed_at
) VALUES (
  'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA',
  '44444444-4444-4444-4444-444444444444',
  'pending', 1000, 0, 1000,
  'Cash on Delivery',
  '{"recipient":"Test","line":"123","city":"Cairo"}'::jsonb,
  'test-no-payment',
  now() + interval '15 minutes',
  now()
) ON CONFLICT (id) DO NOTHING;

-- No payment row for this order

SELECT confirm_cod_payment('AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA');
-- Expected: ok=false, code='payment_not_found'


-- ═══════════════════════════════════════════════════════════
-- TEST 4: Idempotency — already_confirmed on re-confirmation
-- ═══════════════════════════════════════════════════════════
-- Calling confirm_cod_payment on an already-confirmed order
-- should return already_confirmed.

SELECT confirm_cod_payment(
  (SELECT id FROM orders WHERE idempotency_key = 'test-idempotency-001')
);
-- Expected: ok=true, code='already_confirmed'


-- ═══════════════════════════════════════════════════════════
-- TEST 5: Non-owner is rejected
-- ═══════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555"}', true);

SELECT confirm_cod_payment('AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA');
-- Expected: ok=false, code='not_owner'


-- ═══════════════════════════════════════════════════════════
-- TEST 6: Anonymous caller is rejected
-- ═══════════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims', '', true);

SELECT confirm_cod_payment('AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA');
-- Expected: ok=false, code='authentication_required'


-- ═══════════════════════════════════════════════════════════
-- TEST 7: Non-COD order is rejected
-- ═══════════════════════════════════════════════════════════
-- Restore owner JWT
SELECT set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);

-- Create a Paymob order
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, idempotency_key, expires_at, placed_at
) VALUES (
  'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB',
  '44444444-4444-4444-4444-444444444444',
  'pending', 2000, 0, 2000,
  'paymob_card',
  '{"recipient":"Test","line":"123","city":"Cairo"}'::jsonb,
  'test-paymob-order',
  now() + interval '15 minutes',
  now()
) ON CONFLICT (id) DO NOTHING;

SELECT confirm_cod_payment('BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB');
-- Expected: ok=false, code='payment_not_cod'


-- ═══════════════════════════════════════════════════════════
-- TEST 8: Cancelled order is rejected
-- ═══════════════════════════════════════════════════════════
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, expires_at, placed_at
) VALUES (
  'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC',
  '44444444-4444-4444-4444-444444444444',
  'cancelled', 500, 0, 500,
  'Cash on Delivery',
  '{"recipient":"Test","line":"123","city":"Cairo"}'::jsonb,
  now() + interval '15 minutes',
  now()
) ON CONFLICT (id) DO NOTHING;

SELECT confirm_cod_payment('CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC');
-- Expected: ok=false, code='order_not_pending'


-- ═══════════════════════════════════════════════════════════
-- TEST 9: Failed payment is rejected
-- ═══════════════════════════════════════════════════════════
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, idempotency_key, expires_at, placed_at
) VALUES (
  'DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD',
  '44444444-4444-4444-4444-444444444444',
  'pending', 750, 0, 750,
  'Cash on Delivery',
  '{"recipient":"Test","line":"123","city":"Cairo"}'::jsonb,
  'test-failed-payment',
  now() + interval '15 minutes',
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  order_id, user_id, method, amount, status
) VALUES (
  'DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD',
  '44444444-4444-4444-4444-444444444444',
  'cash_on_delivery', 750, 'failed'
) ON CONFLICT DO NOTHING;

SELECT confirm_cod_payment('DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD');
-- Expected: ok=false, code='payment_not_pending'


-- ═══════════════════════════════════════════════════════════
-- TEST 10: Privilege matrix verification
-- ═══════════════════════════════════════════════════════════
-- Verify that the privilege grants are correct after migration 026.

SELECT 'T10 create_checkout_order grants' AS test,
  has_function_privilege('authenticated', 'create_checkout_order(TEXT, JSONB, JSONB, TEXT)', 'execute') AS auth_can_execute,
  has_function_privilege('anon', 'create_checkout_order(TEXT, JSONB, JSONB, TEXT)', 'execute') AS anon_can_execute;
-- Expected: auth_can_execute=true, anon_can_execute=false

SELECT 'T10 confirm_cod_payment grants' AS test,
  has_function_privilege('authenticated', 'confirm_cod_payment(UUID)', 'execute') AS auth_can_execute,
  has_function_privilege('anon', 'confirm_cod_payment(UUID)', 'execute') AS anon_can_execute;
-- Expected: auth_can_execute=true, anon_can_execute=false

SELECT 'T10 process_paymob_callback grants' AS test,
  has_function_privilege('service_role', 'process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN)', 'execute') AS service_can_execute,
  has_function_privilege('authenticated', 'process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN)', 'execute') AS auth_can_execute,
  has_function_privilege('anon', 'process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN)', 'execute') AS anon_can_execute;
-- Expected: service_can_execute=true, auth_can_execute=false, anon_can_execute=false


-- ═══════════════════════════════════════════════════════════
-- SUMMARY
-- ═══════════════════════════════════════════════════════════
-- T1   create_checkout_order creates COD payment  → payment_count=1
-- T2   confirm_cod_payment succeeds               → ok=true, code='confirmed'
-- T3   confirm_cod_payment rejects no payment     → ok=false, code='payment_not_found'
-- T4   Idempotency already_confirmed              → ok=true, code='already_confirmed'
-- T5   Non-owner rejected                         → ok=false, code='not_owner'
-- T6   Anonymous rejected                         → ok=false, code='authentication_required'
-- T7   Non-COD order rejected                     → ok=false, code='payment_not_cod'
-- T8   Cancelled order rejected                   → ok=false, code='order_not_pending'
-- T9   Failed payment rejected                    → ok=false, code='payment_not_pending'
-- T10  Privilege matrix correct                   → authenticated only, service_role for callback
-- ============================================================

ROLLBACK;
