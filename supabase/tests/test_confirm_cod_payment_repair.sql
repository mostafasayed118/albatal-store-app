-- ============================================================
-- SQL test fixture for the confirm_cod_payment RPC (migration 022)
--
-- This is NOT a migration. It is a self-contained test script
-- that validates the `confirm_cod_payment` function repaired in
-- migration 022. Run against a staging database that has
-- migration 022 applied:
--
--   supabase db execute supabase/tests/test_confirm_cod_payment_repair.sql
--
-- or paste into the Supabase SQL Editor.
--
-- Creates throwaway test data in a single transaction and
-- ROLLBACKs at the end — safe to run on staging.
--
-- COVERAGE:
--   T1   owner confirms pending COD order (happy path)
--   T2   repeat call returns already_confirmed (idempotency)
--   T3   anonymous caller denied (authentication_required)
--   T4   non-owner denied (not_owner)
--   T5   cancelled order denied (order_not_pending)
--   T6   non-COD order denied (payment_not_cod)
--   T7   failed payment denied (payment_not_pending)
--   T8   missing payment row → auto-created (auto-create)
--   T9   database state verification after success
--   T10  no persistent state change (ROLLBACK proves it)
-- ============================================================

BEGIN;

-- ─── Seed test category + product + variant ──────────────
INSERT INTO categories (id, name, slug, sort_order)
  VALUES ('a0000000-0000-0000-0000-000000000001', 'RepairCat', 'repair-cat', 0)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO products (id, category_id, name, slug, base_price)
  VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'RepairProduct', 'repair-product', 1000
  )
  ON CONFLICT (id) DO NOTHING;

INSERT INTO product_variants (id, product_id, size, color, stock)
  VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    'M', 'Black', 100
  )
  ON CONFLICT (id) DO NOTHING;

-- ─── Seed test users ─────────────────────────────────────
-- Owner user
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
  VALUES (
    'd0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
    'repair-owner@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000'
  )
  ON CONFLICT (id) DO NOTHING;

-- Non-owner user
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
  VALUES (
    'd0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
    'repair-other@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000'
  )
  ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, full_name, is_admin)
  VALUES ('d0000000-0000-0000-0000-000000000001', 'RepairOwner', false)
  ON CONFLICT (id) DO UPDATE SET is_admin = false;

INSERT INTO profiles (id, full_name, is_admin)
  VALUES ('d0000000-0000-0000-0000-000000000002', 'RepairOther', false)
  ON CONFLICT (id) DO UPDATE SET is_admin = false;

-- ─── Seed test orders ────────────────────────────────────
-- Order 1: pending COD with payment (happy path + idempotency)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000001',
  'd0000000-0000-0000-0000-000000000001',
  'pending', 1000, 0, 1000,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO order_items (
  id, order_id, product_id, variant_id,
  product_name, size, color, unit_price, quantity
) VALUES (
  'f0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'RepairProduct', 'M', 'Black', 1000, 1
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  'a1000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'd0000000-0000-0000-0000-000000000001',
  'cash_on_delivery', 1000, 'pending'
)
  ON CONFLICT (id) DO NOTHING;

-- Order 2: cancelled COD (cancelled order test)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000002',
  'd0000000-0000-0000-0000-000000000001',
  'cancelled', 500, 0, 500,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

-- Order 3: pending non-COD (paymob_card)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000003',
  'd0000000-0000-0000-0000-000000000001',
  'pending', 2000, 0, 2000,
  'paymob_card', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  'a1000000-0000-0000-0000-000000000002',
  'e0000000-0000-0000-0000-000000000003',
  'd0000000-0000-0000-0000-000000000001',
  'paymob_card', 2000, 'pending'
)
  ON CONFLICT (id) DO NOTHING;

-- Order 4: pending COD with failed payment
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000004',
  'd0000000-0000-0000-0000-000000000001',
  'pending', 750, 0, 750,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  'a1000000-0000-0000-0000-000000000003',
  'e0000000-0000-0000-0000-000000000004',
  'd0000000-0000-0000-0000-000000000001',
  'cash_on_delivery', 750, 'failed'
)
  ON CONFLICT (id) DO NOTHING;

-- Order 5: pending COD with NO payment row (missing payment test)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000005',
  'd0000000-0000-0000-0000-000000000001',
  'pending', 600, 0, 600,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

-- Order 6: pending COD owned by other user (non-owner test)
INSERT INTO orders (
  id, user_id, status, subtotal, shipping, total,
  payment_method, address_snapshot, placed_at
) VALUES (
  'e0000000-0000-0000-0000-000000000006',
  'd0000000-0000-0000-0000-000000000002',
  'pending', 900, 0, 900,
  'Cash on Delivery', '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now()
)
  ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (
  id, order_id, user_id, method, amount, status
) VALUES (
  'a1000000-0000-0000-0000-000000000004',
  'e0000000-0000-0000-0000-000000000006',
  'd0000000-0000-0000-0000-000000000002',
  'cash_on_delivery', 900, 'pending'
)
  ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- TESTS
-- ============================================================

-- ─── T1: Owner confirms pending COD order (happy path) ───
SELECT set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000001"}', true);

SELECT 'T1 before', p.status AS pay_status, o.status AS order_status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = 'e0000000-0000-0000-0000-000000000001';

SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000001');
-- Expected: ok=true, code='confirmed', transaction_id starts with 'COD-'

SELECT 'T1 after', p.status AS pay_status, p.transaction_id, o.status AS order_status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = 'e0000000-0000-0000-0000-000000000001';
-- Expected: pay_status='success', transaction_id non-null, order_status='paid'

-- ─── T2: Repeat call is idempotent ──────────────────────
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000001');
-- Expected: ok=true, code='already_confirmed', same transaction_id

-- ─── T3: Anonymous caller is rejected ───────────────────
SELECT set_config('request.jwt.claims', '', true);

SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000001');
-- Expected: ok=false, code='authentication_required'

-- Restore owner JWT for remaining tests
SELECT set_config('request.jwt.claims', '{"sub":"d0000000-0000-0000-0000-000000000001"}', true);

-- ─── T4: Non-owner is rejected ──────────────────────────
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000006');
-- Expected: ok=false, code='not_owner'

-- ─── T5: Cancelled order is rejected ────────────────────
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000002');
-- Expected: ok=false, code='order_not_pending'

-- ─── T6: Non-COD order is rejected ─────────────────────
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000003');
-- Expected: ok=false, code='payment_not_cod'

-- ─── T7: Failed payment is rejected ────────────────────
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000004');
-- Expected: ok=false, code='payment_not_pending'

-- ─── T8: Missing payment row → auto-created ────────────
-- Order 5 has a COD order with NO payment row.
-- The RPC should auto-create a COD payment row and confirm it.
SELECT 'T8 before', count(*) AS payment_rows_before
  FROM payments WHERE order_id = 'e0000000-0000-0000-0000-000000000005';

SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000005');
-- Expected: ok=true, code='confirmed', transaction_id starts with 'COD-'

SELECT 'T8 after', p.status AS pay_status, p.method, p.amount, p.transaction_id, o.status AS order_status
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = 'e0000000-0000-0000-0000-000000000005';
-- Expected: pay_status='success', method='cash_on_delivery',
--           amount=600 (matches order total), order_status='paid'

SELECT 'T8 payment_created', count(*) AS payment_rows_after
  FROM payments WHERE order_id = 'e0000000-0000-0000-0000-000000000005';
-- Expected: 1 (exactly one payment row now exists)

-- ─── T8b: Missing payment idempotency ──────────────────
-- Second call on the same order should return already_confirmed.
SELECT confirm_cod_payment('e0000000-0000-0000-0000-000000000005');
-- Expected: ok=true, code='already_confirmed'

-- ─── T9: Database state verification ────────────────────
-- Verify all state columns are correct after T1 success.
SELECT 'T9 state check',
  p.status        AS payment_status,
  p.method        AS payment_method,
  p.amount        AS payment_amount,
  p.transaction_id AS txn_id,
  o.status        AS order_status,
  o.total         AS order_total
  FROM payments p JOIN orders o ON o.id = p.order_id
  WHERE p.order_id = 'e0000000-0000-0000-0000-000000000001';
-- Expected: payment_status='success', payment_method='cash_on_delivery',
--           payment_amount=1000, txn_id starts with 'COD-',
--           order_status='paid', order_total=1000

-- ============================================================
-- T10: No persistent state change
-- The entire script runs inside BEGIN...ROLLBACK. If the ROLLBACK
-- at the end succeeds, no test data or state changes persist.
-- To verify after running: check that none of the test UUIDs
-- exist in orders or payments.
-- ============================================================

ROLLBACK;

-- Post-rollback verification (run after the transaction rolls back):
-- SELECT count(*) FROM orders WHERE id LIKE 'e0000000%';
-- Expected: 0 (all test orders rolled back)
--
-- SELECT count(*) FROM payments WHERE order_id LIKE 'e0000000%';
-- Expected: 0 (all test payments rolled back)
--
-- SELECT count(*) FROM auth.users WHERE id LIKE 'd0000000%';
-- Note: auth.users rows are NOT rolled back because they are in
-- a different schema. Clean up manually if needed:
--   DELETE FROM auth.users WHERE id IN (
--     'd0000000-0000-0000-0000-000000000001',
--     'd0000000-0000-0000-0000-000000000002'
--   );

-- ============================================================
-- SUMMARY
-- ============================================================
-- T1    owner confirms pending COD         → ok=true,  code='confirmed'
-- T2    repeat call (idempotent)            → ok=true,  code='already_confirmed'
-- T3    anonymous rejected                  → ok=false, code='authentication_required'
-- T4    non-owner rejected                  → ok=false, code='not_owner'
-- T5    cancelled order rejected            → ok=false, code='order_not_pending'
-- T6    non-COD order rejected              → ok=false, code='payment_not_cod'
-- T7    failed payment rejected             → ok=false, code='payment_not_pending'
-- T8    missing payment auto-created        → ok=true,  code='confirmed'
-- T8b   missing payment idempotent          → ok=true,  code='already_confirmed'
-- T9    database state verified             → all columns correct
-- T10   rollback proves no persistence      → ROLLBACK succeeds
-- ============================================================
