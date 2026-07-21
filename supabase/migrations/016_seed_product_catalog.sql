-- ============================================================
-- Migration 016: Seed product catalog
--
-- Seeds the 9 products (with variants) that the Flutter client
-- uses for the storefront. This bridges the gap between the
-- local mock catalog (slug IDs) and the server-side checkout
-- RPC (which requires real UUIDs from the products table).
--
-- Idempotent: ON CONFLICT DO NOTHING on all inserts.
--
-- After applying this migration, register
-- [SupabaseCatalogRepository] in service_locator.dart so the
-- Flutter client fetches products with real UUIDs from the DB.
-- ============================================================

-- ─── Categories ────────────────────────────────────────────
INSERT INTO categories (id, name, slug, sort_order)
VALUES
  ('aaaaaaaa-0001-0001-0001-000000000001', 'Silk',    'silk',    1),
  ('aaaaaaaa-0001-0001-0001-000000000002', 'Cotton',  'cotton',  2),
  ('aaaaaaaa-0001-0001-0001-000000000003', 'Velvet',  'velvet',  3),
  ('aaaaaaaa-0001-0001-0001-000000000004', 'Linen',   'linen',   4),
  ('aaaaaaaa-0001-0001-0001-000000000005', 'Wool',    'wool',    5)
ON CONFLICT (id) DO NOTHING;

-- ─── Products ──────────────────────────────────────────────
-- prices are in minor units (cents) matching Money.egp()
-- e.g. 1290 EGP → 129000 minor units

INSERT INTO products (id, category_id, name, slug, base_price, old_price, description, composition, care, origin, rating, review_count)
VALUES
  -- Silk products
  ('bbbb0001-0001-0001-0001-000000000001',
   'aaaaaaaa-0001-0001-0001-000000000001',
   'Royal Emerald Silk', 'silk-01', 129000, 152000,
   'Hand-loomed mulberry silk with a rich emerald sheen. The tight weave gives it a fluid drape ideal for evening wear, formal suiting, and statement linings.',
   '100% Mulberry Silk',
   'Dry clean only. Cool iron on reverse. Store folded in breathable cotton.',
   'Varanasi, India', 4.8, 124),

  ('bbbb0002-0001-0001-0001-000000000002',
   'aaaaaaaa-0001-0001-0001-000000000001',
   'Golden Charmeuse Silk', 'silk-02', 145000, NULL,
   'Lustrous charmeuse with a liquid gold finish. Double-sided satin weave makes it equally stunning as a lining or as the face fabric.',
   '100% Mulberry Silk',
   'Dry clean recommended. Hand wash cold with pH-neutral detergent.',
   'Suzhou, China', 4.9, 87),

  -- Cotton products
  ('bbbb0003-0001-0001-0001-000000000003',
   'aaaaaaaa-0001-0001-0001-000000000002',
   'Egyptian Cotton', 'cotton-01', 69000, NULL,
   'Long-staple Giza cotton with a warm golden undertone. Exceptionally soft hand feel with natural breathability — perfect for shirting, dresses, and light trousers.',
   '100% Egyptian Giza Cotton',
   'Machine wash cold, gentle cycle. Tumble dry low. Iron while slightly damp.',
   'Nile Delta, Egypt', 4.6, 203),

  ('bbbb0004-0001-0001-0001-000000000004',
   'aaaaaaaa-0001-0001-0001-000000000002',
   'Premium Pima Cotton', 'cotton-02', 82000, 95000,
   'Extra-long staple Pima cotton from Peru. Silky-smooth hand with exceptional durability — ideal for premium basics and luxury casualwear.',
   '100% Peruvian Pima Cotton',
   'Machine wash warm. Tumble dry medium. Avoid bleach.',
   'Cajamarca, Peru', 4.7, 156),

  -- Velvet products
  ('bbbb0005-0001-0001-0001-000000000005',
   'aaaaaaaa-0001-0001-0001-000000000003',
   'Silk Velvet', 'velvet-01', 189000, 210000,
   'Sumptuous silk-blend velvet with a deep, luminous pile. Catches light beautifully for evening gowns, blazers, and upholstery accents.',
   '70% Silk, 30% Cotton',
   'Dry clean only. Steam to remove creases. Store away from direct sunlight.',
   'Bursa, Turkey', 4.9, 67),

  ('bbbb0006-0001-0001-0001-000000000006',
   'aaaaaaaa-0001-0001-0001-000000000003',
   'Cotton Velour', 'velvet-02', 58000, NULL,
   'Soft cotton velour with a plush, even pile. Breathable and comfortable — great for casual wear and loungewear.',
   '100% Combed Cotton',
   'Machine wash cold inside out. Tumble dry low. Avoid ironing the pile.',
   'Istanbul, Turkey', 4.4, 178),

  -- Linen products
  ('bbbb0007-0001-0001-0001-000000000007',
   'aaaaaaaa-0001-0001-0001-000000000004',
   'Belgian Linen', 'linen-01', 95000, NULL,
   'Heritage Belgian flax linen with a crisp hand and natural luster. Gets softer with every wash — perfect for summer suiting and resort wear.',
   '100% Belgian Flax Linen',
   'Machine wash warm. Tumble dry or line dry. Embrace natural wrinkles.',
   'Flanders, Belgium', 4.7, 142),

  ('bbbb0008-0001-0001-0001-000000000008',
   'aaaaaaaa-0001-0001-0001-000000000004',
   'Irish Linen', 'linen-02', 110000, 125000,
   'Classic Irish linen with a medium weight and smooth finish. Known for its exceptional strength and elegant drape.',
   '100% Irish Flax Linen',
   'Machine wash cold. Line dry recommended. Iron while damp.',
   'Belfast, Northern Ireland', 4.8, 98),

  -- Wool products
  ('bbbb0009-0001-0001-0001-000000000009',
   'aaaaaaaa-0001-0001-0001-000000000005',
   'Merino Wool', 'wool-01', 78000, NULL,
   'Ultra-fine Merino wool with a soft, non-itchy feel. Natural temperature regulation and moisture-wicking — ideal for year-round suiting.',
   '100% Australian Merino Wool',
   'Dry clean or hand wash cold. Lay flat to dry. Store with cedar.',
   'Melbourne, Australia', 4.5, 167)
ON CONFLICT (id) DO NOTHING;

-- ─── Product Variants ──────────────────────────────────────
-- Each product has 3 colors × 3 sizes = 9 variants.
-- UUID strings are cast explicitly because PostgreSQL's VALUES
-- clause infers the column as text, which fails the join with
-- the UUID-typed products.id column.

INSERT INTO product_variants (product_id, size, color, stock)
SELECT p.id, v.size, v.color, v.stock
FROM (VALUES
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '1m', 'Emerald', 12),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '2m', 'Emerald', 8),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '5m', 'Emerald', 3),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '1m', 'Gold', 5),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '2m', 'Gold', 10),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '5m', 'Gold', 2),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '1m', 'Ivory', 7),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '2m', 'Ivory', 6),
  ('bbbb0001-0001-0001-0001-000000000001'::UUID, '5m', 'Ivory', 0),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '1m', 'Emerald', 6),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '2m', 'Emerald', 4),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '5m', 'Emerald', 2),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '1m', 'Gold', 8),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '2m', 'Gold', 11),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '5m', 'Gold', 3),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '1m', 'Ivory', 5),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '2m', 'Ivory', 7),
  ('bbbb0002-0001-0001-0001-000000000002'::UUID, '5m', 'Ivory', 1),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '1m', 'Cream', 20),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '2m', 'Cream', 15),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '5m', 'Cream', 8),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '1m', 'White', 18),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '2m', 'White', 12),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '5m', 'White', 6),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '1m', 'Sand', 14),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '2m', 'Sand', 10),
  ('bbbb0003-0001-0001-0001-000000000003'::UUID, '5m', 'Sand', 4),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '1m', 'Navy', 10),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '2m', 'Navy', 8),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '5m', 'Navy', 3),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '1m', 'White', 12),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '2m', 'White', 9),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '5m', 'White', 5),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '1m', 'Blue', 7),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '2m', 'Blue', 6),
  ('bbbb0004-0001-0001-0001-000000000004'::UUID, '5m', 'Blue', 2),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '1m', 'Burgundy', 5),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '2m', 'Burgundy', 3),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '5m', 'Burgundy', 1),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '1m', 'Midnight', 4),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '2m', 'Midnight', 2),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '5m', 'Midnight', 1),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '1m', 'Emerald', 6),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '2m', 'Emerald', 4),
  ('bbbb0005-0001-0001-0001-000000000005'::UUID, '5m', 'Emerald', 2),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '1m', 'Charcoal', 15),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '2m', 'Charcoal', 10),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '5m', 'Charcoal', 5),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '1m', 'Navy', 12),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '2m', 'Navy', 8),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '5m', 'Navy', 3),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '1m', 'Burgundy', 9),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '2m', 'Burgundy', 6),
  ('bbbb0006-0001-0001-0001-000000000006'::UUID, '5m', 'Burgundy', 2),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '1m', 'Natural', 10),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '2m', 'Natural', 7),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '5m', 'Natural', 3),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '1m', 'Sage', 8),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '2m', 'Sage', 5),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '5m', 'Sage', 2),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '1m', 'White', 11),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '2m', 'White', 9),
  ('bbbb0007-0001-0001-0001-000000000007'::UUID, '5m', 'White', 4),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '1m', 'Flax', 7),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '2m', 'Flax', 5),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '5m', 'Flax', 2),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '1m', 'Oatmeal', 9),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '2m', 'Oatmeal', 6),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '5m', 'Oatmeal', 3),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '1m', 'White', 8),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '2m', 'White', 6),
  ('bbbb0008-0001-0001-0001-000000000008'::UUID, '5m', 'White', 3),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '1m', 'Charcoal', 10),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '2m', 'Charcoal', 7),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '5m', 'Charcoal', 3),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '1m', 'Navy', 11),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '2m', 'Navy', 8),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '5m', 'Navy', 4),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '1m', 'Camel', 6),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '2m', 'Camel', 4),
  ('bbbb0009-0001-0001-0001-000000000009'::UUID, '5m', 'Camel', 1)
) AS v(product_id, size, color, stock)
JOIN products p ON p.id = v.product_id
ON CONFLICT (product_id, size, color) DO NOTHING;
