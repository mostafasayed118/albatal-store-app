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
-- ============================================================

\echo '\n=== SECTION 1: Applied migrations ==='

SELECT
  'total_migrations_applied' AS check_name,
  'latest-073-or-newer' AS expected,
  CASE
    WHEN max(version::integer) >= 73 THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM supabase_migrations.schema_migrations
WHERE version ~ '^[0-9]{3}$';

SELECT
  'migration_073_payment_integrity' AS check_name,
  'present' AS expected,
  CASE WHEN EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version = '073'
  ) THEN 'PASS' ELSE 'FAIL' END AS status;

SELECT
  'migration_072_checkout_bounds' AS check_name,
  'present' AS expected,
  CASE WHEN EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version = '072'
  ) THEN 'PASS' ELSE 'FAIL' END AS status;


-- ============================================================
-- SECTION 2: RPC existence + signature
-- ============================================================

\echo '\n=== SECTION 2: RPC existence + signature ==='

WITH required(name, signature) AS (
  VALUES
    ('confirm_cod_payment', 'uuid'),
    ('create_checkout_order', 'text,jsonb,jsonb,text,text'),
    ('update_order_status', 'uuid,text,text'),
    ('process_paymob_callback', 'text,text,integer,text,boolean'),
    ('get_or_claim_paymob_payment', 'uuid'),
    ('set_payment_provider_order_id_claim', 'uuid,text,uuid'),
    ('admin_upsert_variant', 'uuid,text,text,integer,numeric'),
    ('admin_set_product_images', 'uuid,text[]'),
    ('submit_product_review', 'uuid,integer,text,text'),
    ('review_instapay_proof', 'uuid,boolean,text')
)
SELECT
  name || '(' || signature || ')' AS rpc,
  CASE
    WHEN to_regprocedure('public.' || name || '(' || signature || ')') IS NOT NULL
      THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM required;

SELECT
  'old_checkout_overload_absent' AS rpc,
  CASE
    WHEN to_regprocedure('public.create_checkout_order(text,jsonb,jsonb,text)') IS NULL
      THEN 'PASS'
    ELSE 'FAIL'
  END AS status;


-- ============================================================
-- SECTION 3: RPC EXECUTE grants (least privilege)
-- ============================================================

\echo '\n=== SECTION 3: RPC EXECUTE grants ==='

WITH required(name, signature, allowed_role) AS (
  VALUES
    ('confirm_cod_payment', 'uuid', 'authenticated'),
    ('create_checkout_order', 'text,jsonb,jsonb,text,text', 'authenticated'),
    ('update_order_status', 'uuid,text,text', 'authenticated'),
    ('process_paymob_callback', 'text,text,integer,text,boolean', 'service_role'),
    ('get_or_claim_paymob_payment', 'uuid', 'authenticated'),
    ('set_payment_provider_order_id_claim', 'uuid,text,uuid', 'service_role'),
    ('admin_upsert_variant', 'uuid,text,text,integer,numeric', 'authenticated'),
    ('admin_set_product_images', 'uuid,text[]', 'authenticated'),
    ('submit_product_review', 'uuid,integer,text,text', 'authenticated'),
    ('review_instapay_proof', 'uuid,boolean,text', 'authenticated')
)
SELECT
  name || '(' || signature || ')' AS rpc,
  allowed_role AS expected_grantee,
  CASE
    WHEN has_function_privilege(allowed_role, 'public.' || name || '(' || signature || ')', 'EXECUTE')
      AND NOT has_function_privilege('anon', 'public.' || name || '(' || signature || ')', 'EXECUTE')
      AND (
        allowed_role = 'service_role'
        OR name = 'get_or_claim_paymob_payment'
        OR NOT has_function_privilege('service_role', 'public.' || name || '(' || signature || ')', 'EXECUTE')
      )
      THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM required;


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
    'orders', 'order_items', 'payments', 'product_reviews', 'instapay_proofs'
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

SELECT
  'product_reviews_direct_insert' AS check_name,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'product_reviews'
  AND cmd = 'INSERT';

WITH expected(bucket_id) AS (
  VALUES ('instapay-proofs'::TEXT), ('review-images'::TEXT)
), actual AS (
  SELECT b.id AS bucket_id, b.public, b.file_size_limit, b.allowed_mime_types
  FROM expected e
  LEFT JOIN storage.buckets b ON b.id = e.bucket_id
)
SELECT
  bucket_id,
  CASE
    WHEN public = false
      AND file_size_limit <= 5 * 1024 * 1024
      AND allowed_mime_types @> ARRAY['image/jpeg', 'image/png', 'image/webp']::TEXT[]
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM actual
ORDER BY bucket_id;

\echo '\n=== Verification complete — all sections must show PASS ==='
