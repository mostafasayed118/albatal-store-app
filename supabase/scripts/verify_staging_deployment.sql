-- ============================================================
-- Al Batal Elite — Staging Deployment Verification
--
-- Run in Supabase SQL Editor (or psql) against the STAGING
-- database AFTER `supabase db push` completes.
--
-- Every section below prints a PASS/FAIL table. All rows must
-- show PASS for staging to be considered GO.
--
-- SAFETY: This script is READ-ONLY. It does not write, update,
-- or delete any data. Safe to re-run any number of times.
-- ============================================================

\set ECHO on

-- ============================================================
-- SECTION 1: Migration files applied
-- Supabase tracks applied migrations in supabase_migrations
-- .schema_migrations. We expect exactly 19 migrations
-- (001 through 019).
-- ============================================================

\echo '\n=== SECTION 1: Applied migrations ==='

SELECT
  'total_migrations_applied' AS check_name,
  count(*)::text              AS expected,
  CASE WHEN count(*) >= 19 THEN 'PASS' ELSE 'FAIL' END AS status
FROM supabase_migrations.schema_migrations

UNION ALL

SELECT
  'migration_018_confirm_cod_payment' AS check_name,
  'present'                           AS expected,
  CASE WHEN EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version LIKE '%018_confirm_cod_payment%'
  ) THEN 'PASS' ELSE 'FAIL' END AS status

UNION ALL

SELECT
  'migration_019_harden_rpc_grants' AS check_name,
  'present'                         AS expected,
  CASE WHEN EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version LIKE '%019_harden_rpc%'
  ) THEN 'PASS' ELSE 'FAIL' END AS status;


-- ============================================================
-- SECTION 2: RPC existence + signature
-- Confirms the 4 critical RPCs exist with the expected
-- parameter types (so PostgREST can route the Flutter calls).
-- ============================================================

\echo '\n=== SECTION 2: RPC existence + signature ==='

SELECT
  proname AS rpc_name,
  pg_get_function_identity_arguments(oid) AS args,
  CASE
    WHEN proname = 'confirm_cod_payment'
       AND pg_get_function_identity_arguments(oid) = 'uuid'
    THEN 'PASS'
    WHEN proname = 'create_checkout_order'
       AND pg_get_function_identity_arguments(oid) = 'text, jsonb, jsonb, text'
    THEN 'PASS'
    WHEN proname = 'update_order_status'
       AND pg_get_function_identity_arguments(oid) = 'uuid, text, text'
    THEN 'PASS'
    WHEN proname = 'process_paymob_callback'
       AND pg_get_function_identity_arguments(oid) = 'text, text, integer, text, boolean'
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM pg_proc
WHERE proname IN (
  'confirm_cod_payment',
  'create_checkout_order',
  'update_order_status',
  'process_paymob_callback'
)
AND pronamespace = 'public'::regnamespace
ORDER BY proname;


-- ============================================================
-- SECTION 3: RPC EXECUTE grants (least privilege)
--
-- Required state:
--   confirm_cod_payment      → authenticated (NOT anon, NOT public)
--   create_checkout_order    → authenticated (NOT anon, NOT public)
--   update_order_status      → authenticated (NOT anon, NOT public)
--   process_paymob_callback  → service_role  (NOT anon, NOT authenticated)
-- ============================================================

\echo '\n=== SECTION 3: RPC EXECUTE grants ==='

-- Helper: does role R have EXECUTE on function F(args)?
-- proacl is null when default privileges apply; we treat null
-- as "PUBLIC has it" (the pre-019 state, which must be fixed).
SELECT
  f.proname AS rpc_name,
  CASE
    WHEN f.proname = 'confirm_cod_payment'     THEN 'authenticated'
    WHEN f.proname = 'create_checkout_order'  THEN 'authenticated'
    WHEN f.proname = 'update_order_status'    THEN 'authenticated'
    WHEN f.proname = 'process_paymob_callback' THEN 'service_role'
  END AS expected_grantee,
  CASE
    WHEN f.proname = 'confirm_cod_payment'
      AND has_function_privilege('authenticated',  f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon',        f.oid, 'EXECUTE')
      THEN 'PASS'
    WHEN f.proname = 'create_checkout_order'
      AND has_function_privilege('authenticated',  f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon',        f.oid, 'EXECUTE')
      THEN 'PASS'
    WHEN f.proname = 'update_order_status'
      AND has_function_privilege('authenticated',  f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon',        f.oid, 'EXECUTE')
      THEN 'PASS'
    WHEN f.proname = 'process_paymob_callback'
      AND has_function_privilege('service_role',   f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon',        f.oid, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', f.oid, 'EXECUTE')
      THEN 'PASS'
    ELSE 'FAIL'
  END AS status,
  coalesce(f.proacl::text, 'NULL (default→PUBLIC)') AS current_acl
FROM pg_proc f
WHERE f.proname IN (
  'confirm_cod_payment',
  'create_checkout_order',
  'update_order_status',
  'process_paymob_callback'
)
AND f.pronamespace = 'public'::regnamespace
ORDER BY f.proname;


-- ============================================================
-- SECTION 4: Seed catalog exists
-- Migration 016 seeds 5 categories, 9 products, 81 variants.
-- ============================================================

\echo '\n=== SECTION 4: Seed catalog ==='

SELECT
  'categories' AS table_name,
  '5'          AS expected,
  count(*)::text AS actual,
  CASE WHEN count(*) >= 5 THEN 'PASS' ELSE 'FAIL' END AS status
FROM categories

UNION ALL

SELECT
  'products',
  '9',
  count(*)::text,
  CASE WHEN count(*) >= 9 THEN 'PASS' ELSE 'FAIL' END
FROM products

UNION ALL

SELECT
  'product_variants',
  '81',
  count(*)::text,
  CASE WHEN count(*) >= 81 THEN 'PASS' ELSE 'FAIL' END
FROM product_variants

UNION ALL

SELECT
  'seeded_product_silk_01',
  'present',
  CASE WHEN count(*) > 0 THEN 'present' ELSE 'missing' END,
  CASE WHEN count(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM products
WHERE slug = 'silk-01';


-- ============================================================
-- SECTION 5: RLS enabled on user-scoped tables
-- Every table that holds user-owned rows must have RLS on.
-- ============================================================

\echo '\n=== SECTION 5: RLS enabled ==='

SELECT
  c.relname AS table_name,
  CASE WHEN c.relrowsecurity THEN 'PASS' ELSE 'FAIL' END AS status,
  CASE WHEN c.relrowsecurity THEN 'enabled' ELSE 'DISABLED' END AS rls_state
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN (
    'profiles', 'addresses', 'wishlists', 'cart_items',
    'orders', 'order_items', 'payments'
  )
ORDER BY c.relname;


-- ============================================================
-- SECTION 6: Direct client INSERT blocked on payments
-- Migration 019 drops the payments_insert_own policy so no
-- client can INSERT a payment row directly (default-deny).
-- ============================================================

\echo '\n=== SECTION 6: payments direct-insert policy removed ==='

SELECT
  'payments_insert_own policy' AS check_name,
  'absent'                      AS expected,
  CASE WHEN count(*) = 0 THEN 'absent' ELSE 'PRESENT' END AS actual,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND policyname = 'payments_insert_own';

\echo '\n=== Verification complete — all sections must show PASS ==='
