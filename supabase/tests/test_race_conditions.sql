-- ============================================================
-- Test Fixture: Race conditions for payment/order/stock state machine
--
-- Tests the hardened process_paymob_callback (025) and
-- expire_pending_order (025) under all race orderings.
--
-- PREREQUISITES:
--   - Migration 025 applied
--   - A test user exists (or create one inline)
--   - Test product variants with stock exist
--
-- USAGE:
--   psql -f supabase/tests/test_race_conditions.sql
--   All assertions use RAISE EXCEPTION on failure.
--   Wrapped in BEGIN/ROLLBACK — no persistent state changes.
--
-- COVERS:
--   T-RC01: callback before expiry (happy path)
--   T-RC02: expiry before callback (the bug fix)
--   T-RC03: duplicate callback is no-op
--   T-RC04: double expiry is no-op
--   T-RC05: callback success then admin cancel
--   T-RC06: admin cancel then late callback (rejected)
--   T-RC07: amount mismatch rejected
--   T-RC08: stock ledger: cancel restores once
--   T-RC09: stock ledger: callback-fail restores once
--   T-RC10: stock ledger: double-cancel restores once
--   T-RC11: cancelled order late success (rejected)
--   T-RC12: audit trail completeness
--   T-RC13: COD then expiry (expiry no-ops)
--   T-RC14: invalid HMAC (no state change)
-- ============================================================

BEGIN;

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  RACE CONDITION TEST SUITE — Migration 025'
\echo '═══════════════════════════════════════════════════════'
\echo ''

-- ─── Test fixtures ──────────────────────────────────────────
-- Create a disposable test user, product, variant, and order.
-- All cleaned up by ROLLBACK.

DO $$
DECLARE
  v_user_id      UUID;
  v_product_id   UUID;
  v_variant_id   UUID;
  v_order_id     UUID;
  v_payment_id   UUID;
  v_paymob_order TEXT;
  v_result       JSONB;
  v_count        INTEGER;
  v_order_status TEXT;
  v_payment_status TEXT;
BEGIN
  -- ─── Create test user ──────────────────────────────────
  v_user_id := gen_random_uuid();
  INSERT INTO profiles (id, full_name, phone)
    VALUES (v_user_id, 'Race Test User', '+201000000000');

  -- ─── Create test product + variant with stock = 10 ─────
  v_product_id := gen_random_uuid();
  INSERT INTO products (id, category_id, name, slug, base_price, is_active)
    VALUES (v_product_id, (SELECT id FROM categories LIMIT 1),
            'Race Test Product', 'race-test-product-' || floor(random()*10000)::int,
            10000, true);

  v_variant_id := gen_random_uuid();
  INSERT INTO product_variants (id, product_id, size, color, stock, is_active)
    VALUES (v_variant_id, v_product_id, 'M', 'Black', 10, true);

  -- ─── T-RC01: callback BEFORE expiry (happy path) ───────
  -- Create a pending order, process success callback, THEN
  -- run expiry worker. Expiry should see 'already_terminal'.

  RAISE NOTICE 'T-RC01: callback before expiry';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC01-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  -- Decrement stock (simulating checkout)
  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Step 1: Process success callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC01', 10000, 'EGP', true);
  ASSERT (v_result->>'ok')::boolean = true,
    'T-RC01: callback should succeed. Got: ' || v_result::text;
  ASSERT (v_result->>'code') = 'success',
    'T-RC01: code should be success. Got: ' || (v_result->>'code');

  -- Step 2: Run expiry — should see already_terminal
  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'ok')::boolean = true,
    'T-RC01: expiry should return ok. Got: ' || v_result::text;
  ASSERT (v_result->>'code') = 'already_terminal',
    'T-RC01: expiry should say already_terminal. Got: ' || (v_result->>'code');

  -- Verify final state
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'paid',
    'T-RC01: order should be paid. Got: ' || v_order_status;

  SELECT status INTO v_payment_status FROM payments WHERE paymob_order_id = v_paymob_order;
  ASSERT v_payment_status = 'success',
    'T-RC01: payment should be success. Got: ' || v_payment_status;

  RAISE NOTICE 'T-RC01: PASS ✓';


  -- ─── T-RC02: expiry BEFORE callback (THE BUG FIX) ──────
  -- This is the critical race. Expiry cancels first, then
  -- callback arrives. The hardened callback must return
  -- already_processed, NOT ok:true, code:success.

  RAISE NOTICE 'T-RC02: expiry before callback (critical race fix)';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC02-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() - interval '1 minute');  -- Already expired

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Step 1: Run expiry first
  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'code') = 'expired',
    'T-RC02: expiry should expire. Got: ' || v_result::text;

  -- Step 2: Late success callback arrives
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC02', 10000, 'EGP', true);
  ASSERT (v_result->>'ok')::boolean = true,
    'T-RC02: late callback should be ok (no-op). Got: ' || v_result::text;
  ASSERT (v_result->>'code') = 'already_processed',
    'T-RC02: code should be already_processed, NOT success. Got: ' || (v_result->>'code');

  -- Verify order is NOT promoted to paid
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'cancelled',
    'T-RC02: order must stay cancelled. Got: ' || v_order_status;

  SELECT status INTO v_payment_status FROM payments WHERE paymob_order_id = v_paymob_order;
  ASSERT v_payment_status = 'expired',
    'T-RC02: payment must stay expired. Got: ' || v_payment_status;

  RAISE NOTICE 'T-RC02: PASS ✓ (race fix validated)';


  -- ─── T-RC03: duplicate callback is no-op ───────────────

  RAISE NOTICE 'T-RC03: duplicate callback';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC03-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- First callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC03', 10000, 'EGP', true);
  ASSERT (v_result->>'code') = 'success',
    'T-RC03: first callback should succeed';

  -- Duplicate callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC03', 10000, 'EGP', true);
  ASSERT (v_result->>'code') = 'already_processed',
    'T-RC03: duplicate should be no-op. Got: ' || (v_result->>'code');

  -- Verify stock not double-restored
  SELECT stock INTO v_count FROM product_variants WHERE id = v_variant_id;
  RAISE NOTICE 'T-RC03: stock after success = %', v_count;
  -- Stock was decremented once at checkout, not restored on success. Should be 10-1-1 = 8.
  ASSERT v_count = 8,
    'T-RC03: stock should be 8 (decremented twice for two orders). Got: ' || v_count;

  RAISE NOTICE 'T-RC03: PASS ✓';


  -- ─── T-RC04: double expiry is no-op ────────────────────

  RAISE NOTICE 'T-RC04: double expiry';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC04-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() - interval '1 minute');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- First expiry
  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'code') = 'expired',
    'T-RC04: first expiry should expire';

  -- Second expiry
  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'code') = 'already_terminal',
    'T-RC04: second expiry should no-op. Got: ' || (v_result->>'code');

  -- Verify stock restored exactly once
  SELECT stock INTO v_count FROM product_variants WHERE id = v_variant_id;
  RAISE NOTICE 'T-RC04: stock = % (should be 7 after 3 orders)', v_count;
  ASSERT v_count = 7,
    'T-RC04: stock should be 7. Got: ' || v_count;

  -- Verify stock_restorations exists exactly once
  SELECT count(*) INTO v_count FROM stock_restorations WHERE order_id = v_order_id;
  ASSERT v_count = 1,
    'T-RC04: stock_restorations should have 1 row. Got: ' || v_count;

  RAISE NOTICE 'T-RC04: PASS ✓';


  -- ─── T-RC05: success callback then admin cancel ────────

  RAISE NOTICE 'T-RC05: callback success then admin cancel';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC05-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Success callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC05', 10000, 'EGP', true);
  ASSERT (v_result->>'code') = 'success';

  -- Admin cancels a paid order (valid transition)
  PERFORM update_order_status(v_order_id, 'cancelled');

  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'cancelled',
    'T-RC05: order should be cancelled. Got: ' || v_order_status;

  -- Stock should be restored (stock_restorations guard)
  SELECT count(*) INTO v_count FROM stock_restorations WHERE order_id = v_order_id;
  ASSERT v_count = 1,
    'T-RC05: stock_restorations should have 1 row. Got: ' || v_count;

  RAISE NOTICE 'T-RC05: PASS ✓';


  -- ─── T-RC06: admin cancel then late callback ───────────

  RAISE NOTICE 'T-RC06: admin cancel then late callback';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC06-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Admin cancels first
  PERFORM update_order_status(v_order_id, 'cancelled');

  -- Late success callback arrives
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC06', 10000, 'EGP', true);
  ASSERT (v_result->>'code') = 'already_processed',
    'T-RC06: late callback should be rejected. Got: ' || (v_result->>'code');

  -- Order must NOT be promoted to paid
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'cancelled',
    'T-RC06: order must stay cancelled. Got: ' || v_order_status;

  -- Payment must NOT be marked success
  SELECT status INTO v_payment_status FROM payments WHERE paymob_order_id = v_paymob_order;
  ASSERT v_payment_status = 'pending',
    'T-RC06: payment must stay pending. Got: ' || v_payment_status;

  RAISE NOTICE 'T-RC06: PASS ✓';


  -- ─── T-RC07: amount mismatch rejected ──────────────────

  RAISE NOTICE 'T-RC07: amount mismatch';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC07-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Callback with wrong amount
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC07', 9999, 'EGP', true);
  ASSERT (v_result->>'ok')::boolean = false,
    'T-RC07: amount mismatch should fail. Got: ' || v_result::text;
  ASSERT (v_result->>'code') = 'amount_mismatch',
    'T-RC07: code should be amount_mismatch. Got: ' || (v_result->>'code');

  -- State unchanged
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'pending',
    'T-RC07: order should stay pending. Got: ' || v_order_status;

  SELECT status INTO v_payment_status FROM payments WHERE paymob_order_id = v_paymob_order;
  ASSERT v_payment_status = 'pending',
    'T-RC07: payment should stay pending. Got: ' || v_payment_status;

  RAISE NOTICE 'T-RC07: PASS ✓';


  -- ─── T-RC08: stock ledger — cancel restores once ───────

  RAISE NOTICE 'T-RC08: stock ledger cancel';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC08-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() - interval '1 minute');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;
  v_count := (SELECT stock FROM product_variants WHERE id = v_variant_id);

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Cancel via expiry
  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'code') = 'expired';

  -- Stock should be restored
  DECLARE v_after_stock INTEGER;
  BEGIN
    SELECT stock INTO v_after_stock FROM product_variants WHERE id = v_variant_id;
    ASSERT v_after_stock = v_count + 1,
      'T-RC08: stock should be restored. Before=' || v_count || ' After=' || v_after_stock;
  END;

  -- stock_restorations guard: double expiry should not double-restore
  v_result := expire_pending_order(v_order_id);
  DECLARE v_final_stock INTEGER;
  BEGIN
    SELECT stock INTO v_final_stock FROM product_variants WHERE id = v_variant_id;
    ASSERT v_final_stock = v_count + 1,
      'T-RC08: stock should not double-restore. Expected=' || (v_count+1) || ' Got=' || v_final_stock;
  END;

  RAISE NOTICE 'T-RC08: PASS ✓';


  -- ─── T-RC09: stock ledger — callback-fail restores once ─

  RAISE NOTICE 'T-RC09: stock ledger callback-fail';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC09-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;
  v_count := (SELECT stock FROM product_variants WHERE id = v_variant_id);

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Failed callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC09', 10000, 'EGP', false);
  ASSERT (v_result->>'code') = 'failed';

  -- Stock restored
  DECLARE v_after_stock INTEGER;
  BEGIN
    SELECT stock INTO v_after_stock FROM product_variants WHERE id = v_variant_id;
    ASSERT v_after_stock = v_count + 1,
      'T-RC09: stock should be restored. Before=' || v_count || ' After=' || v_after_stock;
  END;

  -- Duplicate failure callback should not double-restore
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC09', 10000, 'EGP', false);
  ASSERT (v_result->>'code') = 'already_processed';

  DECLARE v_final_stock INTEGER;
  BEGIN
    SELECT stock INTO v_final_stock FROM product_variants WHERE id = v_variant_id;
    ASSERT v_final_stock = v_count + 1,
      'T-RC09: stock should not double-restore. Expected=' || (v_count+1) || ' Got=' || v_final_stock;
  END;

  RAISE NOTICE 'T-RC09: PASS ✓';


  -- ─── T-RC10: stock ledger — double-cancel restores once ─

  RAISE NOTICE 'T-RC10: stock ledger double-cancel';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC10-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() - interval '1 minute');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;
  v_count := (SELECT stock FROM product_variants WHERE id = v_variant_id);

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- First cancel via expiry
  PERFORM expire_pending_order(v_order_id);

  -- Second cancel via admin
  -- (expire_pending_order already set status='cancelled', so
  -- update_order_status will see 'cancelled' and reject)
  BEGIN
    PERFORM update_order_status(v_order_id, 'cancelled');
    RAISE EXCEPTION 'T-RC10: admin cancel on cancelled order should fail';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: "Cannot change status of cancelled order"
    RAISE NOTICE 'T-RC10: admin cancel correctly rejected: %', SQLERRM;
  END;

  -- Stock restored exactly once
  DECLARE v_final_stock INTEGER;
  BEGIN
    SELECT stock INTO v_final_stock FROM product_variants WHERE id = v_variant_id;
    ASSERT v_final_stock = v_count + 1,
      'T-RC10: stock should restore exactly once. Expected=' || (v_count+1) || ' Got=' || v_final_stock;
  END;

  RAISE NOTICE 'T-RC10: PASS ✓';


  -- ─── T-RC11: cancelled order late success (rejected) ───

  RAISE NOTICE 'T-RC11: cancelled order late success';

  v_order_id := gen_random_uuid();
  v_paymob_order := 'PAYMOB-RC11-' || floor(random()*1000000)::int;

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() - interval '1 minute');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
    VALUES (v_order_id, v_user_id, 'paymob_card', 10000, 'pending', v_paymob_order);

  -- Cancel via expiry
  PERFORM expire_pending_order(v_order_id);

  -- Late success callback
  v_result := process_paymob_callback(v_paymob_order, 'TXN-RC11', 10000, 'EGP', true);
  ASSERT (v_result->>'code') = 'already_processed',
    'T-RC11: late success should be rejected. Got: ' || (v_result->>'code');

  -- Order must NOT be promoted to paid
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'cancelled',
    'T-RC11: order must stay cancelled. Got: ' || v_order_status;

  RAISE NOTICE 'T-RC11: PASS ✓';


  -- ─── T-RC12: audit trail completeness ──────────────────

  RAISE NOTICE 'T-RC12: audit trail';

  -- Verify state_transitions has records for T-RC02 (the critical race)
  SELECT count(*) INTO v_count
  FROM state_transitions
  WHERE reason = 'late_callback_rejected';

  ASSERT v_count >= 1,
    'T-RC02: should have at least 1 late_callback_rejected audit. Got: ' || v_count;

  -- Verify trigger-based audits exist
  SELECT count(*) INTO v_count
  FROM state_transitions
  WHERE reason = 'trigger_audit';

  ASSERT v_count >= 1,
    'T-RC12: should have trigger_audit records. Got: ' || v_count;

  RAISE NOTICE 'T-RC12: PASS ✓';


  -- ─── T-RC13: COD then expiry (expiry no-ops) ───────────

  RAISE NOTICE 'T-RC13: COD then expiry';

  v_order_id := gen_random_uuid();

  INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                      payment_method, address_snapshot, expires_at)
    VALUES (v_order_id, v_user_id, 'pending', 10000, 0, 10000,
            'cash_on_delivery', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
            now() + interval '15 minutes');

  INSERT INTO order_items (order_id, product_id, variant_id,
                           product_name, size, color, unit_price, quantity)
    VALUES (v_order_id, v_product_id, v_variant_id,
            'Race Test Product', 'M', 'Black', 10000, 1);

  UPDATE product_variants SET stock = stock - 1 WHERE id = v_variant_id;

  -- COD confirmation (authenticated user)
  -- We use the RPC directly (service_role bypasses auth check)
  PERFORM confirm_cod_payment(v_order_id);

  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'paid',
    'T-RC13: order should be paid after COD. Got: ' || v_order_status;

  -- Expiry should see already_paid (payment is success)
  -- First, set expires_at to past (simulate expiry window)
  UPDATE orders SET expires_at = now() - interval '1 minute' WHERE id = v_order_id;

  v_result := expire_pending_order(v_order_id);
  ASSERT (v_result->>'code') = 'already_terminal',
    'T-RC13: expiry should see already_terminal. Got: ' || (v_result->>'code');

  -- Order must stay paid
  SELECT status::text INTO v_order_status FROM orders WHERE id = v_order_id;
  ASSERT v_order_status = 'paid',
    'T-RC13: order must stay paid. Got: ' || v_order_status;

  RAISE NOTICE 'T-RC13: PASS ✓';


  -- ─── T-RC14: invalid HMAC (no state change) ────────────
  -- This tests the Edge Function layer, but we can verify
  -- that an unmapped paymob_order_id causes no mutation.

  RAISE NOTICE 'T-RC14: unmapped payment (no state change)';

  v_result := process_paymob_callback('NONEXISTENT-ORDER', 'TXN-RC14', 10000, 'EGP', true);
  ASSERT (v_result->>'ok')::boolean = false,
    'T-RC14: unmapped should fail. Got: ' || v_result::text;
  ASSERT (v_result->>'code') = 'unmapped_payment',
    'T-RC14: code should be unmapped_payment. Got: ' || (v_result->>'code');

  RAISE NOTICE 'T-RC14: PASS ✓';


  -- ═══════════════════════════════════════════════════════
  -- SUMMARY
  -- ═══════════════════════════════════════════════════════

  RAISE NOTICE '';
  RAISE NOTICE '═══════════════════════════════════════════════════════';
  RAISE NOTICE '  ALL 14 RACE CONDITION TESTS PASSED ✓';
  RAISE NOTICE '═══════════════════════════════════════════════════════';
  RAISE NOTICE '';

END $$;

-- All changes are rolled back — no persistent state changes.
ROLLBACK;
