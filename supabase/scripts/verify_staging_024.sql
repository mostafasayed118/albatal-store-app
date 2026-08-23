-- ============================================================
-- Al Batal Elite — Staging Verification: Migration 024
--
-- Run AFTER applying migration 024 via:
--   supabase db push
--
-- Or paste into Supabase SQL Editor on the staging project.
--
-- Every section prints PASS/FAIL. ALL must show PASS.
-- Save full SQL Editor output as evidence.
--
-- SAFETY: READ-ONLY. No writes, no deletes, no grants.
-- ============================================================

\echo ''
\echo '============================================================'
\echo '  AL BATAL ELITE — MIGRATION 024 VERIFICATION'
\echo '============================================================'

-- ─── SECTION 1: Migration applied ──────────────────────────
\echo ''
\echo '--- SECTION 1: Migration 024 applied ---'

SELECT
  'migration_024_applied' AS check_name,
  CASE WHEN EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version LIKE '%024%'
  ) THEN 'PASS' ELSE 'FAIL' END AS status;


-- ─── SECTION 2: calculate_shipping_fee hardened ─────────────
\echo ''
\echo '--- SECTION 2: calculate_shipping_fee ---'

SELECT
  proname,
  CASE
    WHEN NOT has_function_privilege('PUBLIC', oid, 'EXECUTE')
      AND has_function_privilege('authenticated', oid, 'EXECUTE')
    THEN 'PASS'
    ELSE 'FAIL'
  END AS exec_grant_status,
  CASE
    WHEN proconfig::text LIKE '%search_path%'
    THEN 'PASS — has search_path'
    ELSE 'WARN — no explicit search_path'
  END AS search_path_status
FROM pg_proc
WHERE proname = 'calculate_shipping_fee'
  AND pronamespace = 'public'::regnamespace;


-- ─── SECTION 3: process_paymob_callback: service_role only ──
\echo ''
\echo '--- SECTION 3: process_paymob_callback ---'

SELECT
  'process_paymob_callback' AS rpc,
  CASE
    WHEN has_function_privilege('service_role', oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', oid, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', oid, 'EXECUTE')
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM pg_proc
WHERE proname = 'process_paymob_callback'
  AND pronamespace = 'public'::regnamespace;


-- ─── SECTION 4: confirm_cod_payment: authenticated only ─────
\echo ''
\echo '--- SECTION 4: confirm_cod_payment ---'

SELECT
  'confirm_cod_payment' AS rpc,
  CASE
    WHEN has_function_privilege('authenticated', oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', oid, 'EXECUTE')
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM pg_proc
WHERE proname = 'confirm_cod_payment'
  AND pronamespace = 'public'::regnamespace;


-- ─── SECTION 5: create_checkout_order: authenticated only ───
\echo ''
\echo '--- SECTION 5: create_checkout_order ---'

SELECT
  'create_checkout_order' AS rpc,
  CASE
    WHEN has_function_privilege('authenticated', oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', oid, 'EXECUTE')
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM pg_proc
WHERE proname = 'create_checkout_order'
  AND pronamespace = 'public'::regnamespace;


-- ─── SECTION 6: update_order_status: authenticated only ─────
\echo ''
\echo '--- SECTION 6: update_order_status ---'

SELECT
  'update_order_status' AS rpc,
  CASE
    WHEN has_function_privilege('authenticated', oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', oid, 'EXECUTE')
    THEN 'PASS'
    ELSE 'FAIL'
  END AS status
FROM pg_proc
WHERE proname = 'update_order_status'
  AND pronamespace = 'public'::regnamespace;


-- ─── SECTION 7: notifications — no INSERT policy ────────────
\echo ''
\echo '--- SECTION 7: notifications INSERT posture ---'

SELECT
  'notifications' AS table_name,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  count(*)::text || ' INSERT policies' AS detail
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND cmd = 'INSERT';


-- ─── SECTION 8: analytics_events — narrow INSERT policy ─────
\echo ''
\echo '--- SECTION 8: analytics_events INSERT posture ---'

SELECT
  'analytics_events' AS table_name,
  CASE WHEN count(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
  count(*)::text || ' INSERT policies' AS detail,
  string_agg(policyname, ', ') AS policy_names
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'analytics_events'
  AND cmd = 'INSERT';


-- ─── SECTION 9: error_logs — narrow INSERT policy ───────────
\echo ''
\echo '--- SECTION 9: error_logs INSERT posture ---'

SELECT
  'error_logs' AS table_name,
  CASE WHEN count(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS status,
  count(*)::text || ' INSERT policies' AS detail,
  string_agg(policyname, ', ') AS policy_names
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'error_logs'
  AND cmd = 'INSERT';


-- ─── SECTION 10: payments — no INSERT policy (defense) ──────
\echo ''
\echo '--- SECTION 10: payments INSERT posture ---'

SELECT
  'payments' AS table_name,
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  CASE WHEN relrowsecurity THEN 'RLS enabled' ELSE 'RLS DISABLED' END AS rls_state
FROM pg_policies p
JOIN pg_class c ON c.relname = p.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname = 'public'
  AND p.tablename = 'payments'
  AND p.cmd = 'INSERT'
GROUP BY c.relrowsecurity;


-- ─── SECTION 11: Full EXECUTE matrix (all 11 RPCs) ─────────
\echo ''
\echo '--- SECTION 11: Full RPC EXECUTE matrix ---'

SELECT
  f.proname AS rpc,
  has_function_privilege('PUBLIC',        f.oid, 'EXECUTE') AS "PUBLIC",
  has_function_privilege('anon',          f.oid, 'EXECUTE') AS anon,
  has_function_privilege('authenticated', f.oid, 'EXECUTE') AS authenticated,
  has_function_privilege('service_role',  f.oid, 'EXECUTE') AS service_role
FROM pg_proc f
WHERE f.proname IN (
  'create_checkout_order', 'confirm_cod_payment', 'update_order_status',
  'process_paymob_callback', 'calculate_shipping_fee',
  'get_order_details', 'get_low_stock_products',
  'set_payment_provider_order_id', 'expire_pending_order',
  'decrement_stock', 'increment_stock'
)
AND f.pronamespace = 'public'::regnamespace
ORDER BY f.proname;


\echo ''
\echo '============================================================'
\echo '  ALL SECTIONS MUST SHOW PASS'
\echo '  Save this output as: staging_evidence_024_[date].txt'
\echo '============================================================'
