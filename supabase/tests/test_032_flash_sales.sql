-- supabase/tests/test_032_flash_sales.sql
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_032_flash_sales.sql
-- Expected before migration: flash_sales 0, indexes 0, RLS 0, policy 0
-- Expected after migration: flash_sales 1, flash_sales_active_window 1, RLS true, policy 1, product_images_product_sort 1

-- 1. flash_sales table exists
SELECT 'flash_sales table exists' AS check,
  (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='flash_sales') AS cnt;
-- expect 1 after migration

-- 2. flash_sales index flash_sales_active_window exists
SELECT 'flash_sales index exists' AS check,
  (SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename='flash_sales' AND indexname='flash_sales_active_window') AS cnt;
-- expect 1

-- 3. flash_sales RLS enabled
SELECT 'flash_sales RLS enabled' AS check,
  (SELECT relrowsecurity FROM pg_class WHERE relname='flash_sales' AND relkind='r') AS enabled;
-- expect true

-- 4. flash_sales policy flash_sales_select_active exists
SELECT 'flash_sales policy exists' AS check,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='flash_sales' AND policyname='flash_sales_select_active') AS cnt;
-- expect 1

-- 5. product_images index product_images_product_sort exists
SELECT 'product_images index exists' AS check,
  (SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename='product_images' AND indexname='product_images_product_sort') AS cnt;
-- expect 1

-- 6. product_images RLS enabled
SELECT 'product_images RLS enabled' AS check,
  (SELECT relrowsecurity FROM pg_class WHERE relname='product_images' AND relkind='r') AS enabled;
-- expect true

-- 7. product_images public read policy exists
SELECT 'product_images public read policy exists' AS check,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='product_images' AND policyname='product_images_select_public') AS cnt;
-- expect 1

-- 8. storage product-images public read policy exists
SELECT 'storage product-images public read exists' AS check,
  (SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='product-images public read') AS cnt;
-- expect 1

-- 9. storage product-images admin insert policy exists
SELECT 'storage product-images admin insert exists' AS check,
  (SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='product-images admin insert') AS cnt;
-- expect 1

-- 10. storage product-images admin delete policy exists
SELECT 'storage product-images admin delete exists' AS check,
  (SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='product-images admin delete') AS cnt;
-- expect 1
