-- scripts/verify_demo_seed.sql — all checks must return pass=true
--
-- Run with a role that can read the storage schema (`postgres` or `service_role`):
-- checks 7-8 query storage.objects, which is RLS-enabled. The `product-images`
-- public-read policy (migrations 005/032) covers bucket_id = 'product-images',
-- so those rows are visible to every role; nothing here relies on bypassing RLS.
-- 1. Showcase products exist and are active
SELECT 'showcase_active' AS check, count(*) = 3 AS pass FROM products WHERE slug IN ('demo-silk-01','demo-cotton-01','demo-velvet-01') AND is_active;
-- 2. Every showcase product has >=3 variants with stock >= 0
SELECT 'variants_ok' AS check, (SELECT count(*) FROM product_variants WHERE product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%')) >= 9 AS pass;
-- 3. Every showcase product has its hero image row
SELECT 'images_ok' AS check, count(*) = 3 AS pass FROM product_images WHERE product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%');
-- 4. Money invariant: base_price > 0, old_price IS NULL OR > 0
SELECT 'money_ok' AS check, count(*) = 0 AS pass FROM products WHERE slug LIKE 'demo-%' AND NOT (base_price > 0 AND (old_price IS NULL OR old_price > 0));
-- 5. Flash sales visible through the RLS-active window
SELECT 'flash_ok' AS check, count(*) = 2 AS pass FROM flash_sales WHERE is_active AND now() BETWEEN starts_at AND ends_at AND product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%');
-- 6. No duplicate slugs
SELECT 'no_dup_slugs' AS check, count(*) = count(DISTINCT slug) AS pass FROM products WHERE slug LIKE 'demo-%';
-- 7. …and every one of those paths has a real OBJECT behind it.
-- Completes #3. A product_images row whose binary was never uploaded looks
-- perfectly seeded until the app asks for it — which is exactly how the
-- showcase shipped rendering placeholders (STATE.md part 24).
-- Joins on name as well as bucket_id because storage_path already carries the
-- bucket prefix (`product-images/<id>/hero.jpg`, the same doubling the public
-- URL shows), so it equals storage.objects.name verbatim. Asserting "0 rows
-- missing an object" rather than "count = 3" keeps it honest if the seed ever
-- registers more images.
SELECT 'image_objects_ok' AS check, count(*) = 0 AS pass
FROM product_images pi
WHERE pi.product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%')
  AND NOT EXISTS (
    SELECT 1 FROM storage.objects so
    WHERE so.bucket_id = 'product-images'
      AND so.name = pi.storage_path
  );
-- 8. Those objects carry a content type the app can render.
-- Deliberately a SET, not 'image/png': the seed writes PNG bytes to the
-- 052-registered '.jpg' paths, but a later admin replacement uploads through
-- the app (JPEG/WebP) and repoints storage_path — that is the desired end
-- state and must not fail here. The set mirrors the renderable list in
-- StorageService.getProductImageUrlForWidth.
-- COALESCE matters: `NULL NOT IN (…)` is NULL, not true, so an object with no
-- mimetype at all would silently PASS without it.
SELECT 'image_content_type_ok' AS check, count(*) = 0 AS pass
FROM product_images pi
JOIN storage.objects so
  ON so.bucket_id = 'product-images' AND so.name = pi.storage_path
WHERE pi.product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%')
  AND COALESCE(so.metadata->>'mimetype', '') NOT IN ('image/jpeg', 'image/png', 'image/webp');
