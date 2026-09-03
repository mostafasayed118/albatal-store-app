-- ═══════════════════════════════════════════════════════════
-- Migration 038: fix 037 grant matrix for client-called RPC
-- ═══════════════════════════════════════════════════════════
-- BUG (found live 2026-09-03):
--   037 copied the service/cron-only grant pattern (REVOKE from
--   authenticated) from 033/035. But set_pending_order_payment_method
--   is called BY the Flutter client as the authenticated role, so
--   PostgREST rejected every call with 403 and COD checkout appeared
--   dead ("Failed to set payment method").
--
-- Correct convention for client-called RPCs (same as
-- confirm_cod_payment in 018/022 and the admin RPCs in 033):
--   REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated.
-- The function body itself enforces owner + pending + allowlist,
-- so granting EXECUTE is safe.
-- Idempotent: safe to re-run.
-- ═══════════════════════════════════════════════════════════

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;
