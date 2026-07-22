-- 018_low_stock_index_and_perf.sql
-- Adds a partial index for the admin low-stock query used by
-- `get_low_stock_products` (authorized in migration 017).
--
-- The existing idx_variants_stock covers `WHERE stock > 0` but the
-- low-stock query filters `WHERE is_active = true AND stock <= threshold`.
-- This new index covers that access pattern directly.

CREATE INDEX IF NOT EXISTS idx_variants_low_stock
  ON product_variants (stock)
  WHERE is_active = true AND stock <= 10;
