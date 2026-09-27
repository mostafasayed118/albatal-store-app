-- supabase/tests/test_077_sample_metered_checkout.sql  (DRAFT for human review)
-- Run each block in the Supabase SQL Editor as an authenticated test user
-- AFTER applying migration 077. Uses scratch products with slug prefix
-- 't077-' and idempotency keys 't077-*'; every block cleans up after
-- itself. Replace the address city with a shippable governorate.
--
-- Expected before migration 077:
--   * blocks 1-4 raise 'Metered checkout is not available ...' (074
--     wrapper rejects sample/meters keys);
--   * app_config keys sample_price_minor / sample_max_per_order /
--     cut_max_meters do not exist.
-- Expected after migration 077: the asserts noted per block hold.

-- ─── Setup (run once): scratch category + products ─────────────
-- A metered fabric (sell_by_length, min_cut 1.0, base 10000 minor/m =
-- 100 EGP/m) with a '1m' stock variant of 100 m, plus a plain product
-- with a fixed 'M' variant. Remember the returned ids for the blocks.
/*
INSERT INTO categories (name, slug) VALUES ('T077', 't077')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (category_id, name, slug, base_price, is_active,
                      sell_by_length, min_cut_meters)
SELECT id, 'T077 Linen', 't077-linen', 10000, true, true, 1.0
FROM categories WHERE slug = 't077';

INSERT INTO products (category_id, name, slug, base_price, is_active)
SELECT id, 'T077 Scarf', 't077-scarf', 20000, true
FROM categories WHERE slug = 't077';

INSERT INTO product_variants (product_id, size, color, stock, is_active)
SELECT id, '1m', 'Emerald', 100, true FROM products WHERE slug = 't077-linen';

INSERT INTO product_variants (product_id, size, color, stock, is_active)
SELECT id, 'M', 'Emerald', 10, true FROM products WHERE slug = 't077-scarf';

SELECT (SELECT key || '=' || value FROM public.app_config
        WHERE key IN ('sample_price_minor','sample_max_per_order','cut_max_meters')
        ORDER BY key);
-- expect: cut_max_meters=50 / sample_max_per_order=10 / sample_price_minor=5000
*/

-- ─── TEST 1: sample line prices at sample_price_minor ──────────
-- Expected: order placed; subtotal = 5000 (one swatch line, qty 1);
-- order_items row has size='sample', unit_price=5000; variant stock -1.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-scarf'),
    'size', 'sample', 'color', 'Emerald', 'quantity', 1, 'sample', true)),
  p_idempotency_key := 't077-sample-1'
);
-- Assert: subtotal = 5000, total = 5000 + shipping, status='pending'
-- Assert: SELECT size, unit_price, quantity FROM order_items
--   WHERE order_id = <id>  ->  ('sample', 5000, 1)
-- Assert: variant stock for t077-scarf/M/Emerald went 10 -> 9
-- Cleanup:
-- DELETE FROM order_items WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-sample-1');
-- DELETE FROM payments WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-sample-1');
-- DELETE FROM orders WHERE idempotency_key='t077-sample-1';
-- UPDATE product_variants SET stock = 10 WHERE product_id=(SELECT id FROM products WHERE slug='t077-scarf');
*/

-- ─── TEST 2: sample with quantity 2 rejected ───────────────────
-- Expected: raises 'Sample lines allow quantity 1'; no order row.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-scarf'),
    'size', 'sample', 'color', 'Emerald', 'quantity', 2, 'sample', true)),
  p_idempotency_key := 't077-sample-2'
);
-- Assert: raises 22023 'Sample lines allow quantity 1'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key='t077-sample-2' = 0
*/

-- ─── TEST 3: metered 12.5 m prices with 5 % tier ───────────────
-- Math: base 10000 minor/m, 12.5 m -> tier 5 %; tiered/m =
-- 10000*95/100 = 9500; total = (10000*95*125*1+500)/1000 = 118750.
-- Client sends size='12.5', meters=12.5, line_total=118750,
-- tiered_price=9500.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-linen'),
    'size', '12.5', 'color', 'Emerald', 'quantity', 1,
    'meters', 12.5, 'line_total', 118750, 'tiered_price', 9500)),
  p_idempotency_key := 't077-metered-1'
);
-- Assert: subtotal = 118750; order_items row size='12.5', unit_price=9500
-- Assert: '1m'/Emerald stock went 100 -> 87 (CEIL(12.5) = 13)
-- Cleanup:
-- DELETE FROM order_items WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-metered-1');
-- DELETE FROM payments WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-metered-1');
-- DELETE FROM orders WHERE idempotency_key='t077-metered-1';
-- UPDATE product_variants SET stock = 100 WHERE product_id=(SELECT id FROM products WHERE slug='t077-linen');
*/

-- ─── TEST 4: tampered line_total rejected ──────────────────────
-- Expected: raises 22023 'Metered price mismatch'; no order row.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-linen'),
    'size', '12.5', 'color', 'Emerald', 'quantity', 1,
    'meters', 12.5, 'line_total', 100000, 'tiered_price', 9500)),
  p_idempotency_key := 't077-metered-2'
);
-- Assert: raises 22023 'Metered price mismatch for T077 Linen'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key='t077-metered-2' = 0
*/

-- ─── TEST 5: below min_cut rejected ────────────────────────────
-- Expected: 0.5 m < min_cut_meters 1.0 -> 22023 'Cut length ... outside'.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-linen'),
    'size', '0.5', 'color', 'Emerald', 'quantity', 1,
    'meters', 0.5, 'line_total', 5000)),
  p_idempotency_key := 't077-metered-3'
);
-- Assert: raises 22023 starting 'Cut length 0.5 m is outside'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key='t077-metered-3' = 0
*/

-- ─── TEST 6: meters on a non-fabric product rejected ───────────
-- Expected: 22023 'Metered checkout is not available for this order'.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-scarf'),
    'size', '2.0', 'color', 'Emerald', 'quantity', 1,
    'meters', 2.0, 'line_total', 40000)),
  p_idempotency_key := 't077-metered-4'
);
-- Assert: raises 22023 'Metered checkout is not available for this order'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key='t077-metered-4' = 0
*/

-- ─── TEST 7: plain fixed-size checkout unchanged ───────────────
-- Expected: prices from the variant (20000 x 2), stock -2.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t077-scarf'),
    'size', 'M', 'color', 'Emerald', 'quantity', 2)),
  p_idempotency_key := 't077-plain-1'
);
-- Assert: subtotal = 40000; variant stock went 10 -> 8
-- Cleanup:
-- DELETE FROM order_items WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-plain-1');
-- DELETE FROM payments WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t077-plain-1');
-- DELETE FROM orders WHERE idempotency_key='t077-plain-1';
-- UPDATE product_variants SET stock = 10 WHERE product_id=(SELECT id FROM products WHERE slug='t077-scarf');
*/

-- ─── Teardown (run last): remove scratch catalog ───────────────
/*
DELETE FROM product_variants WHERE product_id IN (SELECT id FROM products WHERE slug IN ('t077-linen','t077-scarf'));
DELETE FROM products WHERE slug IN ('t077-linen','t077-scarf');
DELETE FROM categories WHERE slug = 't077';
*/
