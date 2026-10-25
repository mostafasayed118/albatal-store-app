-- ============================================================
-- Migration 081: admin SELECT on order_items
-- ============================================================
-- Verified defect: order_items has only "order_items_select_own"
-- (002_rls_policies.sql:139-147), so an admin's embedded
-- order_items(id) in the order queue returns zero rows for orders
-- that belong to other users. The admin UI can read orders (003)
-- but not their line items.
--
-- Additive: the existing owner policy is kept; this only adds a
-- second permissive SELECT policy for admins. No UPDATE/DELETE
-- grant and no write-path change.
--
-- Owner review required before apply (AGENTS.md migration gate).
-- Idempotent: DROP POLICY IF EXISTS then CREATE.
-- ============================================================

BEGIN;

DROP POLICY IF EXISTS "order_items_select_admin" ON public.order_items;
CREATE POLICY "order_items_select_admin"
  ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
       WHERE p.id = auth.uid()
         AND p.is_admin = true
    )
  );

COMMIT;
