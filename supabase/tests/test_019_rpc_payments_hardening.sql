-- ============================================================
-- SQL test: RPC and payments authorization hardening (migration 019)
--
-- Verifies:
--   T1  PUBLIC cannot execute create_checkout_order
--   T2  authenticated can execute create_checkout_order
--   T3  PUBLIC cannot execute update_order_status
--   T4  authenticated can execute update_order_status
--   T5  PUBLIC cannot execute confirm_cod_payment
--   T6  authenticated can execute confirm_cod_payment
--   T7  PUBLIC cannot execute process_paymob_callback
--   T8  authenticated cannot execute process_paymob_callback
--   T9  anon cannot execute process_paymob_callback
--   T10 service_role can execute process_paymob_callback
--   T11 payments_insert_own policy no longer exists
--   T12 no INSERT policy remains on payments (RLS default-deny)
--
-- Run: supabase db execute supabase/migrations/test_019_rpc_payments_hardening.sql
-- Safe: wraps everything in a transaction and rolls back.
-- ============================================================

BEGIN;

-- ─── Build the EXECUTE privilege matrix for the four RPCs ──
-- grantee OID 0 == PUBLIC. aclexplode parses pg_proc.proacl;
-- COALESCE with acldefault('f', owner) so a NULL proacl (which
-- means default =X to PUBLIC) is handled correctly.
CREATE TEMP TABLE _rpc_exec AS
SELECT pr.proname, a.grantee AS grantee_oid
FROM pg_proc pr
LEFT JOIN LATERAL aclexplode(COALESCE(pr.proacl, acldefault('f', pr.proowner))) a
  ON a.privilege_type = 'EXECUTE'
WHERE pr.proname IN (
  'create_checkout_order',
  'update_order_status',
  'confirm_cod_payment',
  'process_paymob_callback'
);

-- Map the OIDs we care about to readable role names.
CREATE TEMP TABLE _role AS
SELECT 0::oid AS oid, 'PUBLIC'::text AS rolname
UNION ALL SELECT oid, rolname FROM pg_roles
WHERE rolname IN ('authenticated', 'anon', 'service_role');

-- ─── T1: PUBLIC cannot execute create_checkout_order ────────
SELECT 'T1 PUBLIC blocked from create_checkout_order', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'create_checkout_order' AND r.rolname = 'PUBLIC'
  ) THEN 'PASS'
  ELSE 'FAIL (PUBLIC still has EXECUTE)'
END AS result;

-- ─── T2: authenticated can execute create_checkout_order ───
SELECT 'T2 authenticated can create_checkout_order', CASE
  WHEN EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'create_checkout_order' AND r.rolname = 'authenticated'
  ) THEN 'PASS'
  ELSE 'FAIL (authenticated lacks EXECUTE)'
END AS result;

-- ─── T3: PUBLIC cannot execute update_order_status ─────────
SELECT 'T3 PUBLIC blocked from update_order_status', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'update_order_status' AND r.rolname = 'PUBLIC'
  ) THEN 'PASS'
  ELSE 'FAIL (PUBLIC still has EXECUTE)'
END AS result;

-- ─── T4: authenticated can execute update_order_status ─────
SELECT 'T4 authenticated can update_order_status', CASE
  WHEN EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'update_order_status' AND r.rolname = 'authenticated'
  ) THEN 'PASS'
  ELSE 'FAIL (authenticated lacks EXECUTE)'
END AS result;

-- ─── T5: PUBLIC cannot execute confirm_cod_payment ──────────
SELECT 'T5 PUBLIC blocked from confirm_cod_payment', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'confirm_cod_payment' AND r.rolname = 'PUBLIC'
  ) THEN 'PASS'
  ELSE 'FAIL (PUBLIC still has EXECUTE)'
END AS result;

-- ─── T6: authenticated can execute confirm_cod_payment ──────
SELECT 'T6 authenticated can confirm_cod_payment', CASE
  WHEN EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'confirm_cod_payment' AND r.rolname = 'authenticated'
  ) THEN 'PASS'
  ELSE 'FAIL (authenticated lacks EXECUTE)'
END AS result;

-- ─── T7: PUBLIC cannot execute process_paymob_callback ──────
SELECT 'T7 PUBLIC blocked from process_paymob_callback', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'process_paymob_callback' AND r.rolname = 'PUBLIC'
  ) THEN 'PASS'
  ELSE 'FAIL (PUBLIC still has EXECUTE)'
END AS result;

-- ─── T8: authenticated cannot execute process_paymob_callback ─
SELECT 'T8 authenticated blocked from process_paymob_callback', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'process_paymob_callback' AND r.rolname = 'authenticated'
  ) THEN 'PASS'
  ELSE 'FAIL (authenticated still has EXECUTE)'
END AS result;

-- ─── T9: anon cannot execute process_paymob_callback ────────
SELECT 'T9 anon blocked from process_paymob_callback', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'process_paymob_callback' AND r.rolname = 'anon'
  ) THEN 'PASS'
  ELSE 'FAIL (anon still has EXECUTE)'
END AS result;

-- ─── T10: service_role can execute process_paymob_callback ──
SELECT 'T10 service_role can process_paymob_callback', CASE
  WHEN EXISTS (
    SELECT 1 FROM _rpc_exec e JOIN _role r ON r.oid = e.grantee_oid
    WHERE e.proname = 'process_paymob_callback' AND r.rolname = 'service_role'
  ) THEN 'PASS'
  ELSE 'FAIL (service_role lacks EXECUTE)'
END AS result;

-- ─── T11: payments_insert_own policy dropped ────────────────
SELECT 'T11 payments_insert_own dropped', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'payments'
      AND policyname = 'payments_insert_own'
  ) THEN 'PASS'
  ELSE 'FAIL (policy still exists)'
END AS result;

-- ─── T12: no INSERT policy on payments (RLS default-deny) ──
-- With RLS enabled and no INSERT policy, no client role can
-- insert a row. This is the structural guarantee that a normal
-- user cannot INSERT into payments directly.
SELECT 'T12 no INSERT policy on payments', CASE
  WHEN NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'payments' AND cmd = 'INSERT'
  ) THEN 'PASS (RLS default-deny active)'
  ELSE 'FAIL (an INSERT policy still exists)'
END AS result;

ROLLBACK;
