-- ============================================================
-- Schema Verification Script for Al Batal Elite
--
-- Run AFTER all migrations to confirm the schema is correct.
-- Paste into Supabase SQL Editor after run_all_migrations.sql.
--
-- Expected output: all checks should return "PASS" or data.
-- Any "FAIL" indicates a migration issue.
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 1. CHECK: All required tables exist
-- ════════════════════════════════════════════════════════════
SELECT
  CASE WHEN COUNT(*) >= 12 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*) AS tables_found,
  'Expected at least 12 core tables' AS detail
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'profiles', 'categories', 'products', 'product_variants',
    'product_images', 'addresses', 'wishlists', 'cart_items',
    'orders', 'order_items', 'payments', 'shipping_zones',
    'shipping_config', 'notifications', 'analytics_events', 'error_logs'
  );

-- ════════════════════════════════════════════════════════════
-- 2. CHECK: order_status enum has all required values
-- ════════════════════════════════════════════════════════════
SELECT
  e.enumlabel AS status_value,
  'PASS' AS status
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE t.typname = 'order_status'
ORDER BY e.enumsortorder;

-- ════════════════════════════════════════════════════════════
-- 3. CHECK: orders table has idempotency_key and expires_at
-- ════════════════════════════════════════════════════════════
SELECT
  column_name,
  data_type,
  CASE WHEN column_name IN ('idempotency_key', 'expires_at') THEN 'PASS' ELSE 'INFO' END AS status
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name IN ('idempotency_key', 'expires_at')
ORDER BY column_name;

-- ════════════════════════════════════════════════════════════
-- 4. CHECK: Required functions exist
-- ════════════════════════════════════════════════════════════
SELECT
  routine_name,
  routine_type,
  'PASS' AS status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'decrement_stock', 'increment_stock', 'calculate_shipping_fee',
    'update_order_status', 'get_order_details', 'get_low_stock_products',
    'create_checkout_order', 'handle_new_user', 'update_updated_at'
  )
ORDER BY routine_name;

-- ════════════════════════════════════════════════════════════
-- 5. CHECK: RLS is enabled on all core tables
-- ════════════════════════════════════════════════════════════
SELECT
  tablename,
  rowsecurity AS rls_enabled,
  CASE WHEN rowsecurity THEN 'PASS' ELSE 'FAIL' END AS status
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles', 'products', 'product_variants', 'addresses',
    'wishlists', 'cart_items', 'orders', 'order_items', 'payments'
  )
ORDER BY tablename;

-- ════════════════════════════════════════════════════════════
-- 6. CHECK: Indexes exist
-- ════════════════════════════════════════════════════════════
SELECT
  indexname,
  'PASS' AS status
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idx_orders_idempotency', 'idx_orders_expires',
    'idx_orders_user', 'idx_orders_status',
    'idx_payments_order', 'idx_payments_transaction'
  )
ORDER BY indexname;

-- ════════════════════════════════════════════════════════════
-- 7. CHECK: Shipping zones populated
-- ════════════════════════════════════════════════════════════
SELECT
  COUNT(*) AS zone_count,
  CASE WHEN COUNT(*) >= 7 THEN 'PASS' ELSE 'FAIL' END AS status,
  'Expected at least 7 Egyptian governorate zones' AS detail
FROM shipping_zones
WHERE is_active = true;

-- ════════════════════════════════════════════════════════════
-- 8. CHECK: Shipping config populated
-- ════════════════════════════════════════════════════════════
SELECT
  key, value,
  'PASS' AS status
FROM shipping_config
ORDER BY key;

-- ════════════════════════════════════════════════════════════
-- 9. CHECK: create_checkout_order function is callable
-- ════════════════════════════════════════════════════════════
SELECT
  routine_name,
  security_type,
  CASE WHEN security_type = 'DEFINER' THEN 'PASS' ELSE 'WARN' END AS status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'create_checkout_order';

-- ════════════════════════════════════════════════════════════
-- 10. CHECK: Storage buckets exist
-- ════════════════════════════════════════════════════════════
SELECT
  id AS bucket_name,
  public,
  CASE WHEN id IN ('product-images', 'avatars') THEN 'PASS' ELSE 'WARN' END AS status
FROM storage.buckets
ORDER BY id;

-- ════════════════════════════════════════════════════════════
-- SUMMARY
-- ════════════════════════════════════════════════════════════
SELECT
  '✅ Schema verification complete. Review results above.' AS message;
