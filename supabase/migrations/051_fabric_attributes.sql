-- 051_fabric_attributes.sql (feature-batch §10 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Fabric-specific commerce data:
--   * roll width (cm) and weight (GSM) surfaced on the product details,
--   * sell-by-length: when enabled, shoppers pick a custom cut length
--     (0.5 m steps, >= min_cut_meters) and the metered line is validated
--     server-side inside create_checkout_order (delta below).

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS width_cm integer
    CHECK (width_cm IS NULL OR width_cm BETWEEN 50 AND 400);
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS gsm integer
    CHECK (gsm IS NULL OR gsm BETWEEN 50 AND 1500);
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS sell_by_length boolean NOT NULL DEFAULT false;
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS min_cut_meters numeric(4, 1)
    CHECK (min_cut_meters IS NULL OR min_cut_meters >= 0.5);

-- ─── admin_upsert_product: new optional parameters ───────────────────
-- NOTE FOR REVIEWER: extend the CURRENT admin_upsert_product definition
-- (033 + 044 revisions) with, in this order:
--     p_care text DEFAULT NULL,
--     p_origin text DEFAULT NULL,
--     p_width_cm integer DEFAULT NULL,
--     p_gsm integer DEFAULT NULL,
--     p_sell_by_length boolean DEFAULT NULL,
--     p_min_cut_meters numeric DEFAULT NULL,
-- and include them in the UPDATE/INSERT column lists. The client sends
-- these named parameters ONLY when set, so pre-051 deployments keep
-- working (unknown-parameter errors surface only for admins who fill
-- the new fields before the migration is applied).

-- ─── create_checkout_order: metered-line validation delta ────────────
-- NOTE FOR REVIEWER: for lines whose product has sell_by_length = true,
-- validate the requested size against the fabric contract instead of the
-- fixed variant table:
--     1. parse `size` as '<meters>m' (e.g. '3.5m'),
--     2. reject when meters < products.min_cut_meters,
--     3. snap to the 0.5 m grid server-side (authoritative rounding),
--     4. price the line as base_price (per meter) x snapped meters,
--     5. decrement roll stock tracked in whole meters on the baseline
--        '1m' variant (stock column already holds integer units).
-- Keeping this in the RPC preserves the server-first money math
-- contract pinned by the checkout tests.
