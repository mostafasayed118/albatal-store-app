-- test_029_security_grant_repairs.sql
--
-- Read-only verification for migration 029 (Package K security grant repairs).
-- Run in the Supabase Dashboard SQL Editor or via:
--   supabase db execute --linked supabase/tests/test_029_security_grant_repairs.sql
--
-- This script performs NO mutations. It only reads catalog state.

-- 1. Migration high-water should include 029 (and 028 from Phase K0).
SELECT
  count(*) AS migration_count,
  max(version) AS high_water
FROM supabase_migrations.schema_migrations;

SELECT version
FROM supabase_migrations.schema_migrations
ORDER BY version;

-- Expected: high_water = 029; both 028 and 029 present.

-- 2. Anonymous/public write grants should be gone (expected: 0 rows).
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'public')
  AND table_name IN (
    'profiles',
    'addresses',
    'wishlists',
    'cart_items',
    'orders',
    'order_items',
    'payments',
    'notifications',
    'analytics_events',
    'error_logs'
  )
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY table_name, grantee, privilege_type;

-- Expected: 0 rows.

-- 3. Privileged RPC grants should match target.
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
  has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'decrement_stock',
    'increment_stock',
    'expire_pending_order',
    'set_payment_provider_order_id'
  )
ORDER BY p.proname;

-- Expected:
--   decrement_stock:               anon=false, authenticated=false, service_role=true
--   increment_stock:               anon=false, authenticated=false, service_role=true
--   expire_pending_order:          anon=false, authenticated=false, service_role=true
--   set_payment_provider_order_id: anon=false, authenticated=true,  service_role=true
