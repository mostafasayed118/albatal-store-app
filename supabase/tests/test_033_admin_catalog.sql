-- supabase/tests/test_033_admin_catalog.sql
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_033_admin_catalog.sql
-- Expected before migration: function does not exist
-- Expected after migration as anon / non-admin: ERROR not_admin (42501)
-- Expected after migration as admin: successful upsert / variant / images

-- 1. not_admin check: admin_upsert_product as anon should raise 42501
-- As anon: expect error 42501 not_admin
SELECT admin_upsert_product(NULL, 'Test', 'test-slug', 'desc', 'cotton', (SELECT id FROM categories LIMIT 1), 100, true);
-- expect: ERROR not_admin (SQLSTATE 42501)

-- 2. not_admin check: admin_upsert_variant as anon should raise 42501
SELECT admin_upsert_variant((SELECT id FROM products LIMIT 1), 'M', 'red', 10, NULL);
-- expect: ERROR not_admin (42501)

-- 3. not_admin check: admin_set_product_images as anon should raise 42501
SELECT admin_set_product_images((SELECT id FROM products LIMIT 1), ARRAY['product-images/' || (SELECT id FROM products LIMIT 1) || '/a.jpg']);
-- expect: ERROR not_admin (42501)

-- 4. get_active_flash_sales is accessible to anon (no not_admin) — should not error
SELECT * FROM get_active_flash_sales();
-- expect: 0 or more rows, no error (STABLE, SECURITY DEFINER, GRANT TO anon)

-- 5. prefix guard check (as admin would be needed; as anon still hits not_admin first)
-- If authenticated as non-admin, the prefix guard would be tested after not_admin.
-- After auth as admin, this should raise invalid_path 22000 when prefix mismatched:
-- SELECT admin_set_product_images((SELECT id FROM products LIMIT 1), ARRAY['wrong/prefix.jpg']);
-- expect: ERROR invalid_path (22000) when caller is admin

-- 6. Verify functions exist and have correct security attributes
SELECT 'assert_admin exists' AS check, (SELECT count(*) FROM pg_proc WHERE proname='assert_admin') AS cnt;
-- expect 1
SELECT 'assert_admin secdef' AS check, (SELECT prosecdef FROM pg_proc WHERE proname='assert_admin') AS is_secdef;
-- expect true
SELECT 'admin_upsert_product secdef' AS check, (SELECT prosecdef FROM pg_proc WHERE proname='admin_upsert_product') AS is_secdef;
-- expect true
SELECT 'admin_upsert_variant secdef' AS check, (SELECT prosecdef FROM pg_proc WHERE proname='admin_upsert_variant') AS is_secdef;
-- expect true
SELECT 'admin_set_product_images secdef' AS check, (SELECT prosecdef FROM pg_proc WHERE proname='admin_set_product_images') AS is_secdef;
-- expect true
SELECT 'get_active_flash_sales secdef' AS check, (SELECT prosecdef FROM pg_proc WHERE proname='get_active_flash_sales') AS is_secdef;
-- expect true
SELECT 'get_active_flash_sales stable' AS check, (SELECT provolatile FROM pg_proc WHERE proname='get_active_flash_sales') AS volatility;
-- expect 's' (STABLE)

-- 7. Verify search_path and grants
SELECT 'assert_admin search_path' AS check, (SELECT proconfig FROM pg_proc WHERE proname='assert_admin');
-- expect {search_path=public,pg_temp}
SELECT 'get_active_flash_sales granted to anon' AS check,
  (SELECT count(*) FROM information_schema.routine_privileges WHERE routine_name='get_active_flash_sales' AND grantee='anon') AS cnt;
-- expect 1
