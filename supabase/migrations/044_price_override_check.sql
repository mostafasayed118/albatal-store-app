-- ============================================================
-- Migration 044: price_override numeric hardening
--
-- Closes the last unguarded numeric in the catalog write surface.
--
-- Already enforced at the table layer since migration 001 (on EVERY
-- write path, including direct PostgREST UPDATEs and the admin RPCs):
--   * product_variants.stock       CHECK (stock >= 0)
--   * products.base_price          CHECK (base_price > 0)
--   * flash_sales.discount_pct     CHECK (BETWEEN 1 AND 90)
-- Migration 033's admin_upsert_product / admin_upsert_variant added no
-- numeric validation of their own — but they write through these tables,
-- so the constraints fire regardless of the client.
--
-- The gap: product_variants.price_override (added in 001) had no CHECK
-- at all — any admin_upsert_variant call could persist a negative (or
-- zero) override price, which then wins over base_price at display time.
--
-- Convention mirrors products.base_price / old_price: a price must be
-- strictly positive when present; NULL keeps meaning "no override".
--
-- Idempotent: DROP IF EXISTS before ADD.
-- ============================================================

ALTER TABLE product_variants
  DROP CONSTRAINT IF EXISTS product_variants_price_override_check;

ALTER TABLE product_variants
  ADD CONSTRAINT product_variants_price_override_check
  CHECK (price_override IS NULL OR price_override > 0);
