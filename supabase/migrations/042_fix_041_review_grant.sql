-- ============================================================
-- Migration 042: fix review_instapay_proof EXECUTE privilege
--
-- Bug: migration 041 created review_instapay_proof with
--   REVOKE ALL ... FROM PUBLIC, anon, authenticated
-- and never granted EXECUTE back to any role. The deployed ACL
-- ended up as {postgres, service_role} only, so the
-- instapay-review Edge Function — which calls the RPC under the
-- admin caller's JWT (role 'authenticated') — always failed with
-- SQLSTATE 42501 (permission denied for function), surfaced to
-- clients as { message: "rpc_error" }. Found by the staging E2E
-- (scripts/_pkgL/_e2e_instapay.mjs).
--
-- Fix: mirror the sibling RPC in 041
-- (set_pending_order_payment_method): REVOKE from PUBLIC/anon,
-- GRANT EXECUTE to authenticated. Admin-only safety is NOT
-- weakened: review_instapay_proof is SECURITY DEFINER and
-- re-verifies profiles.is_admin from the JWT inside its body,
-- returning admin_required otherwise. The grant only permits
-- entering the function. service_role keeps EXECUTE (dashboard/
-- service paths unchanged).
--
-- Conventions: forward-only, idempotent, locked search_path.
-- ============================================================

BEGIN;

REVOKE ALL ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  TO authenticated;

COMMIT;
