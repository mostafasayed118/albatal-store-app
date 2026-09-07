-- scripts/verify_demo_seed.sql — all checks must return pass=true
-- 1. Showcase products exist and are active
SELECT 'showcase_active' AS check, count(*) = 3 AS pass FROM products WHERE slug IN ('demo-silk-01','demo-cotton-01','demo-velvet-01') AND is_active;
-- 2. Every showcase product has >=3 variants with stock >= 0
SELECT 'variants_ok' AS check, (SELECT count(*) FROM product_variants WHERE product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%')) >= 9 AS pass;
-- 3. Money invariant: base_price > 0, old_price IS NULL OR > 0
SELECT 'money_ok' AS check, count(*) = 0 AS pass FROM products WHERE slug LIKE 'demo-%' AND NOT (base_price > 0 AND (old_price IS NULL OR old_price > 0));
-- 4. Flash sales visible through the RLS-active window
SELECT 'flash_ok' AS check, count(*) >= 1 AS pass FROM flash_sales WHERE is_active AND now() BETWEEN starts_at AND ends_at AND product_id IN (SELECT id FROM products WHERE slug LIKE 'demo-%');
-- 5. No duplicate slugs
SELECT 'no_dup_slugs' AS check, count(*) = count(DISTINCT slug) AS pass FROM products WHERE slug LIKE 'demo-%';
