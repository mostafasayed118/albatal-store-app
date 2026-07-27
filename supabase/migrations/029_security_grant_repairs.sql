-- 029_security_grant_repairs.sql
--
-- Forward-only security grant repairs (Package K).
--
-- Fixes the Package J staging DB-catalog failures captured against frozen
-- candidate 484a3ea (docs/evidence/484a3ea/STAGING_SNAPSHOT.md):
--   1. anon/public INSERT/UPDATE/DELETE grants on user-private tables.
--   2. anon/authenticated EXECUTE grants on privileged stock/order-lifecycle
--      RPCs (decrement_stock, increment_stock, expire_pending_order).
--   3. anon EXECUTE grant on set_payment_provider_order_id.
--
-- This migration does NOT modify table data.
-- This migration does NOT modify RLS policies.
-- This migration does NOT renumber existing migrations.
-- This migration does NOT change payment or Edge Function business logic.
--
-- Function signatures verified against the frozen candidate:
--   decrement_stock(UUID, TEXT, TEXT, INTEGER)              -- migration 015
--   increment_stock(UUID, TEXT, TEXT, INTEGER)              -- migration 015
--   expire_pending_order(UUID)                              -- migrations 015/025
--   set_payment_provider_order_id(UUID, TEXT)               -- migration 015

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Revoke anonymous/public write grants on user-private tables.
--    RLS is already enabled on these (Package J: PASS); this removes the
--    defense-in-depth gap of table-level DML grants for anon/public.
--    SELECT grants are intentionally left untouched.
-- ---------------------------------------------------------------------

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
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
  ]
  LOOP
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON TABLE public.%I FROM anon', t);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON TABLE public.%I FROM public', t);
  END LOOP;
END
$$;

-- ---------------------------------------------------------------------
-- 2. Restrict privileged stock/order-lifecycle RPCs to service_role only.
--    These are invoked only by trusted server-side jobs / Edge Functions.
-- ---------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.decrement_stock(UUID, TEXT, TEXT, INTEGER)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_stock(UUID, TEXT, TEXT, INTEGER)
  TO service_role;

REVOKE ALL ON FUNCTION public.increment_stock(UUID, TEXT, TEXT, INTEGER)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_stock(UUID, TEXT, TEXT, INTEGER)
  TO service_role;

REVOKE ALL ON FUNCTION public.expire_pending_order(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_pending_order(UUID)
  TO service_role;

-- ---------------------------------------------------------------------
-- 3. Remove anonymous access from set_payment_provider_order_id.
--    Keep authenticated + service_role: the Paymob initiation flow calls
--    this RPC on the authenticated user's JWT (it self-verifies ownership),
--    so authenticated EXECUTE is required and preserved.
-- ---------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT)
  TO authenticated, service_role;

COMMIT;
