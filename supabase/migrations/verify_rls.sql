-- ============================================================
-- RLS Verification Queries
-- Run these as a NON-ADMIN test user to verify access control
-- ============================================================

-- 1. Verify catalog is readable (should succeed)
SELECT COUNT(*) FROM products WHERE is_active = true;
SELECT COUNT(*) FROM categories WHERE is_active = true;
SELECT COUNT(*) FROM product_variants WHERE is_active = true;

-- 2. Verify user cannot read other users' data (should return 0 rows)
SELECT COUNT(*) FROM profiles WHERE id != auth.uid();
SELECT COUNT(*) FROM addresses WHERE user_id != auth.uid();
SELECT COUNT(*) FROM wishlists WHERE user_id != auth.uid();
SELECT COUNT(*) FROM cart_items WHERE user_id != auth.uid();
SELECT COUNT(*) FROM orders WHERE user_id != auth.uid();

-- 3. Verify user can read own data (should return own rows)
SELECT COUNT(*) FROM profiles WHERE id = auth.uid();
SELECT COUNT(*) FROM addresses WHERE user_id = auth.uid();
SELECT COUNT(*) FROM wishlists WHERE user_id = auth.uid();
SELECT COUNT(*) FROM cart_items WHERE user_id = auth.uid();
SELECT COUNT(*) FROM orders WHERE user_id = auth.uid();

-- 4. Verify order creation is blocked (should fail)
-- INSERT INTO orders (user_id, status, subtotal, shipping, total, payment_method, address_snapshot)
-- VALUES (auth.uid(), 'placed', 1000, 500, 1500, 'test', '{}');

-- 5. Verify non-admin cannot manage products (should fail)
-- UPDATE products SET name = 'hacked' WHERE id = 'some-id';
-- DELETE FROM products WHERE id = 'some-id';

-- 6. Verify admin CAN manage products (run as admin)
-- UPDATE products SET name = 'test' WHERE id = 'some-id';

-- 7. Verify storage access
-- Product images: public read should work
-- Avatars: only own avatar should be accessible
