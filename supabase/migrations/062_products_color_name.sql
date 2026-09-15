-- ============================================================================
-- 062_products_color_name.sql — AUD-011 remediation
-- ============================================================================
-- Adds the curated display color name to products. Client side (landed in
-- the same round): Product.colorName (nullable), read by
-- ProductCodec.fromRow and round-tripped by encode/decode; the catalog
-- tint map in catalog_filters.dart stays as the fallback for rows without
-- a color_name. No backfill: existing rows keep NULL (variant-derived
-- colors remain the filter source until the owner curates names).
-- ============================================================================

alter table public.products add column if not exists color_name text;

comment on column public.products.color_name is
  'Curated display color name (AUD-011); null falls back to variant-derived colors.';

-- ============================================================================
-- Rollback
-- ============================================================================
-- alter table public.products drop column if exists color_name;
-- ============================================================================
