-- ============================================================
-- Migration 021: Least-privilege grants for calculate_shipping_fee
--
-- NUMBERING NOTE:
--   Migration 020 on disk is reserved by an out-of-scope COD /
--   late-callback draft (`020_cod_server_confirm_and_late_callback.sql`).
--   This file intentionally uses 021 so 020 is not overwritten and
--   migration history is not rewritten.
--
-- PROBLEM:
--   Migration 009 created `calculate_shipping_fee(TEXT, INTEGER)` as
--   SECURITY DEFINER without least-privilege EXECUTE grants. Default
--   PUBLIC execute allows anon/authenticated clients to invoke the
--   fee calculator directly (resource use / probing shipping config).
--
-- FIX:
--   Revoke EXECUTE from PUBLIC, anon, and authenticated. The function
--   remains callable from SECURITY DEFINER owners (e.g.
--   `create_checkout_order` in migration 013), which run as the
--   function owner and do not rely on client-role EXECUTE grants.
--
-- CALLERS (verified at authoring time — no Flutter client RPC):
--   - create_checkout_order (013) internal call only
--   - checkout Edge Function documents the same server-side path
--
-- SAFETY:
--   - Does not change fee calculation logic
--   - Exact signature: calculate_shipping_fee(TEXT, INTEGER)
--   - Forward-only; idempotent REVOKE
--
-- ROLLBACK (staging only):
--   GRANT EXECUTE ON FUNCTION calculate_shipping_fee(TEXT, INTEGER)
--     TO authenticated;  -- only if a product-approved quote path exists
-- ============================================================

DO $$
BEGIN
  IF to_regprocedure('public.calculate_shipping_fee(text, integer)') IS NULL THEN
    RAISE EXCEPTION
      '021_shipping_fee_least_privilege: expected public.calculate_shipping_fee(text, integer) not found';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.calculate_shipping_fee(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.calculate_shipping_fee(TEXT, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.calculate_shipping_fee(TEXT, INTEGER) FROM authenticated;

-- No GRANT to anon/authenticated. Owner (migration runner role) retains
-- EXECUTE for SECURITY DEFINER callers such as create_checkout_order.
