-- supabase/tests/test_078_wholesale_tier.sql  (DRAFT for human review)
-- Run each block in the Supabase SQL Editor AFTER applying migration 078.
-- Uses scratch products with slug prefix 't078-' and idempotency keys
-- 't078-*'; every block cleans up after itself. Tiered blocks need TWO
-- test users: a wholesale member (tier set via admin_set_membership_tier
-- under service_role/admin) and a standard member. Replace the address
-- city with a shippable governorate.
--
-- Expected before migration 078:
--   * admin_set_membership_tier(x, 'wholesale') raises 'invalid_tier';
--   * wholesale_price_lists does not exist;
--   * wrapper delegates to unchecked_077 (no wholesale pricing).
-- Expected after migration 078: the asserts noted per block hold.

-- ─── Setup (run once): scratch category + products ─────────────
-- A plain fabric (base 20000 minor = 200 EGP) with an 'M' variant of
-- 10 units and a price_override variant row, plus a metered fabric
-- (sell_by_length, min_cut 1.0, base 10000 minor/m) with a '1m' stock
-- variant of 100 m. The wholesale list prices the plain fabric at
-- 15000 and the metered fabric at 8000/m. Remember the returned ids.
-- Tier assignment (service_role / admin session):
--   SELECT admin_set_membership_tier('<WHOLESALE_UID>', 'wholesale');
/*
INSERT INTO categories (name, slug) VALUES ('T078', 't078')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (category_id, name, slug, base_price, is_active)
SELECT id, 'T078 Scarf', 't078-scarf', 20000, true
FROM categories WHERE slug = 't078';

INSERT INTO products (category_id, name, slug, base_price, is_active,
                      sell_by_length, min_cut_meters)
SELECT id, 'T078 Linen', 't078-linen', 10000, true, true, 1.0
FROM categories WHERE slug = 't078';

INSERT INTO product_variants (product_id, size, color, stock, is_active)
SELECT id, 'M', 'Emerald', 10, true FROM products WHERE slug = 't078-scarf';

INSERT INTO product_variants (product_id, size, color, stock, is_active)
SELECT id, '1m', 'Emerald', 100, true FROM products WHERE slug = 't078-linen';

SELECT admin_upsert_wholesale_price(
  (SELECT id FROM products WHERE slug = 't078-scarf'), 15000);
SELECT admin_upsert_wholesale_price(
  (SELECT id FROM products WHERE slug = 't078-linen'), 8000);

-- expect: two rows, tier='wholesale' on both
SELECT slug, tier, price_minor FROM wholesale_price_lists w
JOIN products p ON p.id = w.product_id ORDER BY slug;
*/

-- ─── TEST 1: wholesale member plain checkout uses the list price ──
-- Run as the WHOLESALE test user.
-- Expected: order placed; subtotal = 15000 (qty 1 at list price, NOT
-- the 20000 base); order_items unit_price = 15000; variant stock 10->9.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t078-scarf'),
    'size', 'M', 'color', 'Emerald', 'quantity', 1)),
  p_idempotency_key := 't078-ws-plain-1'
);
-- Assert: subtotal = 15000, status='pending'
-- Assert: SELECT size, unit_price, quantity FROM order_items
--   WHERE order_id = <id>  ->  ('M', 15000, 1)
-- Assert: variant stock for t078-scarf/M/Emerald went 10 -> 9
-- Cleanup:
-- DELETE FROM order_items WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t078-ws-plain-1');
-- DELETE FROM payments WHERE order_id = (SELECT id FROM orders WHERE idempotency_key='t078-ws-plain-1');
-- DELETE FROM orders WHERE idempotency_key='t078-ws-plain-1';
-- UPDATE product_variants SET stock = 10 WHERE product_id=(SELECT id FROM products WHERE slug='t078-scarf');
*/

-- ─── TEST 2: standard member ignores the list row ───────────────
-- Run as the STANDARD test user on the SAME product.
-- Expected: subtotal = 20000 (base price); unit_price = 20000.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t078-scarf'),
    'size', 'M', 'color', 'Emerald', 'quantity', 1)),
  p_idempotency_key := 't078-std-plain-1'
);
-- Assert: subtotal = 20000, unit_price = 20000
-- Cleanup: same shape as TEST 1 with key 't078-std-plain-1';
-- reset stock to 10 afterwards.
*/

-- ─── TEST 3: price-list RLS (wholesale sees, others do not) ─────
-- As WHOLESALE user: expect 2 rows (the t078- scratch rows among them).
-- As STANDARD user: expect 0 rows. As anon (no JWT): expect 0 rows /
-- 42501-safe empty (SELECT denied → empty set, never an error leak).
/*
SELECT count(*) FROM wholesale_price_lists WHERE tier = 'wholesale';
-- wholesale user: >= 2; standard/anon: 0
*/

-- ─── TEST 4: wholesale metered cut uses the list base ───────────
-- Run as the WHOLESALE test user. 12.5 m of t078-linen: list base
-- 8000/m, 5 % meter tier (>= 10 m) → per-meter 7600, total =
-- (8000*95*125*1+500)/1000 = 95000. Client submits line_total 95000
-- + tiered_price 7600.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t078-linen'),
    'size', '12.5', 'color', 'Emerald', 'quantity', 1,
    'meters', 12.5, 'line_total', 95000, 'tiered_price', 7600)),
  p_idempotency_key := 't078-ws-meter-1'
);
-- Assert: subtotal = 95000, unit_price = 7600, size = '12.5'
-- Assert: '1m' variant stock went 100 -> 87 (CEIL(12.5))
-- Cleanup: same shape as TEST 1 with key 't078-ws-meter-1';
-- reset '1m' stock to 100 afterwards.
*/

-- ─── TEST 5: tampered wholesale totals still rejected ───────────
-- Same as TEST 4 but line_total 94000 (off by 1000).
-- Expected: raises 22023 'Metered price mismatch'; no order row.
/*
SELECT create_checkout_order(
  p_payment_method := 'cod',
  p_address := '{"recipient":"T","line":"1 St","city":"Cairo","phone":"+201001234567"}'::JSONB,
  p_items := jsonb_build_array(jsonb_build_object(
    'product_id', (SELECT id::TEXT FROM products WHERE slug='t078-linen'),
    'size', '12.5', 'color', 'Emerald', 'quantity', 1,
    'meters', 12.5, 'line_total', 94000, 'tiered_price', 7600)),
  p_idempotency_key := 't078-ws-meter-tamper'
);
-- Assert: raises 22023 'Metered price mismatch for T078 Linen'
-- Assert: SELECT count(*) FROM orders WHERE idempotency_key='t078-ws-meter-tamper' = 0
*/

-- ─── TEST 6: tier RPC + self-service guards ─────────────────────
-- As admin/service_role:
--   SELECT admin_set_membership_tier('<UID>', 'wholesale');  -- works
--   SELECT admin_set_membership_tier('<UID>', 'platinum');
--     -- raises 22023 'invalid_tier'
--   SELECT admin_upsert_wholesale_price('<PRODUCT_UUID>', -5);
--     -- raises 22023 'invalid_price'
--   SELECT admin_upsert_wholesale_price('00000000-0000-0000-0000-000000000000', 100);
--     -- raises P0002 'product_not_found'
--   SELECT admin_delete_wholesale_price('00000000-0000-0000-0000-000000000000');
--     -- raises P0002 'price_not_found'
-- As the STANDARD test user (self UPDATE attempt):
--   UPDATE profiles SET membership_tier='wholesale' WHERE id=auth.uid();
--     -- 0 rows updated (WITH CHECK pins to existing row)
-- Reset the wholesale test user afterwards:
--   SELECT admin_set_membership_tier('<WHOLESALE_UID>', 'standard');
*/

-- ─── Teardown (run last): remove scratch rows ───────────────────
/*
DELETE FROM wholesale_price_lists
 WHERE product_id IN (SELECT id FROM products WHERE slug LIKE 't078-%');
DELETE FROM product_variants
 WHERE product_id IN (SELECT id FROM products WHERE slug LIKE 't078-%');
DELETE FROM products WHERE slug LIKE 't078-%';
DELETE FROM categories WHERE slug = 't078';
-- expect: wholesale_price_lists holds no t078- rows afterwards
*/
