-- ============================================================
-- RPC Test Cases for create_checkout_order
--
-- These are manual SQL test cases to run against a deployed
-- Supabase database AFTER applying migration 013. They verify
-- the server-authoritative checkout behavior that cannot be
-- tested from Dart (price authority, stock atomicity, rollback,
-- shipping-zone calculation, idempotency at the DB level).
--
-- Run each block in the Supabase SQL Editor as an authenticated
-- test user. Replace <TEST_USER_ID> with a real auth.users id.
-- ============================================================

-- ─── TEST 1: Successful order creation ─────────────────────
-- Expected: A new order is created with status='pending', correct
-- totals from DB prices, and stock is decremented.

-- Prerequisites: A test product with variants exists in the DB.
-- Run as an authenticated user with a valid JWT.

/*
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-001'
);
-- Assert: returns JSONB with order_id (UUID), subtotal, shipping, total, status='pending'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key = 'test-key-001' = 1
-- Assert: SELECT count(*) FROM order_items WHERE order_id = <returned order_id> = 1
-- Assert: stock for the variant decreased by 1
*/

-- ─── TEST 2: Insufficient stock ────────────────────────────
-- Expected: Exception raised, no order created, no stock change.

/*
-- Set up: ensure variant has stock = 1
UPDATE product_variants SET stock = 1 WHERE product_id = '<PRODUCT_UUID>' AND size = '2m' AND color = 'Emerald';

SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":5}]'::JSONB,
  p_idempotency_key := 'test-key-stock'
);
-- Assert: raises 'Insufficient stock for ...'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key = 'test-key-stock' = 0
*/

-- ─── TEST 3: Retry with same idempotency key ───────────────
-- Expected: Returns the SAME order, no second order, no second stock decrement.

/*
-- First call
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-retry'
);

-- Second call with same key
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-retry'
);
-- Assert: both calls return the SAME order_id
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key = 'test-key-retry' = 1
-- Assert: "idempotent" field is true on the second call
-- Assert: stock was decremented only once (by 1, not by 2)
*/

-- ─── TEST 4: Rollback on forced failure ────────────────────
-- Expected: When a stock race occurs (stock changes between
-- validation and decrement), the entire transaction rolls back.
-- No order, no order_items, no stock change.

/*
-- Set up: stock = 2
UPDATE product_variants SET stock = 2 WHERE product_id = '<PRODUCT_UUID>' AND size = '2m' AND color = 'Emerald';

-- In a concurrent scenario, another transaction decrements stock
-- between the validation SELECT and the UPDATE. To simulate:
-- Use a trigger that decrements stock before the RPC's UPDATE
-- runs, or run two concurrent calls with quantity that exceeds
-- available stock when combined.

-- Simple simulation: request quantity=3 when stock=2
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":3}]'::JSONB,
  p_idempotency_key := 'test-key-rollback'
);
-- Assert: raises 'Insufficient stock'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key = 'test-key-rollback' = 0
-- Assert: SELECT count(*) FROM order_items = 0 (for this key)
-- Assert: stock unchanged (still 2)
*/

-- ─── TEST 5: Server price differs from client ──────────────
-- Expected: The RPC reads the DB price, not any client-provided
-- price. The client only sends product_id, size, color, quantity.
-- No price field is accepted.

-- The RPC signature does NOT accept a price parameter. The unit
-- price is always read from product_variants.price_override or
-- products.base_price. This is verified by design: there is no
-- p_price parameter.

-- To verify the correct price is used:
/*
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-price'
);
-- Assert: returned subtotal = DB price for the variant
-- Assert: order_items.unit_price = COALESCE(variant.price_override, product.base_price)
*/

-- ─── TEST 6: Server shipping differs from client ────────────
-- Expected: Shipping is calculated via calculate_shipping_fee()
-- using the address's city as the governorate. The client cannot
-- influence the shipping fee.

-- The RPC signature does NOT accept a shipping parameter. It
-- calls calculate_shipping_fee(p_governorate, p_subtotal) with
-- the city from p_address. This is verified by design.

-- To verify Cairo gets the Cairo & Giza zone fee:
/*
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-ship-cairo'
);
-- Assert: returned shipping = Cairo zone fee (5000) or 0 if subtotal >= free_shipping_threshold

-- Verify Alexandria gets a different fee:
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Alexandria","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-ship-alex'
);
-- Assert: returned shipping = Alexandria zone fee (6000) or 0 if subtotal >= threshold
*/

-- ─── TEST 7: Unauthorized caller rejection ─────────────────
-- Expected: When auth.uid() is NULL (unauthenticated), the RPC
-- raises 'Authentication required'.

-- Run as an unauthenticated client (no JWT):
/*
SELECT create_checkout_order(
  p_payment_method := 'paymob_card',
  p_address := '{"recipient":"Test","line":"123 St","city":"Cairo","country":"Egypt"}'::JSONB,
  p_items := '[{"product_id":"<PRODUCT_UUID>","size":"2m","color":"Emerald","quantity":1}]'::JSONB,
  p_idempotency_key := 'test-key-noauth'
);
-- Assert: raises 'Authentication required'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key = 'test-key-noauth' = 0
*/
