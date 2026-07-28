-- ============================================================
-- Al Batal Elite — Privilege Matrix Audit
--
-- RUN THIS AGAINST STAGING BEFORE AND AFTER HARDENING.
-- Save output as evidence: privilege_matrix_[timestamp].txt
--
-- SAFETY: READ-ONLY. No writes, no deletes, no grants.
-- ============================================================

\echo ''
\echo '============================================================'
\echo '  AL BATAL ELITE — PRIVILEGE MATRIX'
\echo '  Run: BEFORE hardening (023) and AFTER to compare'
\echo '============================================================'
\echo ''

-- ─── 1. EXECUTE privilege matrix for ALL RPCs ──────────────
\echo '--- SECTION 1: RPC EXECUTE privilege matrix ---'

SELECT
  f.proname AS rpc,
  f.pg_get_function_identity_arguments(f.oid) AS args,
  has_function_privilege('PUBLIC',         f.oid, 'EXECUTE') AS public_exec,
  has_function_privilege('anon',           f.oid, 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated',  f.oid, 'EXECUTE') AS auth_exec,
  has_function_privilege('service_role',   f.oid, 'EXECUTE') AS svc_exec,
  CASE
    WHEN f.proname = 'process_paymob_callback'
      AND has_function_privilege('service_role', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', f.oid, 'EXECUTE')
      THEN 'OK'
    WHEN f.proname IN ('create_checkout_order','confirm_cod_payment',
                        'update_order_status','get_order_details',
                        'get_low_stock_products','set_payment_provider_order_id')
      AND has_function_privilege('authenticated', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', f.oid, 'EXECUTE')
      THEN 'OK'
    WHEN f.proname IN ('expire_pending_order','decrement_stock','increment_stock')
      AND has_function_privilege('service_role', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('anon', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', f.oid, 'EXECUTE')
      AND NOT has_function_privilege('PUBLIC', f.oid, 'EXECUTE')
      THEN 'OK'
    WHEN f.proname = 'calculate_shipping_fee'
      AND NOT has_function_privilege('PUBLIC', f.oid, 'EXECUTE')
      THEN 'OK'
    ELSE 'NEEDS HARDENING'
  END AS expected_state
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


-- ─── 2. RLS INSERT policies on sensitive tables ────────────
\echo ''
\echo '--- SECTION 2: INSERT policies on sensitive tables ---'

SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE
    WHEN tablename IN ('notifications', 'analytics_events', 'error_logs')
      AND cmd = 'INSERT'
      AND qual = 'true'
      THEN 'EXPOSED — any role can insert'
    WHEN tablename = 'payments'
      AND cmd = 'INSERT'
      THEN 'BLOCKED — no INSERT policy (default-deny)'
    ELSE 'OK'
  END AS risk_assessment,
  COALESCE(qual, '(none)') AS using_clause,
  COALESCE(with_check, '(none)') AS with_check_clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'notifications', 'analytics_events', 'error_logs',
    'payments', 'orders', 'order_items'
  )
  AND cmd = 'INSERT'
ORDER BY tablename, policyname;


-- ─── 3. RLS SELECT policies (read access) ──────────────────
\echo ''
\echo '--- SECTION 3: SELECT policies on user-scoped tables ---'

SELECT
  tablename,
  policyname,
  cmd,
  COALESCE(qual, '(true)') AS using_clause
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'orders', 'order_items', 'payments',
    'notifications', 'analytics_events', 'error_logs',
    'profiles', 'addresses', 'cart_items'
  )
  AND cmd = 'SELECT'
ORDER BY tablename, policyname;


-- ─── 4. SECURITY DEFINER functions (bypass RLS) ────────────
\echo ''
\echo '--- SECTION 4: SECURITY DEFINER functions ---'

SELECT
  proname,
  prokind,
  pg_get_function_identity_arguments(oid) AS args,
  prosecdef AS is_security_definer,
  COALESCE(proconfig::text, '(none)') AS config
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND prosecdef = true
ORDER BY proname;


-- ─── 5. Direct INSERT posture on payments ───────────────────
\echo ''
\echo '--- SECTION 5: payments INSERT posture ---'

SELECT
  'payments_rls_enabled' AS check_name,
  CASE WHEN relrowsecurity THEN 'PASS' ELSE 'FAIL' END AS status,
  CASE WHEN relrowsecurity THEN 'RLS enabled' ELSE 'RLS DISABLED' END AS detail
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'payments'

UNION ALL

SELECT
  'payments_insert_policy_count',
  CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  count(*)::text || ' INSERT policies'
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'payments' AND cmd = 'INSERT';


-- ─── 6. Notifications/analytics/error_logs INSERT posture ───
\echo ''
\echo '--- SECTION 6: INSERT posture on logging tables ---'

SELECT
  tablename,
  CASE
    WHEN count(*) = 0 THEN 'PASS — no INSERT policy (service_role only via SECURITY DEFINER)'
    ELSE 'FAIL — ' || count(*)::text || ' INSERT policy(s) allow client inserts'
  END AS status,
  COALESCE(string_agg(policyname || ': ' || COALESCE(with_check, 'true'), ', '), '') AS detail
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('notifications', 'analytics_events', 'error_logs')
  AND cmd = 'INSERT'
GROUP BY tablename;


\echo ''
\echo '============================================================'
\echo '  MATRIX COMPLETE — save this output as evidence'
\echo '============================================================'
