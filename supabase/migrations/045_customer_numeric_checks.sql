-- ============================================================
-- Migration 045: customer-side numeric hardening
--
-- Follows the constraint audit behind migration 044 across the
-- remaining customer-facing tables. Already constrained (no action):
--   * cart_items.quantity             CHECK (quantity > 0)        [001]
--   * orders.subtotal/shipping/total  CHECK (>= 0)                [001]
--   * order_items.unit_price/quantity CHECK (> 0)                 [001]
--   * payments.amount                 CHECK (amount > 0)          [006]
--   * flash_sales.discount_pct / ends_at window                   [032]
--   * wishlists, addresses — no numeric columns at all
--
-- The gaps this migration closes:
--   1. shipping_zones.estimated_days_min / _max (009) had no CHECKs —
--      a zero/negative window would render nonsense ETAs, and
--      min > max inverts the range. They are display data only (the
--      fee RPC never reads them), which is why 001 shipped without
--      guards and why this surfaces only now.
--   2. products.review_count (001) had no >= 0 CHECK. Only backend
--      review flows write it today, but the column is client-readable,
--      so the invariant belongs at the table layer like its siblings.
--
-- The two zone constraints compose: min >= 1 and max >= min imply
-- max >= 1, so a valid window is always 1..N or wider.
--
-- Idempotent: DROP IF EXISTS before each ADD. ADD CONSTRAINT fails
-- loudly if staging rows already violate the bounds — that is the
-- desired signal, not something to pre-clean here.
-- ============================================================

ALTER TABLE shipping_zones
  DROP CONSTRAINT IF EXISTS shipping_zones_estimated_days_min_check;
ALTER TABLE shipping_zones
  ADD CONSTRAINT shipping_zones_estimated_days_min_check
  CHECK (estimated_days_min >= 1);

ALTER TABLE shipping_zones
  DROP CONSTRAINT IF EXISTS shipping_zones_estimated_days_max_check;
ALTER TABLE shipping_zones
  ADD CONSTRAINT shipping_zones_estimated_days_max_check
  CHECK (estimated_days_max >= estimated_days_min);

ALTER TABLE products
  DROP CONSTRAINT IF EXISTS products_review_count_check;
ALTER TABLE products
  ADD CONSTRAINT products_review_count_check
  CHECK (review_count IS NULL OR review_count >= 0);
