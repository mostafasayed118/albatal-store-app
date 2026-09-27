-- supabase/tests/test_076_variant_remnant_flag.sql  (DRAFT for human review)
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_076_variant_remnant_flag.sql
-- Expected before migration 076: column is_remnant does not exist
--   (query on information_schema returns 0).
-- Expected after migration:
--   * column exists, BOOLEAN NOT NULL DEFAULT false;
--   * partial index idx_variants_remnant exists;
--   * RLS still enabled on product_variants; variants_select_public intact;
--   * scratch variant round-trip (admin session): insert with default false,
--     flag true, public-shape SELECT sees it, cleanup deletes it.

-- 1. Column exists with correct attributes
SELECT 'is_remnant column' AS check,
  (SELECT count(*) FROM information_schema.columns
    WHERE table_schema='public' AND table_name='product_variants'
      AND column_name='is_remnant') AS cnt;
-- expect 1
SELECT 'is_remnant not null' AS check,
  (SELECT is_nullable FROM information_schema.columns
    WHERE table_schema='public' AND table_name='product_variants'
      AND column_name='is_remnant') AS nullable;
-- expect NO
SELECT 'is_remnant default false' AS check,
  (SELECT column_default FROM information_schema.columns
    WHERE table_schema='public' AND table_name='product_variants'
      AND column_name='is_remnant') AS default_value;
-- expect false

-- 2. Partial index exists
SELECT 'idx_variants_remnant' AS check,
  (SELECT count(*) FROM pg_indexes
    WHERE schemaname='public' AND indexname='idx_variants_remnant') AS cnt;
-- expect 1

-- 3. RLS posture unchanged (flag inherits the table policy)
SELECT 'variants rls' AS check,
  (SELECT relrowsecurity FROM pg_class WHERE relname='product_variants')
  AS enabled;
-- expect true
SELECT 'variants_select_public intact' AS check,
  (SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='product_variants'
      AND policyname='variants_select_public') AS cnt;
-- expect 1

-- 4. Scratch round-trip (run in an admin/service-role session on staging):
--    a) pick any active product with a variant, note one variant id:
--      SELECT id, size, color, stock, is_remnant FROM product_variants
--        WHERE is_active LIMIT 1;
--      -- expect: is_remnant = false (migration default).
--    b) flag it, read it back through the public join shape the client
--       will use (products + variants), then unflag:
--      UPDATE product_variants SET is_remnant = true WHERE id = '<id>';
--      SELECT v.id FROM products p
--        JOIN product_variants v ON v.product_id = p.id
--        WHERE p.is_active AND v.is_remnant AND v.is_active AND v.stock > 0
--        LIMIT 5;
--      -- expect: '<id>' present iff its stock > 0.
--      UPDATE product_variants SET is_remnant = false WHERE id = '<id>';
--      -- expect: staging left exactly as found (no leftover flags).
