-- 049_coupons.sql (feature-batch §8 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Promo codes end-to-end:
--   * `coupons` table (admin-managed, RLS: admin-write, none read by
--     clients directly — validation goes through the SECURITY DEFINER
--     RPC so inactive/expired rows never leak).
--   * `validate_coupon(p_code)` RPC for checkout validation.
--   * `create_checkout_order` update: accepts `p_coupon_code`, applies
--     the discount SERVER-SIDE and stamps `coupons_id` on the order.
--     Money math remains server-owned (design spec §1).

-- ─── Table ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.coupons (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text NOT NULL UNIQUE,
  discount_minor integer NOT NULL CHECK (discount_minor > 0),
  description    text,
  active         boolean NOT NULL DEFAULT true,
  expires_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- No public policies: only the service role (via SECURITY DEFINER
-- functions) and admins reach this table.
CREATE POLICY coupons_admin_read ON public.coupons
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );
CREATE POLICY coupons_admin_write ON public.coupons
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS coupons_id uuid REFERENCES public.coupons(id);
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS coupon_discount_minor integer NOT NULL DEFAULT 0;

-- ─── validate_coupon RPC ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validate_coupon(p_code text)
RETURNS TABLE (code text, discount_minor integer, description text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.code, c.discount_minor, c.description
  FROM public.coupons c
  WHERE upper(trim(c.code)) = upper(trim(p_code))
    AND c.active
    AND (c.expires_at IS NULL OR c.expires_at > now())
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.validate_coupon(text)
  TO anon, authenticated;

-- ─── create_checkout_order: accept p_coupon_code ─────────────────────
-- NOTE FOR REVIEWER: this section must be merged into the CURRENT
-- create_checkout_order definition (migration 013 + later revisions).
-- The essential deltas are:
--   1. new parameter  `p_coupon_code text DEFAULT NULL`,
--   2. before pricing: resolve the coupon via validate_coupon semantics
--      (NULL when absent/invalid — an invalid code must NOT block the
--      order, it simply applies no discount),
--   3. `v_total := GREATEST(v_total - v_coupon_discount, 0)` after the
--      shipping computation and before the order insert,
--   4. store `coupons_id` + `coupon_discount_minor` on the order row.
-- The full rewritten function body is intentionally NOT inlined here so
-- it is diffed against the live definition during owner review instead
-- of clobbering a newer revision.
