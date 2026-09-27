-- supabase/migrations/076_variant_remnant_flag.sql  (DRAFT for human review)
--
-- Batch 3 #3 (remnants): end-of-roll short pieces get an admin-set flag on
-- the variant, so the storefront can badge them ("Remnant — only X left")
-- and offer a remnants filter without heuristic guessing from size/stock.
--
-- Design decisions:
-- * Flag lives on product_variants (a remnant is one short piece = one
--   color+size row), NOT on products. Setting is_remnant=true is an admin
--   action via the service role (established pattern); shoppers never write.
-- * No RLS change: the new column inherits the existing
--   variants_select_public policy (002), which grants SELECT on the whole
--   table. Anonymous shoppers can already read every variant column.
-- * Partial index covers the storefront query (remnants of active products
--   with stock) so the "shop all remnants" list never seq-scans.
-- * DEFAULT false keeps every existing variant a non-remnant: applying this
--   migration changes zero shopper-visible behavior until the client
--   ships the badge/filter AND an admin flags rows.
--
-- Idempotent: safe to re-run (IF NOT EXISTS everywhere).

BEGIN;

ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS is_remnant BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.product_variants.is_remnant IS
  'Admin-set: this variant is an end-of-roll remnant piece. '
  'Storefront badges it and offers a remnants filter.';

CREATE INDEX IF NOT EXISTS idx_variants_remnant
  ON public.product_variants (product_id)
  WHERE is_remnant AND is_active AND stock > 0;

COMMIT;
