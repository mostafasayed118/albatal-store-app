-- ============================================================
-- Migration 052: Demo showcase seed (catalog only)
-- Idempotent: ON CONFLICT DO NOTHING everywhere. Fixed UUIDs
-- with cccc prefix so reruns never duplicate. Prices in minor
-- units (cents). Mirrors 016 pattern. User-linked demo data
-- lives in scripts/seed_demo_staging.mjs (Task 2), not here.
-- ============================================================

-- ─── Products (3 showcase, reuse existing 016 categories) ────
INSERT INTO products (id, category_id, name, slug, base_price, old_price, description, composition, care, origin, rating, review_count, is_active)
VALUES
  ('cccc0001-0001-0001-0001-000000000001',
   'aaaaaaaa-0001-0001-0001-000000000001',
   'Midnight Emerald Silk', 'demo-silk-01', 159000, 189000,
   'Showcase mulberry silk in deep emerald for evening tailoring and statement linings.',
   '100% Mulberry Silk',
   'Dry clean only. Cool iron on reverse.',
   'Suzhou, China', 4.9, 41, true),
  ('cccc0002-0001-0001-0001-000000000002',
   'aaaaaaaa-0001-0001-0001-000000000002',
   'Nile Gold Cotton', 'demo-cotton-01', 74000, NULL,
   'Long-staple Giza cotton with a warm golden undertone for shirting and dresses.',
   '100% Egyptian Giza Cotton',
   'Machine wash cold, gentle cycle. Tumble dry low.',
   'Nile Delta, Egypt', 4.7, 58, true),
  ('cccc0003-0001-0001-0001-000000000003',
   'aaaaaaaa-0001-0001-0001-000000000003',
   'Burgundy Silk Velvet', 'demo-velvet-01', 199000, 229000,
   'Plush silk-blend velvet with a deep burgundy pile for gowns and blazers.',
   '70% Silk, 30% Cotton',
   'Dry clean only. Steam to remove creases.',
   'Bursa, Turkey', 4.8, 23, true)
ON CONFLICT (id) DO NOTHING;

-- ─── Variants (3 per product: 1m/2m/5m, showcase colors) ─────
INSERT INTO product_variants (product_id, size, color, stock)
SELECT p.id, v.size, v.color, v.stock
FROM (VALUES
  ('cccc0001-0001-0001-0001-000000000001'::UUID, '1m', 'Emerald', 10),
  ('cccc0001-0001-0001-0001-000000000001'::UUID, '2m', 'Emerald', 6),
  ('cccc0001-0001-0001-0001-000000000001'::UUID, '5m', 'Emerald', 2),
  ('cccc0002-0001-0001-0001-000000000002'::UUID, '1m', 'Gold', 14),
  ('cccc0002-0001-0001-0001-000000000002'::UUID, '2m', 'Gold', 9),
  ('cccc0002-0001-0001-0001-000000000002'::UUID, '5m', 'Gold', 4),
  ('cccc0003-0001-0001-0001-000000000003'::UUID, '1m', 'Burgundy', 7),
  ('cccc0003-0001-0001-0001-000000000003'::UUID, '2m', 'Burgundy', 5),
  ('cccc0003-0001-0001-0001-000000000003'::UUID, '5m', 'Burgundy', 2)
) AS v(product_id, size, color, stock)
JOIN products p ON p.id = v.product_id
ON CONFLICT (product_id, size, color) DO NOTHING;

-- ─── Product images (storage_path rows only; binaries uploaded separately as admin) ──
INSERT INTO product_images (product_id, storage_path, sort_order, is_primary)
SELECT p.id, v.storage_path, v.sort_order, v.is_primary
FROM (VALUES
  ('cccc0001-0001-0001-0001-000000000001'::UUID, 'product-images/cccc0001-0001-0001-0001-000000000001/hero.jpg', 0, true),
  ('cccc0002-0001-0001-0001-000000000002'::UUID, 'product-images/cccc0002-0001-0001-0001-000000000002/hero.jpg', 0, true),
  ('cccc0003-0001-0001-0001-000000000003'::UUID, 'product-images/cccc0003-0001-0001-0001-000000000003/hero.jpg', 0, true)
) AS v(product_id, storage_path, sort_order, is_primary)
JOIN products p ON p.id = v.product_id
WHERE NOT EXISTS (SELECT 1 FROM product_images WHERE product_id = 'cccc0001-0001-0001-0001-000000000001' AND storage_path = 'product-images/cccc0001-0001-0001-0001-000000000001/hero.jpg')
  AND NOT EXISTS (SELECT 1 FROM product_images WHERE product_id = 'cccc0002-0001-0001-0001-000000000002' AND storage_path = 'product-images/cccc0002-0001-0001-0001-000000000002/hero.jpg')
  AND NOT EXISTS (SELECT 1 FROM product_images WHERE product_id = 'cccc0003-0001-0001-0001-000000000003' AND storage_path = 'product-images/cccc0003-0001-0001-0001-000000000003/hero.jpg')
ON CONFLICT DO NOTHING;

-- ─── Flash sales (active window: yesterday → +7 days, RLS-visible) ──
INSERT INTO flash_sales (product_id, discount_pct, starts_at, ends_at, is_active)
SELECT 'cccc0001-0001-0001-0001-000000000001'::UUID, 15, now() - interval '1 day', now() + interval '7 days', true
WHERE EXISTS (SELECT 1 FROM products WHERE id = 'cccc0001-0001-0001-0001-000000000001')
  AND NOT EXISTS (SELECT 1 FROM flash_sales WHERE product_id = 'cccc0001-0001-0001-0001-000000000001' AND is_active)
ON CONFLICT DO NOTHING;

INSERT INTO flash_sales (product_id, discount_pct, starts_at, ends_at, is_active)
SELECT 'cccc0003-0001-0001-0001-000000000003'::UUID, 10, now() - interval '1 day', now() + interval '7 days', true
WHERE EXISTS (SELECT 1 FROM products WHERE id = 'cccc0003-0001-0001-0001-000000000003')
  AND NOT EXISTS (SELECT 1 FROM flash_sales WHERE product_id = 'cccc0003-0001-0001-0001-000000000003' AND is_active)
ON CONFLICT DO NOTHING;
