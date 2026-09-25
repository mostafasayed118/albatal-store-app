-- ============================================================
-- Al Batal Elite — Combined Migration Script
-- Generated: 2026-09-24 20:03:33
--
-- Paste this into Supabase SQL Editor and click Run.
-- Existing projects should use run_migrations.ps1 with the migration ledger.
-- ============================================================

SET client_min_messages = warning;

-- ────────────────────────────────────────────────────────────
-- MIGRATION: 001_initial_schema.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Al Batal Elite — Initial Schema
-- Run this in Supabase SQL Editor or via `supabase db push`
--
-- Idempotent: IF NOT EXISTS on all CREATE statements.
-- Safe to re-run on existing databases.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── PROFILES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── CATEGORIES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  image_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── PRODUCTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  composition TEXT,
  care TEXT,
  origin TEXT,
  base_price INTEGER NOT NULL CHECK (base_price > 0),
  old_price INTEGER CHECK (old_price IS NULL OR old_price > 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  rating NUMERIC(3,2) DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  review_count INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── PRODUCT VARIANTS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_variants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  size TEXT NOT NULL,
  color TEXT NOT NULL,
  price_override INTEGER,
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  sku TEXT UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(product_id, size, color)
);

-- ─── PRODUCT IMAGES ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  alt_text TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── ADDRESSES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient TEXT NOT NULL,
  line TEXT NOT NULL,
  city TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT '',
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── WISHLISTS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, product_id)
);

-- ─── CART ITEMS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, variant_id)
);

-- ─── ORDERS ───────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM ('placed', 'shipped', 'delivered', 'cancelled', 'refunded');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  status order_status NOT NULL DEFAULT 'placed',
  subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
  shipping INTEGER NOT NULL DEFAULT 0 CHECK (shipping >= 0),
  total INTEGER NOT NULL CHECK (total >= 0),
  payment_method TEXT NOT NULL,
  payment_id TEXT,
  address_snapshot JSONB NOT NULL,
  placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── ORDER ITEMS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  product_image_url TEXT,
  size TEXT NOT NULL,
  color TEXT NOT NULL,
  unit_price INTEGER NOT NULL CHECK (unit_price > 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── INDEXES ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_variants_stock ON product_variants(stock) WHERE stock > 0;
CREATE INDEX IF NOT EXISTS idx_product_images_product ON product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_addresses_user ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlists_user ON wishlists(user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user ON cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- ─── UPDATED_AT TRIGGERS ──────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON profiles;
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_products_updated_at ON products;
CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_addresses_updated_at ON addresses;
CREATE TRIGGER set_addresses_updated_at
  BEFORE UPDATE ON addresses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_cart_items_updated_at ON cart_items;
CREATE TRIGGER set_cart_items_updated_at
  BEFORE UPDATE ON cart_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_orders_updated_at ON orders;
CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 002_rls_policies.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Al Batal Elite — Row Level Security Policies
-- Run AFTER 001_initial_schema.sql
--
-- Idempotent: DROP POLICY IF EXISTS before each CREATE POLICY
-- so re-running this migration is safe on existing databases.
-- ============================================================

-- Enable RLS on all tables (safe — idempotent)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- ─── PROFILES ──────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- ─── CATEGORIES ────────────────────────────────────────────
DROP POLICY IF EXISTS "categories_select_public" ON categories;
CREATE POLICY "categories_select_public"
  ON categories FOR SELECT
  USING (is_active = true);

-- ─── PRODUCTS ──────────────────────────────────────────────
DROP POLICY IF EXISTS "products_select_public" ON products;
CREATE POLICY "products_select_public"
  ON products FOR SELECT
  USING (is_active = true);

-- ─── PRODUCT VARIANTS ─────────────────────────────────────
DROP POLICY IF EXISTS "variants_select_public" ON product_variants;
CREATE POLICY "variants_select_public"
  ON product_variants FOR SELECT
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM products
      WHERE products.id = product_variants.product_id
        AND products.is_active = true
    )
  );

-- ─── PRODUCT IMAGES ───────────────────────────────────────
DROP POLICY IF EXISTS "images_select_public" ON product_images;
CREATE POLICY "images_select_public"
  ON product_images FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM products
      WHERE products.id = product_images.product_id
        AND products.is_active = true
    )
  );

-- ─── ADDRESSES ────────────────────────────────────────────
DROP POLICY IF EXISTS "addresses_select_own" ON addresses;
CREATE POLICY "addresses_select_own"
  ON addresses FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "addresses_insert_own" ON addresses;
CREATE POLICY "addresses_insert_own"
  ON addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "addresses_update_own" ON addresses;
CREATE POLICY "addresses_update_own"
  ON addresses FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "addresses_delete_own" ON addresses;
CREATE POLICY "addresses_delete_own"
  ON addresses FOR DELETE
  USING (auth.uid() = user_id);

-- ─── WISHLISTS ────────────────────────────────────────────
DROP POLICY IF EXISTS "wishlists_select_own" ON wishlists;
CREATE POLICY "wishlists_select_own"
  ON wishlists FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "wishlists_insert_own" ON wishlists;
CREATE POLICY "wishlists_insert_own"
  ON wishlists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "wishlists_delete_own" ON wishlists;
CREATE POLICY "wishlists_delete_own"
  ON wishlists FOR DELETE
  USING (auth.uid() = user_id);

-- ─── CART ITEMS ───────────────────────────────────────────
DROP POLICY IF EXISTS "cart_select_own" ON cart_items;
CREATE POLICY "cart_select_own"
  ON cart_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_insert_own" ON cart_items;
CREATE POLICY "cart_insert_own"
  ON cart_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_update_own" ON cart_items;
CREATE POLICY "cart_update_own"
  ON cart_items FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "cart_delete_own" ON cart_items;
CREATE POLICY "cart_delete_own"
  ON cart_items FOR DELETE
  USING (auth.uid() = user_id);

-- ─── ORDERS ───────────────────────────────────────────────
DROP POLICY IF EXISTS "orders_select_own" ON orders;
CREATE POLICY "orders_select_own"
  ON orders FOR SELECT
  USING (auth.uid() = user_id);

-- ─── ORDER ITEMS ──────────────────────────────────────────
DROP POLICY IF EXISTS "order_items_select_own" ON order_items;
CREATE POLICY "order_items_select_own"
  ON order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 003_auth_profiles_and_hardening.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Al Batal Elite — Auth, Profiles & Admin Role
-- Run AFTER 002_rls_policies.sql
--
-- Idempotent: CREATE OR REPLACE for functions/triggers,
-- DROP POLICY IF EXISTS before each CREATE POLICY.
-- ============================================================

-- ─── PROFILE AUTO-CREATION TRIGGER ────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users inserts (drop + create to ensure it points to the latest function)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── ADMIN ROLE ───────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

DROP POLICY IF EXISTS "admin_select_all_orders" ON orders;
CREATE POLICY "admin_select_all_orders"
  ON orders FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_update_orders" ON orders;
CREATE POLICY "admin_update_orders"
  ON orders FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_manage_products" ON products;
CREATE POLICY "admin_manage_products"
  ON products FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_manage_categories" ON categories;
CREATE POLICY "admin_manage_categories"
  ON categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_manage_variants" ON product_variants;
CREATE POLICY "admin_manage_variants"
  ON product_variants FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- ─── PROFILE UPDATE PROTECTION ────────────────────────────
DROP POLICY IF EXISTS "profiles_update_own_safe" ON profiles;
CREATE POLICY "profiles_update_own_safe"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
  );

-- ─── ORDER CREATION PROTECTION ────────────────────────────
DROP POLICY IF EXISTS "orders_insert_denied" ON orders;
CREATE POLICY "orders_insert_denied"
  ON orders FOR INSERT
  WITH CHECK (false);

DROP POLICY IF EXISTS "order_items_insert_denied" ON order_items;
CREATE POLICY "order_items_insert_denied"
  ON order_items FOR INSERT
  WITH CHECK (false);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 004_stock_function.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Stock decrement function (called by Edge Function)
-- ============================================================

CREATE OR REPLACE FUNCTION decrement_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID AS $$
BEGIN
  UPDATE product_variants
  SET stock = stock - p_quantity
  WHERE product_id = p_product_id
    AND size = p_size
    AND color = p_color
    AND stock >= p_quantity;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock for variant %/%', p_size, p_color;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 005_storage_buckets.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Storage buckets for product images
-- Run AFTER tables are created
--
-- Idempotent: DROP POLICY IF EXISTS before each CREATE POLICY
-- so re-running this migration is safe.
-- ============================================================

-- Create storage buckets (safe — ON CONFLICT DO NOTHING)
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('product-images', 'product-images', true),
  ('avatars', 'avatars', false)
ON CONFLICT (id) DO NOTHING;

-- Public read access for product images
DROP POLICY IF EXISTS "product_images_select_public" ON storage.objects;
CREATE POLICY "product_images_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- Authenticated users can upload their own avatar
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can read their own avatar
DROP POLICY IF EXISTS "avatars_select_own" ON storage.objects;
CREATE POLICY "avatars_select_own"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can update their own avatar
DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete their own avatar
DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Admins can manage product images
DROP POLICY IF EXISTS "product_images_admin_all" ON storage.objects;
CREATE POLICY "product_images_admin_all"
  ON storage.objects FOR ALL
  USING (
    bucket_id = 'product-images'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 006_payments_table.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Payments table for tracking payment transactions
-- Run AFTER 005_storage_buckets.sql
--
-- Idempotent: CREATE TABLE IF NOT EXISTS, DROP POLICY IF EXISTS.
-- ============================================================

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  method TEXT NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  phone_number TEXT,
  transaction_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes (safe — IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_own" ON payments;
CREATE POLICY "payments_select_own"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "payments_insert_own" ON payments;
CREATE POLICY "payments_insert_own"
  ON payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Updated_at trigger (drop + create to ensure it points to latest function)
DROP TRIGGER IF EXISTS set_payments_updated_at ON payments;
CREATE TRIGGER set_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 007_stock_increment_function.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Stock increment function (for payment failure recovery)
-- ============================================================

CREATE OR REPLACE FUNCTION increment_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID AS $$
BEGIN
  UPDATE product_variants
  SET stock = stock + p_quantity
  WHERE product_id = p_product_id
    AND size = p_size
    AND color = p_color;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 008_order_fulfillment.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Order fulfillment SQL functions
-- ============================================================

-- Update order status with validation
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_tracking_number TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  -- Get current status
  SELECT status INTO v_current_status FROM orders WHERE id = p_order_id;

  -- Validate transition
  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Define valid transitions
  IF v_current_status = 'placed' AND p_new_status NOT IN ('processing', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from placed to %', p_new_status;
  ELSIF v_current_status = 'processing' AND p_new_status NOT IN ('shipped', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from processing to %', p_new_status;
  ELSIF v_current_status = 'shipped' AND p_new_status NOT IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from shipped to %', p_new_status;
  ELSIF v_current_status IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Cannot change status of % order', v_current_status;
  END IF;

  -- Update status
  UPDATE orders
  SET status = p_new_status::order_status,
      updated_at = now()
  WHERE id = p_order_id;

  -- Store tracking number if provided
  IF p_tracking_number IS NOT NULL THEN
    UPDATE orders
    SET payment_id = p_tracking_number
    WHERE id = p_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get order with items for admin view
CREATE OR REPLACE FUNCTION get_order_details(p_order_id UUID)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'order', (SELECT row_to_json(o) FROM orders o WHERE o.id = p_order_id),
    'items', (SELECT json_agg(row_to_json(oi)) FROM order_items oi WHERE oi.order_id = p_order_id),
    'customer', (SELECT row_to_json(p) FROM profiles p WHERE p.id = (SELECT user_id FROM orders WHERE id = p_order_id))
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Low stock alert query (run periodically)
CREATE OR REPLACE FUNCTION get_low_stock_products(p_threshold INTEGER DEFAULT 5)
RETURNS TABLE (
  product_name TEXT,
  variant_size TEXT,
  variant_color TEXT,
  current_stock INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.name,
    pv.size,
    pv.color,
    pv.stock
  FROM product_variants pv
  JOIN products p ON p.id = pv.product_id
  WHERE pv.stock <= p_threshold
    AND pv.is_active = true
    AND p.is_active = true
  ORDER BY pv.stock ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 009_shipping_zones.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Shipping zones and delivery fee calculation
--
-- Idempotent: CREATE TABLE IF NOT EXISTS, INSERT ... ON CONFLICT.
-- ============================================================

CREATE TABLE IF NOT EXISTS shipping_zones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  governorates TEXT[] NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0 CHECK (fee >= 0),
  estimated_days_min INTEGER NOT NULL DEFAULT 1,
  estimated_days_max INTEGER NOT NULL DEFAULT 3,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shipping_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Default config (safe — ON CONFLICT DO NOTHING)
INSERT INTO shipping_config (key, value) VALUES
  ('free_shipping_threshold', '50000'),
  ('default_fee', '7500'),
  ('default_days_min', '1'),
  ('default_days_max', '3')
ON CONFLICT (key) DO NOTHING;

-- Default zones for Egypt (safe — skip if zones already exist)
INSERT INTO shipping_zones (name, governorates, fee, estimated_days_min, estimated_days_max)
SELECT * FROM (VALUES
  ('Cairo & Giza', ARRAY['Cairo', 'Giza'], 5000, 1, 2),
  ('Alexandria', ARRAY['Alexandria'], 6000, 1, 2),
  ('Delta', ARRAY['Dakahlia', 'Sharqia', 'Gharbia', 'Monufia', 'Qalyubia', 'Beheira', 'Kafr El Sheikh'], 7000, 2, 3),
  ('Upper Egypt', ARRAY['Minya', 'Assiut', 'Sohag', 'Qena', 'Luxor', 'Aswan'], 8000, 3, 5),
  ('Canal Cities', ARRAY['Ismailia', 'Port Said', 'Suez'], 7000, 2, 3),
  ('Sinai', ARRAY['North Sinai', 'South Sinai'], 10000, 4, 7),
  ('Matrouh & Red Sea', ARRAY['Matrouh', 'Red Sea'], 9000, 3, 5)
) AS v(name, governorates, fee, days_min, days_max)
WHERE NOT EXISTS (SELECT 1 FROM shipping_zones LIMIT 1);

-- RLS
ALTER TABLE shipping_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shipping_zones_select_public" ON shipping_zones;
CREATE POLICY "shipping_zones_select_public"
  ON shipping_zones FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "shipping_config_select_public" ON shipping_config;
CREATE POLICY "shipping_config_select_public"
  ON shipping_config FOR SELECT
  USING (true);

-- Function to calculate shipping fee (safe — CREATE OR REPLACE)
CREATE OR REPLACE FUNCTION calculate_shipping_fee(
  p_governorate TEXT,
  p_subtotal INTEGER
)
RETURNS INTEGER AS $$
DECLARE
  v_threshold INTEGER;
  v_fee INTEGER;
BEGIN
  SELECT value::INTEGER INTO v_threshold
  FROM shipping_config WHERE key = 'free_shipping_threshold';

  IF p_subtotal >= v_threshold THEN
    RETURN 0;
  END IF;

  SELECT sz.fee INTO v_fee
  FROM shipping_zones sz
  WHERE p_governorate = ANY(sz.governorates)
    AND sz.is_active = true
  LIMIT 1;

  IF v_fee IS NULL THEN
    SELECT value::INTEGER INTO v_fee
    FROM shipping_config WHERE key = 'default_fee';
  END IF;

  RETURN v_fee;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 010_notifications_analytics.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Notifications and Analytics tables
-- Run AFTER 009_shipping_zones.sql
--
-- Idempotent: CREATE TABLE IF NOT EXISTS, DROP POLICY IF EXISTS.
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  recipient_email TEXT NOT NULL,
  recipient_name TEXT,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed', 'pending')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_order ON notifications(order_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event TEXT NOT NULL,
  properties JSONB DEFAULT '{}',
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_event ON analytics_events(event);
CREATE INDEX IF NOT EXISTS idx_analytics_user ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_created ON analytics_events(created_at);

CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message TEXT NOT NULL,
  context TEXT,
  error TEXT,
  stack_trace TEXT,
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  environment TEXT NOT NULL DEFAULT 'production',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_error_logs_created ON error_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_environment ON error_logs(environment);

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (auth.uid() = (
    SELECT user_id FROM orders WHERE id = notifications.order_id
  ));

DROP POLICY IF EXISTS "notifications_insert_service" ON notifications;
CREATE POLICY "notifications_insert_service"
  ON notifications FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "analytics_insert_service" ON analytics_events;
CREATE POLICY "analytics_insert_service"
  ON analytics_events FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "error_logs_insert_service" ON error_logs;
CREATE POLICY "error_logs_insert_service"
  ON error_logs FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "admin_select_analytics" ON analytics_events;
CREATE POLICY "admin_select_analytics"
  ON analytics_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

DROP POLICY IF EXISTS "admin_select_errors" ON error_logs;
CREATE POLICY "admin_select_errors"
  ON error_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 011_orders_idempotency_and_expiry.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 011: Add idempotency_key, expires_at, and missing
-- order_status values used by the checkout and payment cycle.
--
-- idempotency_key: prevents duplicate orders on network retry.
--   NULL = non-idempotent request (legacy). Non-NULL = client
--   supplied a key; CHECK constraint enforces uniqueness per user.
-- expires_at: orders that are still "pending" after this time
--   should be cancelled and stock restored by a scheduled function.
--
-- Order statuses: 'pending', 'processing', 'paid' are added here
-- so the checkout RPC (013) can reference them.
--
-- NOTE: PostgreSQL forbids using a newly-added enum value in a
-- CREATE INDEX WHERE clause within the same transaction. The
-- idx_orders_expires index therefore filters only on
-- expires_at IS NOT NULL. The cancel-expired-orders query adds
-- status = 'pending' in its WHERE clause, which is efficient
-- because the index narrows the scan to rows with a non-null
-- expires_at (the common case is NULL for completed orders).
--
-- Run AFTER 010_notifications_analytics.sql.
-- ============================================================

-- ─── Add missing order_status enum values ─────────────────
-- The original enum (001) had: placed, shipped, delivered,
-- cancelled, refunded. The checkout cycle needs 'pending' and
-- 'paid'; the admin fulfillment cycle needs 'processing'.
-- ADD VALUE IF NOT EXISTS is safe on Postgres 15+ (Supabase).
-- Each statement must be its own statement (cannot be combined).
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'paid';

-- ─── Add columns ──────────────────────────────────────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- ─── Unique constraint: one idempotency_key per user ──────
-- NULLs allowed (non-idempotent requests). The unique index
-- prevents duplicate orders on network retry for the same key.
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency
  ON orders (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ─── Index for the scheduled cleanup query ────────────────
-- Finds rows with a non-null expires_at so the cancel-expired-
-- orders function can efficiently scan for expired pending
-- orders. The status = 'pending' filter is applied in the
-- query's WHERE clause, not in the index, because PostgreSQL
-- forbids referencing a newly-added enum value in CREATE INDEX
-- within the same transaction as the ALTER TYPE ADD VALUE.
CREATE INDEX IF NOT EXISTS idx_orders_expires
  ON orders (expires_at)
  WHERE expires_at IS NOT NULL;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 012_add_order_statuses.sql
-- ────────────────────────────────────────────────────────────
-- Add missing order_status values used by edge functions and the fulfillment trigger.
--
-- The checkout Edge Function inserts orders as "pending" (pre-payment).
-- The paymob-callback promotes them to "paid" on success.
-- The update_order_status trigger (008) transitions "placed" -> "processing".
-- "refunded" was already in the original enum (001) but not used by the client.
--
-- ALTER TYPE ... ADD VALUE is non-transactional in Postgres < 12, but
-- Supabase runs Postgres 15+, so it is safe inside a migration block.
-- Each ADD VALUE must be its own statement (cannot be combined).

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'paid';


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 013_atomic_checkout_rpc.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 013: Atomic server-side checkout RPC
--
-- Replaces the multi-step edge-function checkout with a single
-- SECURITY DEFINER RPC that runs in one transaction. The client
-- is never trusted for price, shipping, total, user id, or stock.
--
-- The function:
--   1. Authenticates via auth.uid()
--   2. Validates the address has required fields
--   3. Returns an existing order if the idempotency key matches
--   4. Looks up each variant, reads DB price, checks stock
--   5. Calculates shipping via calculate_shipping_fee()
--   6. Inserts order + order_items with snapshotted prices
--   7. Decrements stock atomically (WHERE stock >= qty)
--   8. Clears the user's cart_items
--   9. Returns the canonical order data
--
-- Any failure rolls back the entire transaction.
-- ============================================================

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ─── Validate payment method ─────────────────────────────
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- ─── Validate items ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- ─── Validate address ────────────────────────────────────
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- ─── Idempotency: return existing order if key matches ───
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true
      );
    END IF;
  END IF;

   -- ─── Validate items, read DB prices, check stock ────────
  -- TODO(audit): batch variant SELECT with UNNEST + FOR UPDATE to prevent concurrent oversell (see 025 race_safe)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- Look up variant and product in one query
    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    -- Collect validated item for later insert
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- ─── Calculate shipping from shipping-zone logic ────────
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);
  v_total    := v_subtotal + v_shipping;

   -- ─── Compute expiry ──────────────────────────────────────
   v_expires_at := now() + interval '15 minutes';

   -- ─── Ensure a profile exists ──────────────────────────
   -- The handle_new_user() trigger on auth.users should have
   -- created a profile, but users who signed up before that
   -- trigger was added, or whose profile was deleted, would
   -- hit a FK violation on orders.user_id -> profiles(id).
   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   -- ─── Insert order (atomic with the rest) ─────────────────
   -- Wrap in a sub-block so a unique-constraint violation on
   -- idempotency_key (from a concurrent request with the same
   -- key) is caught and the existing order is returned instead.
   BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    -- A concurrent request with the same idempotency_key won
    -- the race. Return its result.
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
      'expires_at', v_existing_expires,
      'idempotent', true
    );
  END;

  -- ─── Insert order items + decrement stock ────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

    -- Insert the snapshotted order item
    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    -- Atomically decrement stock — the WHERE stock >= guard
    -- is the real race protection. If this fails the entire
    -- transaction rolls back (order + items are undone).
    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- ─── Clear the user's server-side cart ──────────────────
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- ─── Return the canonical order data ─────────────────────
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false
  );
END;
$$;

-- Grant execute to authenticated users (the RPC checks auth.uid()
-- internally, so public execute is safe — unauthenticated calls
-- will fail at the auth check inside the function).
GRANT EXECUTE ON FUNCTION create_checkout_order TO PUBLIC;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 014_paymob_security_repair.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 014: Paymob security repair
--
-- Forward-only migration that fixes the P0 Paymob security
-- defects identified in the audit:
--
--   HIGH-03: adds a durable `paymob_order_id` column to
--           `payments` so the callback can map a Paymob
--           provider order to the internal order/payment
--           without treating the provider order ID as an
--           internal UUID.
--   HIGH-04: rewrites `update_order_status` so a `paid`
--           order can move through the fulfillment state
--           machine (`paid → processing → shipped →
--           delivered`) and so invalid transitions fail
--           server-side. The RPC now checks `profiles.is_admin`
--           directly (defense in depth on top of RLS).
--   HIGH-05: adds `process_paymob_callback` — an atomic,
--           SECURITY DEFINER RPC that the Edge Function
--           invokes after HMAC verification. It maps the
--           provider order to the internal payment, validates
--           amount/currency, persists the real Paymob
--           transaction id exactly once, transitions the
--           order and payment state in one transaction, and
--           restores stock exactly once on failure. A
--           duplicate callback is a no-op.
--
-- This migration NEVER edits historical migrations. It only
-- adds new columns, indexes, functions, and constraints.
--
-- Rollback:
--   This migration is forward-only in production. To roll
--   back on a staging database that has NOT shipped to
--   production, run the statements in reverse order:
--     DROP FUNCTION IF EXISTS process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN);
--     DROP INDEX IF EXISTS idx_payments_provider_txn;
--     DROP INDEX IF EXISTS idx_payments_paymob_order_id;
--     ALTER TABLE payments DROP COLUMN IF EXISTS paymob_order_id;
--   and restore the previous `update_order_status` from
--   migration 008. Do NOT roll back after production deploy.
--
-- Staging application:
--   Apply with `supabase db push` or by running this file in
--   the SQL editor on the staging project. Verify with:
--     \d payments                      -- column present
--     SELECT proname FROM pg_proc WHERE proname IN ('process_paymob_callback','update_order_status');
--   Then run the callback test fixture
--   (`test_paymob_callback.sql`) to confirm the state
--   transitions before pointing the Edge Function at staging.
-- ============================================================

-- ─── HIGH-03: provider order bridge on payments ───────────
-- `paymob_order_id` stores the numeric Paymob provider order
-- id (returned by /api/ecommerce/orders) at initiation time.
-- The callback uses it to locate the internal payment row
-- WITHOUT ever feeding the provider order id into `orders.id`
-- (which is a UUID). Nullable so existing rows survive.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_order_id TEXT;

-- One internal payment per provider order id. NULLs are
-- allowed for legacy rows that pre-date this migration.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_paymob_order_id
  ON payments (paymob_order_id)
  WHERE paymob_order_id IS NOT NULL;

-- The real Paymob transaction id is written exactly once by
-- the callback RPC. Keep the existing unique constraint on
-- `transaction_id` (migration 006) and add a partial index
-- so lookups by provider transaction id are fast.
CREATE INDEX IF NOT EXISTS idx_payments_provider_txn
  ON payments (transaction_id)
  WHERE transaction_id IS NOT NULL;

-- ─── HIGH-04: fulfillment state machine incl. `paid` ──────
-- Replace the 008 `update_order_status` with a version that
--   * accepts the `paid` source state,
--   * allows `paid → processing`, `paid → cancelled`,
--   * keeps `processing → shipped/cancelled`,
--   * keeps `shipped → delivered/cancelled`,
--   * denies every other transition,
--   * verifies the caller is an admin by reading
--     `profiles.is_admin` directly (the RPC is SECURITY
--     DEFINER, so this check is independent of RLS and
--     survives even if RLS is misconfigured),
--   * restores stock exactly once when an order that has
--     reserved stock is cancelled, using a guarded update
--     that only fires when the status actually flips to
--     `cancelled`.
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_tracking_number TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_current      TEXT;
  v_is_admin     BOOLEAN;
  v_do_restore   BOOLEAN;
  v_restored     UUID;
BEGIN
  -- ─── Admin authorization (defense in depth) ───────────
  -- RLS already gates UPDATE on `admin_update_orders`, but
  -- this RPC is SECURITY DEFINER and runs as the owner. We
  -- re-check `is_admin` so a non-admin JWT that somehow
  -- reaches the RPC still fails.
  SELECT COALESCE(profiles.is_admin, false)
    INTO v_is_admin
    FROM profiles
    WHERE profiles.id = auth.uid();

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- ─── Load current status (lock the row) ────────────────
  SELECT status INTO v_current
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- ─── Validate transition ───────────────────────────────
  -- `pending` is the pre-payment state. The callback RPC
  -- (not this function) is the only path that promotes
  -- `pending → paid`. Admins cancel expired/abandoned
  -- pending orders through here.
  IF v_current = 'pending' AND p_new_status NOT IN ('cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from pending to %', p_new_status;
  ELSIF v_current = 'paid' AND p_new_status NOT IN ('processing', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from paid to %', p_new_status;
  ELSIF v_current = 'placed' AND p_new_status NOT IN ('processing', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from placed to %', p_new_status;
  ELSIF v_current = 'processing' AND p_new_status NOT IN ('shipped', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from processing to %', p_new_status;
  ELSIF v_current = 'shipped' AND p_new_status NOT IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from shipped to %', p_new_status;
  ELSIF v_current IN ('delivered', 'cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cannot change status of % order', v_current;
  END IF;

  -- ─── Apply transition ──────────────────────────────────
  -- Track whether we are about to cancel an order that had
  -- reserved stock so stock is restored exactly once.
  v_do_restore := (p_new_status = 'cancelled' AND v_current <> 'cancelled');

  UPDATE orders
    SET status = p_new_status::order_status,
        updated_at = now(),
        payment_id = COALESCE(p_tracking_number, payment_id)
    WHERE id = p_order_id;

  -- ─── Stock restoration on cancel (exactly once) ────────
  -- The `stock_restorations` ledger guarantees we only
  -- restore once per order, even if this function is called
  -- twice. The `order_items.restored` flag + trigger do the
  -- actual stock increment; the ledger is the guard.
  IF v_do_restore THEN
    INSERT INTO stock_restorations (order_id, restored_at)
      SELECT p_order_id, now()
      WHERE NOT EXISTS (
        SELECT 1 FROM stock_restorations
          WHERE order_id = p_order_id
      )
      RETURNING order_id INTO v_restored;

    IF FOUND THEN
      -- First cancel for this order — flip the restored flag
      -- on its items. The trigger `trg_restore_stock_on_item`
      -- increments product_variants.stock exactly once per
      -- item (guarded by `restored = false → true`).
      UPDATE order_items
        SET restored = true
        WHERE order_id = p_order_id
          AND restored = false;
    END IF;
  END IF;
END;
$$;

-- Keep the grant from 008.
GRANT EXECUTE ON FUNCTION update_order_status TO PUBLIC;

-- ─── Stock restoration ledger ─────────────────────────────
-- A tiny table that records, per order, whether stock has
-- already been restored. The callback and the cancel path
-- both consult it so a duplicate callback or a double
-- cancel never restores stock twice.
CREATE TABLE IF NOT EXISTS stock_restorations (
  order_id UUID PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
  restored_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- `order_items.restored` flags whether a line item's stock
-- has already been incremented back. The cancel trigger and
-- the callback failure path both set it atomically.
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS restored BOOLEAN NOT NULL DEFAULT false;

-- ─── Trigger: restore stock once when an item flips to restored
-- The trigger increments `product_variants.stock` exactly
-- once per order_items row, guarded by `restored = false`.
-- Both the admin cancel path and the callback failure path
-- set `restored = true`; the trigger does the increment.
CREATE OR REPLACE FUNCTION restore_stock_on_item_restore()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.restored = true AND OLD.restored = false THEN
    UPDATE product_variants
      SET stock = stock + NEW.quantity
      WHERE id = NEW.variant_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_restore_stock_on_item ON order_items;
CREATE TRIGGER trg_restore_stock_on_item
  AFTER UPDATE OF restored ON order_items
  FOR EACH ROW
  WHEN (NEW.restored = true AND OLD.restored = false)
  EXECUTE FUNCTION restore_stock_on_item_restore();

-- ─── HIGH-05: atomic callback processing RPC ─────────────
-- `process_paymob_callback` is the single transactional
-- entry point the Edge Function calls AFTER it has verified
-- the HMAC signature. It:
--   1. Locates the internal payment by `paymob_order_id`
--      (never by provider order id on `orders.id`).
--   2. Rejects if no matching payment exists (no orphan
--      insert — CRIT-02).
--   3. Validates the callback amount/currency against the
--      internal order total.
--   4. If the payment is already `success`/`failed`, returns
--      `already_processed` so the Edge Function can reply
--      2xx no-op (idempotent — HIGH-05).
--   5. On success: sets payment.status = 'success', stores
--      the real Paymob transaction id exactly once, promotes
--      the order from `pending` to `paid` (only if still
--      `pending`).
--   6. On failure: sets payment.status = 'failed', cancels
--      the order (only if still `pending`), and restores
--      stock exactly once via the guarded `restored` flag.
--   7. Never downgrades a `paid`/`processing`/`shipped`/
--      `delivered` order on a duplicate or late callback.
--
-- The RPC is SECURITY DEFINER because the Edge Function
-- calls it with the service-role client; it performs its
-- own authorization by requiring the caller to present the
-- already-verified provider order id and transaction id.
CREATE OR REPLACE FUNCTION process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id   TEXT,
  p_amount_cents    INTEGER,
  p_currency        TEXT,
  p_success         BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment        RECORD;
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Locate the internal payment by provider order id ──
  -- CRIT-01/CRIT-04 fix: never use the provider order id on
  -- `orders.id`. The payment row was created at initiation
  -- with `paymob_order_id` populated.
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    -- CRIT-02 fix: no fallback/orphan payment insert.
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  -- ─── Lock the order row and read canonical total ───────
  SELECT total INTO v_order_total
    FROM orders
    WHERE id = v_payment.order_id
    FOR UPDATE;

  IF v_order_total IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Validate amount/currency (callback requirement B8) ─
  IF p_amount_cents IS NULL OR p_amount_cents <> v_order_total THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'amount_mismatch',
      'expected', v_order_total,
      'received', p_amount_cents
    );
  END IF;

  IF p_currency IS NOT NULL AND p_currency <> v_order_currency THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'currency_mismatch',
      'expected', v_order_currency,
      'received', p_currency
    );
  END IF;

  -- ─── Idempotency: already terminal ─────────────────────
  -- HIGH-05: a duplicate valid callback is a no-op.
  IF v_payment.status = 'success' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  IF v_payment.status = 'failed' THEN
    -- A late failure callback for a payment we already failed.
    -- Do not downgrade an order that has since moved on.
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  -- ─── Apply the terminal transition ─────────────────────
  IF p_success THEN
    -- Persist the real Paymob transaction id exactly once.
    UPDATE payments
      SET status = 'success',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    -- Promote the order to `paid` ONLY if it is still
    -- `pending`. A duplicate success callback cannot
    -- downgrade a `paid`/`processing`/`shipped`/`delivered`
    -- order (CRIT-04).
    UPDATE orders
      SET status = 'paid'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'success',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  ELSE
    -- Failure: mark payment failed, cancel order if still
    -- pending, restore stock exactly once.
    UPDATE payments
      SET status = 'failed',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'cancelled'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    -- Stock restoration happens exactly once via the
    -- `restored` flag on order_items + the trigger.
    UPDATE order_items
      SET restored = true
      WHERE order_id = v_payment.order_id
        AND restored = false;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'failed',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  END IF;

  RETURN v_result;
END;
$$;

-- The Edge Function calls this with the service-role client;
-- public execute is safe because the RPC performs its own
-- authorization (it only acts on payments that already exist
-- and were created by the initiation flow).
GRANT EXECUTE ON FUNCTION process_paymob_callback TO PUBLIC;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 015_payments_update_and_stock_hardening.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 015: payment update authorization and stock hardening
--
-- This forward-only migration repairs the remaining P0 gaps:
--   1. `paymob-initiate` cannot update payments.paymob_order_id through
--      RLS. The restricted RPC below is the only authenticated path.
--   2. `process_paymob_callback` was executable by PUBLIC even though
--      it trusts the Edge Function's already-verified HMAC. A customer
--      could otherwise call it directly and forge success.
--   3. Legacy stock mutation functions were SECURITY DEFINER with a
--      mutable search_path and PUBLIC execution.
--   4. Expired pending orders need one transactional server-side path
--      that changes payment/order state and restores stock exactly once.
--
-- SECURITY MODEL
--   * Flutter never directly updates `payments`.
--   * A signed-in owner can set a provider order id exactly once while
--     their payment is still pending, through the restricted RPC.
--   * Only the service-role Edge Functions can process provider callbacks,
--     mutate legacy stock functions, or expire pending orders.
--   * Authenticated admins continue to call update_order_status; that
--     RPC verifies profiles.is_admin internally (migration 014).
-- ============================================================

-- Add explicit server-side terminal states used by the expiry worker.
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE payments
  ADD CONSTRAINT payments_status_check
  CHECK (status IN ('pending', 'success', 'failed', 'cancelled', 'expired', 'refunded'));

-- Persist the provider order bridge exactly once. The calling Edge Function
-- uses the authenticated user's JWT, so this RPC verifies ownership itself.
CREATE OR REPLACE FUNCTION set_payment_provider_order_id(
  p_payment_id UUID,
  p_paymob_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_payment RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_payment_id IS NULL OR COALESCE(btrim(p_paymob_order_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT id, user_id, status, paymob_order_id
    INTO v_payment
    FROM payments
    WHERE id = p_payment_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_found');
  END IF;

  IF v_payment.user_id <> auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_pending');
  END IF;

  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_set');
  END IF;

  UPDATE payments
    SET paymob_order_id = btrim(p_paymob_order_id),
        updated_at = now()
    WHERE id = p_payment_id;

  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_payment_provider_order_id(UUID, TEXT) TO authenticated;

-- Restrict sensitive callback execution to the service-role Edge Function.
-- HMAC verification happens in paymob-callback before this RPC is called;
-- therefore authenticated/anonymous clients must never execute it directly.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- Legacy stock functions are used only by trusted service-side jobs. Keep
-- their signatures for compatibility, but lock both function execution and
-- SECURITY DEFINER name resolution down.
CREATE OR REPLACE FUNCTION decrement_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive';
  END IF;

  UPDATE product_variants
    SET stock = stock - p_quantity
    WHERE product_id = p_product_id
      AND size = p_size
      AND color = p_color
      AND stock >= p_quantity;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock for variant %/%', p_size, p_color;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION increment_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive';
  END IF;

  UPDATE product_variants
    SET stock = stock + p_quantity
    WHERE product_id = p_product_id
      AND size = p_size
      AND color = p_color;
END;
$$;

REVOKE ALL ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;

-- Atomic expiry used by cancel-expired-orders. It locks the order, updates
-- only still-pending rows, marks a pending payment expired, and flips the
-- restored flag so the migration-014 trigger restores inventory once.
CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'code', 'already_terminal');
  END IF;

  IF v_order.expires_at IS NULL OR v_order.expires_at >= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_expired');
  END IF;

  UPDATE orders
    SET status = 'cancelled'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  UPDATE payments
    SET status = 'expired',
        updated_at = now()
    WHERE order_id = p_order_id
      AND status = 'pending';

  UPDATE order_items
    SET restored = true
    WHERE order_id = p_order_id
      AND restored = false;

  RETURN jsonb_build_object('ok', true, 'code', 'expired');
END;
$$;

REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- `update_order_status` deliberately remains executable by authenticated
-- callers because the admin Flutter app uses the authenticated client. The
-- SECURITY DEFINER implementation in migration 014 checks profiles.is_admin
-- independently of RLS before any state transition is applied.


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 016_seed_product_catalog.sql
-- ────────────────────────────────────────────────────────────
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


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 017_authorize_rpcs.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 016: Authorize get_order_details and get_low_stock_products
--
-- SECURITY DEFICIT (P0.3):
--   `get_order_details(p_order_id)` (migration 008) has NO
--   authorization check. Any authenticated user can call it
--   with any order UUID and read another customer's order,
--   items, and profile data. This is an IDOR vulnerability.
--
--   `get_low_stock_products(p_threshold)` (migration 008)
--   has NO authorization check. Any authenticated user can
--   call it and read inventory levels — information that
--   should be restricted to admins.
--
-- FIX:
--   Replace both functions with versions that verify
--   authorization internally. The RPC is SECURITY DEFINER,
--   so the check is independent of RLS.
--
-- ROLLBACK:
--   Re-run the original CREATE OR REPLACE from migration 008.
-- ============================================================

-- ─── get_order_details: owner OR admin authorization ───────
-- A signed-in user may only read their own order. An admin
-- may read any order. The function is SECURITY DEFINER so
-- auth.uid() is reliable regardless of RLS configuration.
CREATE OR REPLACE FUNCTION get_order_details(p_order_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_id UUID;
  v_is_admin  BOOLEAN;
  v_owner_id  UUID;
  v_result    JSON;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Check if caller is admin (defense in depth).
  SELECT COALESCE(profiles.is_admin, false)
    INTO v_is_admin
    FROM profiles
    WHERE profiles.id = v_caller_id;

  -- Check order ownership.
  SELECT user_id INTO v_owner_id
    FROM orders
    WHERE id = p_order_id;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Authorization: owner or admin only.
  IF v_owner_id <> v_caller_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT json_build_object(
    'order', (SELECT row_to_json(o) FROM orders o WHERE o.id = p_order_id),
    'items', (SELECT json_agg(row_to_json(oi)) FROM order_items oi WHERE oi.order_id = p_order_id),
    'customer', (SELECT row_to_json(p) FROM profiles p WHERE p.id = v_owner_id)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Revoke PUBLIC and grant to authenticated (owner check is internal).
REVOKE ALL ON FUNCTION get_order_details(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_order_details(UUID) TO authenticated;

-- ─── get_low_stock_products: admin only ───────────────────
-- Inventory levels are sensitive business data. Only admins
-- should be able to query low-stock products.
CREATE OR REPLACE FUNCTION get_low_stock_products(p_threshold INTEGER DEFAULT 5)
RETURNS TABLE (
  product_name TEXT,
  variant_size TEXT,
  variant_color TEXT,
  current_stock INTEGER
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(profiles.is_admin, false)
    INTO v_is_admin
    FROM profiles
    WHERE profiles.id = auth.uid();

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    p.name,
    pv.size,
    pv.color,
    pv.stock
  FROM product_variants pv
  JOIN products p ON p.id = pv.product_id
  WHERE pv.stock <= p_threshold
    AND pv.is_active = true
    AND p.is_active = true
  ORDER BY pv.stock ASC;
END;
$$;

-- Revoke PUBLIC and grant to authenticated (admin check is internal).
REVOKE ALL ON FUNCTION get_low_stock_products(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_low_stock_products(INTEGER) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 018_confirm_cod_payment.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 018: confirm_cod_payment RPC
--
-- The Flutter client calls `confirm_cod_payment` via
-- `supabase.rpc('confirm_cod_payment', params: {'p_order_id': ...})`
-- when the user selects Cash on Delivery. No Edge Function is
-- involved — the authenticated client calls the RPC directly.
--
-- PROBLEM THIS FIXES:
--   The RPC was referenced in Dart code (PaymobPaymentService,
--   PaymentCubit, PaymentService interface) and in unit tests
--   but never defined in any migration. Every COD payment
--   attempt failed with a PostgREST "function not found" error.
--
-- BEHAVIOR:
--   1. Verifies authentication (auth.uid() not null)
--   2. Finds the order, verifies ownership and pending status
--   3. Verifies the order's payment_method is COD
--      (tolerant ILIKE match on 'cash' or 'cod')
--   4. Finds or creates a COD payment row for this order
--   5. Atomically: payment.status = 'success', order.status = 'paid'
--   6. Returns { ok: true, transaction_id } or error code
--
-- The RPC is SECURITY DEFINER with search_path = public, auth
-- (same pattern as create_checkout_order, process_paymob_callback).
--
-- ERROR CODES (mapped to user-safe messages in PaymobPaymentService):
--   authentication_required  — not signed in
--   order_not_found          — no order with this ID
--   not_owner                — order belongs to another user
--   order_not_pending        — order already paid/cancelled/etc.
--   payment_not_cod          — order is not a Cash-on-Delivery order
--   payment_not_pending      — payment exists but not pending
--   already_confirmed        — payment already succeeded (idempotent)
--
-- IDEMPOTENCY:
--   Calling twice for the same order returns ok:true with
--   code 'already_confirmed' and the existing transaction_id.
--   No side effects on the second call.
--
-- Rollback:
--   DROP FUNCTION IF EXISTS confirm_cod_payment(UUID);
-- ============================================================

CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_order      RECORD;
  v_payment    RECORD;
  v_txn_id     TEXT;
  v_is_cod     BOOLEAN;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  -- ─── Find and lock the order ──────────────────────────────
  SELECT id, user_id, status, total, payment_method
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Ownership check ─────────────────────────────────────
  -- Defense in depth: RLS already restricts orders to the
  -- owner, but this RPC is SECURITY DEFINER so it runs as the
  -- owner. We re-check user_id so a forged JWT or misconfigured
  -- RLS cannot confirm another user's order.
  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  -- ─── Verify the order is Cash on Delivery ────────────────
  -- The checkout stores the Flutter PaymentMethod.label string
  -- ("Cash on Delivery") in orders.payment_method. Match
  -- tolerantly so a future label change does not break COD.
  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── Idempotency: order already paid ─────────────────────
  -- If the order is already 'paid', a repeat confirmation is
  -- a no-op. Return the existing transaction_id.
  IF v_order.status = 'paid' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE order_id = p_order_id
        AND status = 'success'
      LIMIT 1;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  -- ─── Order must be pending ────────────────────────────────
  -- Any non-pending, non-paid status (cancelled, expired,
  -- shipped, etc.) cannot be confirmed.
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  -- ─── Find or create the COD payment row ───────────────────
  -- The checkout RPC (migration 013) creates the order but
  -- does NOT create a payment row. For Paymob, the Edge
  -- Function creates it. For COD, this RPC creates it here.
  -- Match on order_id + user_id + a COD-like method so a
  -- stray Paymob payment row is never reused for COD.
  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Create the COD payment row atomically. Store the method
    -- as 'cash_on_delivery' (lowercase convention, matches the
    -- paymob-initiate style of 'paymob_card').
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (p_order_id, v_user_id, 'cash_on_delivery', v_order.total, 'pending')
      RETURNING id, status INTO v_payment;
  END IF;

  -- ─── Payment already succeeded (idempotent) ──────────────
  IF v_payment.status = 'success' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE id = v_payment.id;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  -- ─── Payment must be pending ──────────────────────────────
  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ──────────────────
  -- Format: COD-{unix_timestamp}-{8_hex_chars}
  -- Guarantees uniqueness via the timestamp + random suffix.
  -- The payments.transaction_id UNIQUE constraint is the
  -- ultimate guard; on collision the transaction rolls back.
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- ─── Atomic transition: payment + order ───────────────────
  -- Guarded UPDATE: only flips a still-pending payment. A
  -- concurrent confirmation that won the race leaves this
  -- UPDATE matching 0 rows, and we read the current state.
  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    -- Another concurrent call won the race. Read the final state.
    SELECT status, transaction_id INTO v_payment
      FROM payments
      WHERE id = v_payment.id;

    IF v_payment.status = 'success' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_confirmed',
        'transaction_id', COALESCE(v_payment.transaction_id, '')
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- Promote the order to 'paid' ONLY if still pending. A
  -- duplicate confirmation cannot downgrade a 'paid',
  -- 'processing', 'shipped', or 'delivered' order.
  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id
  );
END;
$$;

-- Execute permission: the Flutter client calls this with the
-- authenticated user's JWT. The RPC verifies auth.uid() and
-- order ownership internally, so authenticated execute is safe.
-- Anonymous calls fail at the auth check inside the function.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 019_harden_rpc_and_payments_authorization.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 019: Harden RPC and payments authorization
--
-- SECURITY DEFICIT (authz hardening):
--   Three user-facing RPCs were executable by PUBLIC, allowing
--   anonymous (anon role) callers to invoke them. While each
--   function verifies auth.uid() internally, relying on
--   in-function checks alone is a defense-in-depth failure: a
--   future refactor or a PostgREST misconfiguration could
--   expose them. The least-privilege posture is to REVOKE from
--   PUBLIC and grant only to `authenticated`.
--
--   1. create_checkout_order (TEXT, JSONB, JSONB, TEXT)
--        Granted TO PUBLIC in migration 013 (line 249).
--   2. update_order_status (UUID, TEXT, TEXT)
--        Granted TO PUBLIC in migration 014 (line 188).
--        Migration 015's comment claims it "remains executable
--        by authenticated callers" but the live grant is TO
--        PUBLIC — this migration makes the grant match the
--        intended security model.
--   3. confirm_cod_payment (UUID)
--        Already restricted in migration 018 (lines 239-240);
--        re-asserted here for a single source of truth and
--        idempotency under re-run.
--
--   4. process_paymob_callback (TEXT, TEXT, INTEGER, TEXT, BOOLEAN)
--        Granted TO PUBLIC in migration 014 (line 410).
--        Restricted to service_role in migration 015; re-asserted
--        here so the final desired state is explicit and survives
--        any future re-grant to PUBLIC. Anonymous and authenticated
--        clients must never execute the callback directly — HMAC
--        verification happens in the Edge Function before this RPC.
--
--   5. payments_insert_own policy (migration 006, lines 35-38)
--        Allowed any authenticated user to INSERT a payment row
--        directly. Payments must only be created by:
--          * create_checkout_order / confirm_cod_payment RPCs
--            (SECURITY DEFINER, bypass RLS)
--          * the Paymob initiation Edge Function (service_role,
--            bypass RLS)
--          * service_role server-side logic (bypass RLS)
--        Direct client INSERT is removed. RLS is enabled on
--        payments (migration 006 line 28), so with no INSERT
--        policy the default-deny posture blocks client inserts.
--
-- IDEMPOTENCY:
--   REVOKE is a no-op when the privilege is absent.
--   GRANT EXECUTE is a no-op when the privilege is already held.
--   DROP POLICY IF EXISTS is a no-op when the policy is absent.
--   Safe to apply after migrations 001-018 and safe to re-run.
--
-- DOES NOT:
--   * modify application data
--   * drop tables
--   * delete existing migrations
--   * touch secrets / .env / auth / payments-config
--
-- ROLLBACK (staging only — do NOT roll back after production deploy):
--   GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT,JSONB,JSONB,TEXT) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION update_order_status(UUID,TEXT,TEXT) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN) TO PUBLIC;
--   CREATE POLICY "payments_insert_own" ON payments
--     FOR INSERT WITH CHECK (auth.uid() = user_id);
-- ============================================================

-- ─── 1. create_checkout_order: authenticated only ──────────
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- ─── 2. update_order_status: authenticated (admin-checked internally) ─
-- The RPC verifies profiles.is_admin inside (migration 014), so
-- authenticated execute is safe; non-admins are rejected at the
-- function body even though they can reach the entry point.
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, TEXT) TO authenticated;

-- ─── 3. confirm_cod_payment: authenticated only ─────────────
-- Already restricted in migration 018; re-asserted here so the
-- final desired state lives in one migration and survives re-runs.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- ─── 4. process_paymob_callback: service_role only ──────────
-- Revoke from every client-facing role, then grant only to the
-- service_role that the Edge Function uses after HMAC verification.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- ─── 5. Remove direct client INSERT on payments ─────────────
-- After this drop, an authenticated client has no INSERT policy
-- on payments. Because RLS is enabled on the table (migration
-- 006), the absence of an INSERT policy means default-deny: no
-- client row can be inserted. The only paths that create payment
-- rows are SECURITY DEFINER RPCs and the service_role Edge
-- Function, both of which bypass RLS.
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 020_fix_orders_fk.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 020: Fix FK violation on orders table
--
-- The create_checkout_order RPC inserts into orders with
-- user_id from auth.uid(). The orders table has a foreign
-- key constraint (user_id -> profiles(id) ON DELETE RESTRICT).
-- If a user exists in auth.users but has no profile row,
-- the order insert fails with a foreign key violation.
--
-- Fix: ensure a profile exists before inserting the order.
-- ============================================================

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
BEGIN
  -- Authentication
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Validate payment method
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- Validate items
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- Validate address
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- Idempotency: return existing order if key matches
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Validate items, read DB prices, check stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- Calculate shipping and total
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);
  v_total    := v_subtotal + v_shipping;
  v_expires_at := now() + interval '15 minutes';

  -- Ensure a profile exists before inserting the order.
  -- The handle_new_user() trigger should have created one,
  -- but users who signed up before the trigger or whose
  -- profile was deleted would hit a FK violation on
  -- orders.user_id -> profiles(id).
  INSERT INTO profiles (id, full_name, phone)
  VALUES (v_user_id, '', '')
  ON CONFLICT (id) DO NOTHING;

  -- Insert order (atomic with the rest)
  BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
      'expires_at', v_existing_expires,
      'idempotent', true
    );
  END;

  -- Insert order items + decrement stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- Clear the user's server-side cart
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- Return the canonical order data
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_checkout_order TO authenticated;

-- ────────────────────────────────────────────────────────────
-- MIGRATION: 021_fix_create_checkout_order.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 021: Fix OR type error in create_checkout_order
--
-- Migration 020 had a typo on line 67 of migration 020:
--   OR COALESCE(p_address->>'city', '') THEN
-- Missing the = '' comparison made PostgreSQL interpret the
-- COALESCE result (text) as an OR operand, causing:
--   "argument of OR must be type boolean, not type text"
--
-- Fix: recreate the function with the corrected condition.
-- ============================================================

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;
  v_governorate := p_address->>'city';
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;
    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true
      );
    END IF;
  END IF;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;
    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;
    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;
    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;
    v_subtotal := v_subtotal + (v_unit_price * v_quantity);
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);
  v_total    := v_subtotal + v_shipping;
  v_expires_at := now() + interval '15 minutes';
  INSERT INTO profiles (id, full_name, phone)
  VALUES (v_user_id, '', '')
  ON CONFLICT (id) DO NOTHING;
  BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
    )
    RETURNING id INTO v_order_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;
    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
      'expires_at', v_existing_expires,
      'idempotent', true
    );
  END;
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;
    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );
    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;
  DELETE FROM cart_items WHERE user_id = v_user_id;
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_checkout_order TO authenticated;

-- ────────────────────────────────────────────────────────────
-- MIGRATION: 022_repair_confirm_cod_payment.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 022: Repair confirm_cod_payment RPC
--
-- PROBLEM:
--   The Flutter client calls `confirm_cod_payment` when the
--   user selects Cash on Delivery. The on-disk migration 018
--   defined this RPC but was never applied to staging (staging
--   has a different file at slot 018: 018_low_stock_index_and_perf).
--   All COD checkout attempts fail with PostgREST "function not
--   found" error.
--
-- THIS MIGRATION:
--   Uses CREATE OR REPLACE to (re)define the function. Safe to
--   apply regardless of whether migration 018 was applied:
--     - If the function does not exist: creates it.
--     - If the function exists (from local 018): replaces it
--       with the identical logic.
--     - If staging has a different function at this signature:
--       replaces it.
--
--   Also re-asserts REVOKE/GRANT to guarantee the final
--   authorization state matches migrations 018 + 019, regardless
--   of which migrations were previously applied.
--
-- BEHAVIOR (matches approved migration 018):
--   1. Requires auth.uid() (authentication_required)
--   2. Finds and locks the order row (order_not_found)
--   3. Verifies order ownership (not_owner)
--   4. Verifies COD payment method via ILIKE (payment_not_cod)
--   5. Idempotent: if order already paid → already_confirmed
--   6. Order must be pending (order_not_pending)
--   7. Finds or auto-creates a COD payment row
--   8. Idempotent: if payment already success → already_confirmed
--   9. Payment must be pending (payment_not_pending / invalid_state)
--  10. Generates server-side transaction ID
--  11. Atomic: payment.status = 'success', order.status = 'paid'
--  12. Returns jsonb: { ok, code, transaction_id }
--
-- MISSING PAYMENT ROW:
--   The checkout RPC (migration 013) creates orders but does NOT
--   create payment rows for COD. This function auto-creates a
--   COD payment row when one does not exist. This is the approved
--   behavior (auto-create), not reject.
--
-- SECURITY:
--   SECURITY DEFINER with search_path = public, auth
--   REVOKE ALL FROM PUBLIC + anon; GRANT EXECUTE TO authenticated
--
-- IDEMPOTENCY:
--   Safe to re-run. REVOKE/GRANT are no-ops when already in the
--   desired state. CREATE OR REPLACE is idempotent.
--
-- DOES NOT:
--   * renumber or delete existing migrations
--   * rewrite applied migration history
--   * modify application data (aside from the target function)
--   * touch secrets / .env / auth / payments-config
--   * push to git
--   * apply to staging (human must run manually)
--
-- ROLLBACK:
--   DROP FUNCTION IF EXISTS confirm_cod_payment(UUID);
-- ============================================================

CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_order      RECORD;
  v_payment    RECORD;
  v_txn_id     TEXT;
  v_is_cod     BOOLEAN;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  -- ─── Find and lock the order ──────────────────────────────
  SELECT id, user_id, status, total, payment_method
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Ownership check ─────────────────────────────────────
  -- Defense in depth: RLS already restricts orders to the
  -- owner, but this RPC is SECURITY DEFINER so it runs as the
  -- function owner. We re-check user_id so a forged JWT or
  -- misconfigured RLS cannot confirm another user's order.
  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  -- ─── Verify the order is Cash on Delivery ────────────────
  -- The checkout stores the Flutter PaymentMethod.label string
  -- ("Cash on Delivery") in orders.payment_method. Match
  -- tolerantly so a future label change does not break COD.
  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── Idempotency: order already paid ─────────────────────
  -- If the order is already 'paid', a repeat confirmation is
  -- a no-op. Return the existing transaction_id.
  IF v_order.status = 'paid' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE order_id = p_order_id
        AND status = 'success'
      LIMIT 1;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  -- ─── Order must be pending ────────────────────────────────
  -- Any non-pending, non-paid status (cancelled, expired,
  -- shipped, etc.) cannot be confirmed.
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  -- ─── Find or create the COD payment row ───────────────────
  -- The checkout RPC (migration 013) creates the order but
  -- does NOT create a payment row. For Paymob, the Edge
  -- Function creates it. For COD, this RPC creates it here.
  -- Match on order_id + user_id + a COD-like method so a
  -- stray Paymob payment row is never reused for COD.
  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Create the COD payment row atomically. Store the method
    -- as 'cash_on_delivery' (lowercase convention, matches the
    -- paymob-initiate style of 'paymob_card').
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (p_order_id, v_user_id, 'cash_on_delivery', v_order.total, 'pending')
      RETURNING id, status INTO v_payment;
  END IF;

  -- ─── Payment already succeeded (idempotent) ──────────────
  IF v_payment.status = 'success' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE id = v_payment.id;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  -- ─── Payment must be pending ──────────────────────────────
  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ──────────────────
  -- Format: COD-{unix_timestamp}-{8_hex_chars}
  -- Guarantees uniqueness via the timestamp + random suffix.
  -- The payments.transaction_id UNIQUE constraint is the
  -- ultimate guard; on collision the transaction rolls back.
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- ─── Atomic transition: payment + order ───────────────────
  -- Guarded UPDATE: only flips a still-pending payment. A
  -- concurrent confirmation that won the race leaves this
  -- UPDATE matching 0 rows, and we read the current state.
  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    -- Another concurrent call won the race. Read the final state.
    SELECT status, transaction_id INTO v_payment
      FROM payments
      WHERE id = v_payment.id;

    IF v_payment.status = 'success' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_confirmed',
        'transaction_id', COALESCE(v_payment.transaction_id, '')
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- Promote the order to 'paid' ONLY if still pending. A
  -- duplicate confirmation cannot downgrade a 'paid',
  -- 'processing', 'shipped', or 'delivered' order.
  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id
  );
END;
$$;

-- ─── Authorization ─────────────────────────────────────────
-- REVOKE/GRANT are idempotent (no-op when already in desired
-- state). This guarantees the final authorization matches the
-- intended security model regardless of which migrations were
-- previously applied.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 024_hardening_rpcs_policies.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 024: Final hardening — RPCs + logging table policies
--
-- DEFICITS FIXED:
--
--   1. calculate_shipping_fee — EXECUTE privilege
--      No explicit GRANT was ever issued. By default PostgreSQL
--      grants EXECUTE to PUBLIC, meaning anonymous callers can
--      invoke it. While the function has no side effects beyond
--      reading shipping config, a client-callable RPC that
--      returns pricing data should not be reachable by anon.
--      FIX: REVOKE from PUBLIC, grant to authenticated. Add
--      input validation (non-null, non-negative subtotal,
--      non-empty governorate). Add safe search_path.
--
--   2. notifications — INSERT policy (migration 010)
--      The current policy "notifications_insert_service" uses
--      WITH CHECK (true), which allows ANY role (including anon
--      and authenticated) to insert notification rows directly.
--      Notifications are only created by the send-order-
--      notification Edge Function (service_role, bypasses RLS).
--      FIX: Drop the permissive INSERT policy. With RLS enabled
--      and no INSERT policy, default-deny blocks all client
--      inserts. Service-role (SECURITY DEFINER or bypass RLS)
--      is the only write path.
--
--   3. analytics_events — INSERT policy (migration 010)
--      The current policy "analytics_insert_service" uses
--      WITH CHECK (true), allowing any role to inject arbitrary
--      events. This is an abuse vector for spam or data
--      poisoning.
--      FIX: Replace with a narrow authenticated policy:
--        - user_id must match auth.uid()
--        - event name must be non-empty, max 100 chars
--        - properties JSONB must be ≤ 10 KB
--        - No column-level size bypass
--
--   4. error_logs — INSERT policy (migration 010)
--      Same issue as analytics_events. WITH CHECK (true) lets
--      any role inject arbitrary error rows.
--      FIX: Replace with a narrow authenticated policy:
--        - user_id must match auth.uid()
--        - message must be non-empty, max 500 chars
--        - stack_trace must be ≤ 50 KB (error traces can be
--          large but should not be unlimited)
--        - environment restricted to known values
--
-- IDEMPOTENCY:
--   All statements use IF EXISTS / IF NOT EXISTS / CREATE OR
--   REPLACE. Safe to re-run after partial application.
--
-- DOES NOT:
--   - modify application data
--   - drop tables
--   - touch secrets / .env / auth / payments-config
--   - push to git
--
-- ROLLBACK (staging only — do NOT roll back after production):
--   See 024_rollback_hardening.sql
-- ============================================================

BEGIN;

-- ─── 1. calculate_shipping_fee: harden ─────────────────────
-- Drop existing function (same signature) and recreate with
-- input validation, safe search_path, and restricted EXECUTE.
DROP FUNCTION IF EXISTS calculate_shipping_fee(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION calculate_shipping_fee(
  p_governorate TEXT,
  p_subtotal    INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold INTEGER;
  v_fee       INTEGER;
BEGIN
  -- ─── Input validation ────────────────────────────────────
  IF p_governorate IS NULL OR btrim(p_governorate) = '' THEN
    RAISE EXCEPTION 'Governorate is required';
  END IF;

  IF p_subtotal IS NULL OR p_subtotal < 0 THEN
    RAISE EXCEPTION 'Subtotal must be a non-negative integer';
  END IF;

  -- ─── Free-shipping threshold check ───────────────────────
  SELECT value::INTEGER INTO v_threshold
  FROM shipping_config WHERE key = 'free_shipping_threshold';

  IF v_threshold IS NULL THEN
    -- Defensive: if config row is missing, do not charge shipping.
    RETURN 0;
  END IF;

  IF p_subtotal >= v_threshold THEN
    RETURN 0;
  END IF;

  -- ─── Zone lookup ─────────────────────────────────────────
  SELECT sz.fee INTO v_fee
  FROM shipping_zones sz
  WHERE p_governorate = ANY(sz.governorates)
    AND sz.is_active = true
  LIMIT 1;

  -- ─── Fallback to default ─────────────────────────────────
  IF v_fee IS NULL THEN
    SELECT value::INTEGER INTO v_fee
    FROM shipping_config WHERE key = 'default_fee';

    -- Ultimate fallback if default_fee config is also missing.
    IF v_fee IS NULL THEN
      RETURN 0;
    END IF;
  END IF;

  RETURN v_fee;
END;
$$;

-- Restrict EXECUTE: authenticated only (called by other RPCs
-- and the Flutter client for display purposes).
REVOKE ALL ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) TO authenticated;


-- ─── 2. notifications: remove permissive INSERT policy ──────
-- Service-role Edge Functions bypass RLS, so the only INSERT
-- path is the send-order-notification Edge Function (service
-- role). Removing the policy means default-deny for all client
-- roles.
DROP POLICY IF EXISTS "notifications_insert_service" ON notifications;

-- Verify no INSERT policies remain (defense in depth check).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'notifications'
      AND cmd = 'INSERT'
  ) THEN
    RAISE EXCEPTION ' notifications仍有INSERT策略，安全检查失败';
  END IF;
END $$;


-- ─── 3. analytics_events: narrow authenticated INSERT policy ─
-- Drop the permissive policy first, then create the narrow one.
DROP POLICY IF EXISTS "analytics_insert_service" ON analytics_events;

CREATE POLICY "analytics_insert_narrow"
  ON analytics_events FOR INSERT
  WITH CHECK (
    -- Must be authenticated.
    auth.uid() IS NOT NULL
    -- user_id must match the caller.
    AND user_id = auth.uid()
    -- event name: non-empty, max 100 chars.
    AND event IS NOT NULL
    AND length(btrim(event)) > 0
    AND length(event) <= 100
    -- properties JSONB: must be ≤ 10 KB when serialized.
    AND pg_column_size(COALESCE(properties, '{}'::jsonb)) <= 10240
  );


-- ─── 4. error_logs: narrow authenticated INSERT policy ──────
-- Drop the permissive policy first, then create the narrow one.
DROP POLICY IF EXISTS "error_logs_insert_service" ON error_logs;

CREATE POLICY "error_logs_insert_narrow"
  ON error_logs FOR INSERT
  WITH CHECK (
    -- Must be authenticated.
    auth.uid() IS NOT NULL
    -- user_id must match the caller.
    AND user_id = auth.uid()
    -- message: non-empty, max 500 chars.
    AND message IS NOT NULL
    AND length(btrim(message)) > 0
    AND length(message) <= 500
    -- stack_trace: max 50 KB (large traces truncated by client).
    AND length(COALESCE(stack_trace, '')) <= 51200
    -- environment: restricted to known values.
    AND environment IN ('production', 'staging', 'development')
  );


-- ─── 5. Re-assert existing hardening (idempotent) ──────────
-- These are no-ops when already in the desired state. Included
-- so the final desired state is explicit in this migration.

-- process_paymob_callback: service_role only
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- confirm_cod_payment: authenticated only
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- create_checkout_order: authenticated only
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- update_order_status: authenticated (admin-checked internally)
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, TEXT) TO authenticated;

-- Stock functions: service_role only
REVOKE ALL ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;

-- Expire function: service_role only
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- get_order_details: authenticated only (owner/admin checked)
REVOKE ALL ON FUNCTION get_order_details(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_order_details(UUID) TO authenticated;

-- get_low_stock_products: authenticated (admin checked internally)
REVOKE ALL ON FUNCTION get_low_stock_products(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_low_stock_products(INTEGER) TO authenticated;

-- set_payment_provider_order_id: authenticated only
REVOKE ALL ON FUNCTION set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_payment_provider_order_id(UUID, TEXT) TO authenticated;


-- ─── 6. payments INSERT posture (defense in depth) ──────────
-- Ensure no INSERT policy exists on payments. Default-deny is
-- the structural guarantee that clients cannot create payment
-- rows directly.
-- Drop any existing INSERT policy for defense in depth.
DROP POLICY IF EXISTS "payments_insert_own" ON payments;


COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 025_race_safe_state_machine.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 025: Race-safe payment/order/stock state machine
--
-- PROBLEM:
--   A Paymob success callback may race with order expiry or
--   admin cancellation. The current process_paymob_callback
--   (014) only checks payment.status for idempotency. If
--   expiry fires first and sets payment.status='expired',
--   the callback's UPDATE silently no-ops (WHERE status='pending'
--   fails), but the function still returns ok:true, code:success.
--   This misreports the outcome and leaves the client confused.
--
-- FIXES:
--   1. process_paymob_callback: check BOTH order.status and
--      payment.status before applying any transition. If the
--      order is no longer 'pending' OR the payment is no longer
--      'pending', return already_processed immediately.
--
--   2. expire_pending_order: check payment.status before
--      cancelling. If payment is already 'success', return
--      already_paid (do NOT cancel a paid order).
--
--   3. state_transitions audit table: record every state
--      transition with caller, timestamp, and before/after
--      values for full auditability.
--
--   4. confirm_cod_payment: add dual-guard (order + payment)
--      identical to the callback path.
--
-- INVARIANTS ENFORCED:
--   I1: Every terminal state is coherent across payments, orders, stock.
--   I2: Lock canonical rows in deterministic order (payment → order).
--   I3: Permit success only while order AND payment are eligible.
--   I4: Reject late success after expiry/cancel without marking payment.
--   I5: Restore stock exactly once via stock_restorations ledger.
--   I6: Duplicate callbacks are safe no-ops.
--   I7: All transitions are auditable via state_transitions table.
--
-- IDEMPOTENCY:
--   All CREATE OR REPLACE. Safe to re-run after partial application.
--
-- SAFETY:
--   - Does NOT push to git.
--   - Does NOT deploy without approval.
--   - Does NOT print secrets.
--   - Does NOT allow client-side authoritative payment success.
--
-- ROLLBACK (staging only):
--   DROP TABLE IF EXISTS state_transitions;
--   -- Then restore process_paymob_callback, expire_pending_order,
--   -- confirm_cod_payment from migration 014/015/022.
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. STATE TRANSITIONS AUDIT TABLE
-- ═══════════════════════════════════════════════════════════
-- Records every state mutation for orders and payments.
-- Append-only. Never deleted. Enables forensic audit of
-- race conditions and replay attacks.

CREATE TABLE IF NOT EXISTS state_transitions (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type   TEXT NOT NULL CHECK (entity_type IN ('order', 'payment')),
  entity_id     UUID NOT NULL,
  old_status    TEXT,
  new_status    TEXT NOT NULL,
  caller        TEXT NOT NULL DEFAULT 'system',
  reason        TEXT,
  metadata      JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast lookup by entity for audit queries.
CREATE INDEX IF NOT EXISTS idx_state_transitions_entity
  ON state_transitions (entity_type, entity_id, created_at DESC);

-- Fast lookup by caller for forensic analysis.
CREATE INDEX IF NOT EXISTS idx_state_transitions_caller
  ON state_transitions (caller, created_at DESC);

-- ═══════════════════════════════════════════════════════════
-- 2. AUDIT HELPER FUNCTION
-- ═══════════════════════════════════════════════════════════
-- Inserts an audit record. Called from within RPCs.
-- SECURITY DEFINER so it can write even when RLS is active.

CREATE OR REPLACE FUNCTION audit_transition(
  p_entity_type TEXT,
  p_entity_id   UUID,
  p_old_status  TEXT,
  p_new_status  TEXT,
  p_caller      TEXT,
  p_reason      TEXT,
  p_metadata    JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO state_transitions (
    entity_type, entity_id, old_status, new_status,
    caller, reason, metadata
  ) VALUES (
    p_entity_type, p_entity_id, p_old_status, p_new_status,
    p_caller, p_reason, p_metadata
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 3. HARDENED process_paymob_callback
-- ═══════════════════════════════════════════════════════════
-- FIX: The idempotency guard now checks BOTH order.status
-- and payment.status before applying any mutation. This
-- prevents the race where expiry cancels the order between
-- our status check and our UPDATE.

CREATE OR REPLACE FUNCTION process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id   TEXT,
  p_amount_cents    INTEGER,
  p_currency        TEXT,
  p_success         BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment        RECORD;
  v_order          RECORD;
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Locate the internal payment by provider order id ──
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  -- ─── Lock the order row and read canonical total ───────
  SELECT id, status, total, expires_at
    INTO v_order
    FROM orders
    WHERE id = v_payment.order_id
    FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  v_order_total := v_order.total;

  -- ─── Validate amount/currency ──────────────────────────
  IF p_amount_cents IS NULL OR p_amount_cents <> v_order_total THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'amount_mismatch',
      'expected', v_order_total,
      'received', p_amount_cents
    );
  END IF;

  IF p_currency IS NOT NULL AND p_currency <> v_order_currency THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'currency_mismatch',
      'expected', v_order_currency,
      'received', p_currency
    );
  END IF;

  -- ─── RACE GUARD: check BOTH payment AND order status ───
  -- I3/I4: If either is already in a terminal state, this
  -- callback is a late arrival. The outcome is already
  -- determined — return it without mutation.
  --
  -- This is the critical fix. The old code only checked
  -- payment.status IN ('success','failed'). If expiry set
  -- payment.status='expired' first, the UPDATE silently
  -- no-oped but the function returned ok:true, code:success.

  -- Payment already terminal → no-op.
  IF v_payment.status IN ('success', 'failed', 'expired', 'cancelled', 'refunded') THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- Order already terminal → no-op (do NOT mark payment success
  -- for an order that was cancelled/expired).
  IF v_order.status IN ('paid', 'processing', 'shipped', 'delivered',
                         'cancelled', 'refunded') THEN
    -- Audit: we rejected a late callback.
    PERFORM audit_transition(
      'payment', v_payment.id,
      v_payment.status, v_payment.status,
      'paymob-callback',
      'late_callback_rejected',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'order_status', v_order.status::text,
        'success_intended', p_success
      )
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- ─── Apply the terminal transition ─────────────────────
  -- Both order AND payment are still 'pending'. Safe to transition.

  IF p_success THEN
    -- Audit: order transition.
    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'paid',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

    -- Audit: payment transition.
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'success',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

    UPDATE payments
      SET status = 'success',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'paid'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'success',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  ELSE
    -- Audit: payment failure.
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'failed',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

    -- Audit: order cancellation.
    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'cancelled',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

    UPDATE payments
      SET status = 'failed',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'cancelled'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    -- Stock restoration: exactly once via restored flag + trigger.
    UPDATE order_items
      SET restored = true
      WHERE order_id = v_payment.order_id
        AND restored = false;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'failed',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Preserve privilege matrix from migration 024.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;


-- ═══════════════════════════════════════════════════════════
-- 4. HARDENED expire_pending_order
-- ═══════════════════════════════════════════════════════════
-- FIX: Before cancelling, check if any payment for this order
-- is already 'success'. If so, the user paid — do NOT cancel.
-- This prevents the race where callback success arrives
-- slightly after the expiry query but before the lock.

CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order       RECORD;
  v_has_success BOOLEAN;
BEGIN
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'code', 'already_terminal');
  END IF;

  IF v_order.expires_at IS NULL OR v_order.expires_at >= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_expired');
  END IF;

  -- ─── RACE GUARD: check if payment already succeeded ─────
  -- If a success callback already landed (even if it hasn't
  -- promoted the order yet due to transaction ordering), we
  -- must NOT cancel. Check payment status under the same
  -- transaction scope.
  SELECT EXISTS(
    SELECT 1 FROM payments
    WHERE order_id = p_order_id
      AND status = 'success'
  ) INTO v_has_success;

  IF v_has_success THEN
    PERFORM audit_transition(
      'order', p_order_id,
      'pending', 'pending',
      'expire-worker',
      'expiry_aborted_payment_already_succeeded',
      '{}'::jsonb
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_paid',
      'order_id', p_order_id
    );
  END IF;

  -- ─── Apply expiry ──────────────────────────────────────
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'cancelled',
    'expire-worker',
    'order_expired',
    jsonb_build_object('expires_at', v_order.expires_at)
  );

  PERFORM audit_transition(
    'payment', p_order_id,
    'pending', 'expired',
    'expire-worker',
    'order_expired',
    '{}'::jsonb
  );

  UPDATE orders
    SET status = 'cancelled'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  UPDATE payments
    SET status = 'expired',
        updated_at = now()
    WHERE order_id = p_order_id
      AND status = 'pending';

  -- Stock restoration: exactly once via restored flag + trigger.
  UPDATE order_items
    SET restored = true
    WHERE order_id = p_order_id
      AND restored = false;

  RETURN jsonb_build_object('ok', true, 'code', 'expired');
END;
$$;

-- Preserve privilege matrix.
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;


-- ═══════════════════════════════════════════════════════════
-- 5. HARDENED confirm_cod_payment
-- ═══════════════════════════════════════════════════════════
-- FIX: Add dual-guard (order + payment) identical to the
-- callback path. If order is no longer pending or payment
-- is no longer pending, return already_confirmed.

CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_order      RECORD;
  v_payment    RECORD;
  v_txn_id     TEXT;
  v_is_cod     BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  SELECT id, user_id, status, total, payment_method
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── RACE GUARD: order already terminal ────────────────
  IF v_order.status = 'paid' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE order_id = p_order_id
        AND status = 'success'
      LIMIT 1;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (p_order_id, v_user_id, 'cash_on_delivery', v_order.total, 'pending')
      RETURNING id, status INTO v_payment;
  END IF;

  -- ─── RACE GUARD: payment already terminal ──────────────
  IF v_payment.status = 'success' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE id = v_payment.id;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ───────────────
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- Audit: payment transition.
  PERFORM audit_transition(
    'payment', v_payment.id,
    'pending', 'success',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    SELECT status, transaction_id INTO v_payment
      FROM payments
      WHERE id = v_payment.id;

    IF v_payment.status = 'success' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_confirmed',
        'transaction_id', COALESCE(v_payment.transaction_id, '')
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- Audit: order transition.
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'paid',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id
  );
END;
$$;

-- Preserve privilege matrix.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════
-- 6. AUDIT TRIGGER ON orders.status
-- ═══════════════════════════════════════════════════════════
-- Automatic audit trail for order status changes made by
-- any code path (not just the RPCs above). Defense in depth.

CREATE OR REPLACE FUNCTION audit_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO state_transitions (
      entity_type, entity_id, old_status, new_status,
      caller, reason, metadata
    ) VALUES (
      'order', NEW.id,
      OLD.status::text, NEW.status::text,
      current_user,
      'trigger_audit',
      jsonb_build_object(
        'function',TG_OP,
        'table', TG_TABLE_NAME
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_order_status ON orders;
CREATE TRIGGER trg_audit_order_status
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION audit_order_status_change();


-- ═══════════════════════════════════════════════════════════
-- 7. AUDIT TRIGGER ON payments.status
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION audit_payment_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO state_transitions (
      entity_type, entity_id, old_status, new_status,
      caller, reason, metadata
    ) VALUES (
      'payment', NEW.id,
      OLD.status, NEW.status,
      current_user,
      'trigger_audit',
      jsonb_build_object(
        'function', TG_OP,
        'table', TG_TABLE_NAME
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_payment_status ON payments;
CREATE TRIGGER trg_audit_payment_status
  AFTER UPDATE OF status ON payments
  FOR EACH ROW
  EXECUTE FUNCTION audit_payment_status_change();


COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 026_forward_repair_confirm_cod_payment_and_grants.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 026: Forward repair — confirm_cod_payment + grants
--
-- PROBLEM:
--   Migration 018/022/025 defined confirm_cod_payment with
--   auto-create behavior for missing COD payment rows. The
--   approved Decision 2 changes this to reject with
--   payment_not_found. However, create_checkout_order (013)
--   does NOT create a payment row for COD orders. If we
--   reject without creating the payment row first, valid
--   COD orders will always fail.
--
-- FIX:
--   1. Update create_checkout_order to create a pending COD
--      payment row when payment_method is COD.
--   2. Update confirm_cod_payment to reject payment_not_found
--      when no valid pending COD payment row exists.
--   3. Re-assert all privilege grants for consistency.
--
-- APPROVED BEHAVIOR (Decision 2):
--   confirm_cod_payment returns:
--     payment_not_found  — no valid pending COD payment row
--     confirmed          — successful confirmation
--     already_confirmed  — idempotent re-confirmation
--
-- SAFETY:
--   - All CREATE OR REPLACE (idempotent)
--   - Does NOT renumber applied migrations
--   - Does NOT delete applied migration history
--   - Does NOT push to git
--   - Does NOT apply to staging (human must run manually)
--
-- ROLLBACK (staging only):
--   Restore create_checkout_order from migration 013.
--   Restore confirm_cod_payment from migration 025.
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. UPDATED create_checkout_order
-- ═══════════════════════════════════════════════════════════
-- After creating the order, if payment_method is COD, also
-- create a pending COD payment row. This ensures that
-- confirm_cod_payment can find a valid pending payment row
-- and does not need to auto-create one.

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
  v_is_cod       BOOLEAN;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ─── Validate payment method ─────────────────────────────
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- ─── Validate items ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- ─── Validate address ────────────────────────────────────
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- ─── Idempotency: return existing order if key matches ───
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true
      );
    END IF;
  END IF;

  -- ─── Validate items, read DB prices, check stock ────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- Look up variant and product in one query
    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    -- Collect validated item for later insert
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- ─── Calculate shipping from shipping-zone logic ────────
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);
  v_total    := v_subtotal + v_shipping;

   -- ─── Compute expiry ──────────────────────────────────────
   v_expires_at := now() + interval '15 minutes';

   -- ─── Ensure a profile exists ──────────────────────────
   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   -- ─── Insert order (atomic with the rest) ─────────────────
   BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
      'expires_at', v_existing_expires,
      'idempotent', true
    );
  END;

  -- ─── Insert order items + decrement stock ────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- ─── Clear the user's server-side cart ──────────────────
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- ═══════════════════════════════════════════════════════
  -- NEW: Create pending COD payment row for COD orders
  -- ═══════════════════════════════════════════════════════
  -- Decision 2 requires confirm_cod_payment to reject
  -- payment_not_found. For COD orders, we must create a
  -- pending payment row here so confirm_cod_payment can
  -- find and confirm it later.
  v_is_cod := p_payment_method ILIKE '%cash%'
           OR p_payment_method ILIKE '%cod%';

  IF v_is_cod THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (v_order_id, v_user_id, 'cash_on_delivery', v_total, 'pending');
  END IF;

  -- ─── Return the canonical order data ─────────────────────
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 2. UPDATED confirm_cod_payment
-- ═══════════════════════════════════════════════════════════
-- Decision 2: reject with payment_not_found when no valid
-- pending COD payment row exists. No auto-create.

CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_order      RECORD;
  v_payment    RECORD;
  v_txn_id     TEXT;
  v_is_cod     BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  SELECT id, user_id, status, total, payment_method
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── RACE GUARD: order already terminal ────────────────
  IF v_order.status = 'paid' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE order_id = p_order_id
        AND status = 'success'
      LIMIT 1;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  -- ═══════════════════════════════════════════════════════
  -- Decision 2: REJECT payment_not_found (no auto-create)
  -- ═══════════════════════════════════════════════════════
  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_found'
    );
  END IF;

  -- ─── RACE GUARD: payment already terminal ──────────────
  IF v_payment.status = 'success' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE id = v_payment.id;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ───────────────
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- Audit: payment transition.
  PERFORM audit_transition(
    'payment', v_payment.id,
    'pending', 'success',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    SELECT status, transaction_id INTO v_payment
      FROM payments
      WHERE id = v_payment.id;

    IF v_payment.status = 'success' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_confirmed',
        'transaction_id', COALESCE(v_payment.transaction_id, '')
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- Audit: order transition.
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'paid',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 3. PRIVILEGE GRANTS
-- ═══════════════════════════════════════════════════════════
-- Re-assert the complete privilege matrix. All REVOKE/GRANT
-- are idempotent (no-op when already in desired state).

-- create_checkout_order: authenticated only
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- confirm_cod_payment: authenticated only
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- process_paymob_callback: service_role only
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- expire_pending_order: service_role only
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- payments_insert_own policy: removed (defense in depth)
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 027_add_payments_insert_policy.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 027: Add payments INSERT policy for Edge Functions
--
-- PROBLEM:
--   Migration 019 removed payments_insert_own policy for defense
--   in depth. However, the paymob-initiate Edge Function uses the
--   user's JWT (not service_role) and needs to INSERT payment rows.
--   Without an INSERT policy, the Edge Function fails with:
--   "failed to create payment record"
--
-- FIX:
--   Add a narrow INSERT policy that allows authenticated users
--   to insert payment rows for their own orders only.
--
-- SECURITY:
--   - Only authenticated users can insert
--   - user_id must match auth.uid()
--   - order_id must reference an order owned by the user
--   - method must be non-empty
--   - amount must be positive
--
-- IDEMPOTENCY:
--   DROP POLICY IF EXISTS + CREATE POLICY IF NOT EXISTS
--
-- ROLLBACK (staging only):
--   DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON payments;
-- ============================================================

BEGIN;

-- Drop any existing INSERT policy to ensure clean state
DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON payments;

-- Create narrow INSERT policy for authenticated users
CREATE POLICY "payments_insert_authenticated_own"
  ON payments FOR INSERT
  TO authenticated
  WITH CHECK (
    -- user_id must match the authenticated user
    user_id = auth.uid()
    -- order_id must reference an order owned by this user
    AND order_id IN (
      SELECT id FROM orders
      WHERE user_id = auth.uid()
    )
    -- method must be non-empty
    AND method IS NOT NULL
    AND length(method) > 0
    -- amount must be positive
    AND amount > 0
  );

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 028_reclose_payments_insert_policy.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 028: Re-close direct payment INSERT after migration 027
--
-- Migration 027 accidentally reopened authenticated direct INSERT on
-- payments so paymob-initiate could persist a row through the caller JWT.
-- That contradicts the approved payment boundary: payment rows are created
-- only by SECURITY DEFINER RPCs or trusted service-role Edge Functions.
--
-- The paymob-initiate function is repaired in the same candidate to use a
-- service-role client only for its server-generated payment INSERT. Its
-- caller-scoped client remains responsible for authentication, ownership
-- reads, and the ownership-checked provider-order RPC.
--
-- Forward-only and idempotent. This file is repository evidence only until
-- a separately approved staging migration run is performed.
-- ============================================================

BEGIN;

DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON public.payments;
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 029_drop_profiles_update_own.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 029: drop redundant profiles_update_own that defeats is_admin guard (RLS-ESC-001)
-- See STATE.md:27-38 and audit report for context
--
-- Two permissive UPDATE policies on profiles existed:
--   - profiles_update_own (002_rls_policies.sql:32, USING auth.uid()=id, no WITH CHECK)
--   - profiles_update_own_safe (003_auth_profiles_and_hardening.sql:88, WITH CHECK is_admin guard)
-- Permissive OR + null WITH CHECK falls back to USING, so any auth user could
-- UPDATE is_admin=true. This migration drops the old policy.
--
-- Local docker variant `users can update own profile` (with_check auth.uid()=id)
-- is also permissive and must be replaced. This migration is idempotent
-- and handles all known names, then recreates the single safe policy.
--
-- Forward-only, idempotent. Human review required before supabase db push.
-- ============================================================

-- Drop all known variants of the permissive UPDATE policy
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_safe" ON public.profiles;

-- Recreate the single safe policy: only allow is_admin to stay as it was
CREATE POLICY "profiles_update_own_safe"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
  );


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 030_batch_checkout_variants.sql
-- ────────────────────────────────────────────────────────────
-- 030: batch index for checkout variants (UNNEST batching TODO from audit)
CREATE INDEX IF NOT EXISTS idx_product_variants_lookup ON public.product_variants (product_id, size, color);
-- Note: 013 loop remains correct; UNNEST batching would require rewriting the RPC to SELECT ... FROM jsonb_to_recordset(p_items) JOIN product_variants ON (product_id,size,color) FOR UPDATE — deferred to post-launch as safe optimization.


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 031_realtime_and_cron_fix.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 031: realtime publication fix + pg_cron schedules (T0)
--
-- Fixes staging gap where payments (and support_messages when
-- present) were not in supabase_realtime publication, so
-- PaymobPaymentService.watchPaymentStatus realtime was dead.
-- Also schedules pg_cron jobs for expiry/rollups/retention.
--
-- Idempotent: safe to re-run. Extensions guarded with
-- IF NOT EXISTS. Publication ADD guarded via pg_publication_tables.
-- Cron jobs use unschedule-if-exists then schedule pattern.
-- ============================================================

-- Extensions (safe if already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net; -- retained for send-order-notification via pg_net.http_post; remove if trigger migrates to external scheduler
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Realtime publication fix: payments
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'payments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
  END IF;
END $$;
ALTER TABLE public.payments REPLICA IDENTITY FULL;

-- Realtime publication fix: support_messages (table may not exist yet — T4)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'support_messages'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = 'support_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'support_messages'
  ) THEN
    -- Use dynamic SQL to avoid error if table absent at parse time
    EXECUTE 'ALTER TABLE public.support_messages REPLICA IDENTITY FULL';
  END IF;
END $$;

-- ── Batch expiry wrapper (fixes zero-arg expire_pending_order call) ──
-- expire_pending_order(UUID) requires an order id; pg_cron must call
-- a zero-arg wrapper that scans for expired pending orders.
CREATE OR REPLACE FUNCTION public.batch_expire_pending_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.expire_pending_order(id)
  FROM public.orders
  WHERE status = 'pending'
    AND expires_at < now();
END;
$$;

REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM anon;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO service_role;

-- pg_cron schedules (idempotent: unschedule if exists then schedule)

-- cancel-expired-every-5m: every 5 minutes, expire pending orders via batch wrapper
SELECT cron.unschedule('cancel-expired-every-5m')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cancel-expired-every-5m');
SELECT cron.schedule('cancel-expired-every-5m', '*/5 * * * *', $$SELECT public.batch_expire_pending_orders()$$);

-- analytics rollup daily at 03:00 (guarded: matview may not exist yet — T2)
SELECT cron.unschedule('analytics-rollup-daily')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-rollup-daily');
SELECT cron.schedule('analytics-rollup-daily', '0 3 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname='analytics_daily') THEN EXECUTE 'REFRESH MATERIALIZED VIEW analytics_daily'; END IF; END $do$ $cron$);

-- audit retention 90d at 04:00 (guarded: audit_logs does not exist — audit is state_transitions; guard keeps cron valid)
SELECT cron.unschedule('audit-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'audit-retention-90d');
SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='audit_logs') THEN DELETE FROM public.audit_logs WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);

-- analytics retention 90d at 04:00 (guarded for idempotency; analytics_events exists per 010)
SELECT cron.unschedule('analytics-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-retention-90d');
SELECT cron.schedule('analytics-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='analytics_events') THEN DELETE FROM public.analytics_events WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 032_flash_sales_and_product_images.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 032: flash_sales + product_images hardening (T1)
--
-- Adds flash_sales table for time-boxed discounts (replaces
-- home_page.dart placeholder), hardens product_images ordering
-- index and RLS, and tightens storage.objects policies for
-- the product-images bucket: public read, admin-only
-- insert/delete with prefix guard.
--
-- Idempotent: safe to re-run. Table/index guards use
-- IF NOT EXISTS. Policies use DROP IF EXISTS before CREATE.
-- Storage bucket insert is ON CONFLICT DO NOTHING.
-- ============================================================

-- Ensure pgcrypto for gen_random_uuid() (present via uuid-ossp but guard)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Ensure product-images bucket exists (idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- ── flash_sales table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS flash_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  discount_pct INT NOT NULL CHECK (discount_pct BETWEEN 1 AND 90),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL CHECK (ends_at > starts_at),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Keep updated_at fresh (reuse existing function from 001)
DROP TRIGGER IF EXISTS set_flash_sales_updated_at ON flash_sales;
CREATE TRIGGER set_flash_sales_updated_at
  BEFORE UPDATE ON flash_sales
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Partial index for active window scan (idempotent)
CREATE INDEX IF NOT EXISTS flash_sales_active_window ON flash_sales (ends_at) WHERE is_active;

-- RLS: only active window visible to anon/authenticated; writes via admin RPCs only
ALTER TABLE flash_sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS flash_sales_select_active ON flash_sales;
CREATE POLICY flash_sales_select_active
  ON flash_sales FOR SELECT
  USING (is_active AND now() BETWEEN starts_at AND ends_at);

-- ── product_images hardening ─────────────────────────────────
-- Ensure index for ordered fetch (product_id, sort_order)
CREATE INDEX IF NOT EXISTS product_images_product_sort ON product_images (product_id, sort_order);

ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

-- Public read for product_images (allow browsing without auth)
DROP POLICY IF EXISTS product_images_select_public ON product_images;
DROP POLICY IF EXISTS images_select_public ON product_images;
CREATE POLICY product_images_select_public
  ON product_images FOR SELECT
  USING (true);

-- ── storage.objects tightening for product-images bucket ─────
-- Drop legacy permissive admin ALL policy from 005 (and any alias)
DROP POLICY IF EXISTS "product_images_admin_all" ON storage.objects;
DROP POLICY IF EXISTS "admin-manage" ON storage.objects;
DROP POLICY IF EXISTS "product_images_select_public" ON storage.objects;
DROP POLICY IF EXISTS "product-images public read" ON storage.objects;
DROP POLICY IF EXISTS "product-images admin insert" ON storage.objects;
DROP POLICY IF EXISTS "product-images admin delete" ON storage.objects;

-- Public read for product-images bucket
CREATE POLICY "product-images public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- Admin-only insert with prefix guard (product-images/{productId}/...)
CREATE POLICY "product-images admin insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
    AND (
      (storage.foldername(name))[1] = 'product-images'
      OR name LIKE 'product-images/%'
    )
  );

-- Admin-only delete
CREATE POLICY "product-images admin delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'product-images'
    AND (SELECT is_admin FROM profiles WHERE id = auth.uid()) = true
  );


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 033_admin_catalog_rpcs.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 033: admin catalog RPCs + flash_sales read (T1)
--
-- Adds assert_admin() helper + admin_upsert_product,
-- admin_upsert_variant, admin_set_product_images, and
-- get_active_flash_sales for admin catalog ops and
-- flash sale window reads.
--
-- Idempotent: CREATE OR REPLACE for all functions.
-- Security: SECURITY DEFINER SET search_path=public,pg_temp
-- Grants: REVOKE FROM PUBLIC,anon; GRANT TO authenticated
--         (get_active_flash_sales also GRANT TO anon).
-- ============================================================

CREATE OR REPLACE FUNCTION assert_admin() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid() AND is_admin=true) THEN
    RAISE EXCEPTION 'not_admin' USING ERRCODE='42501';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION assert_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION assert_admin() TO authenticated;

CREATE OR REPLACE FUNCTION admin_upsert_product(
  p_id UUID, p_name TEXT, p_slug TEXT, p_description TEXT, p_composition TEXT,
  p_category_id UUID, p_base_price NUMERIC, p_is_active BOOL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_id UUID;
BEGIN
  PERFORM assert_admin();
  IF p_id IS NULL THEN
    INSERT INTO products (name, slug, description, composition, category_id, base_price, is_active)
    VALUES (p_name, p_slug, p_description, p_composition, p_category_id, p_base_price, p_is_active)
    RETURNING id INTO v_id;
  ELSE
    UPDATE products SET name=p_name, slug=p_slug, description=p_description, composition=p_composition,
      category_id=p_category_id, base_price=p_base_price, is_active=p_is_active, updated_at=now()
    WHERE id=p_id RETURNING id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'product_not_found' USING ERRCODE='P0002'; END IF;
  END IF;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION admin_upsert_product(UUID,TEXT,TEXT,TEXT,TEXT,UUID,NUMERIC,BOOL) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_upsert_product(UUID,TEXT,TEXT,TEXT,TEXT,UUID,NUMERIC,BOOL) TO authenticated;

CREATE OR REPLACE FUNCTION admin_upsert_variant(
  p_product_id UUID, p_size TEXT, p_color TEXT, p_stock INT, p_price_override NUMERIC
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_id UUID;
BEGIN
  PERFORM assert_admin();
  IF NOT EXISTS (SELECT 1 FROM products WHERE id=p_product_id) THEN RAISE EXCEPTION 'product_not_found' USING ERRCODE='P0002'; END IF;
  INSERT INTO product_variants (product_id, size, color, stock, price_override)
  VALUES (p_product_id, p_size, p_color, p_stock, p_price_override)
  ON CONFLICT (product_id, size, color) DO UPDATE SET stock=EXCLUDED.stock, price_override=EXCLUDED.price_override
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION admin_upsert_variant(UUID,TEXT,TEXT,INT,NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_upsert_variant(UUID,TEXT,TEXT,INT,NUMERIC) TO authenticated;

CREATE OR REPLACE FUNCTION admin_set_product_images(p_product_id UUID, p_paths TEXT[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  PERFORM assert_admin();
  IF NOT EXISTS (SELECT 1 FROM products WHERE id=p_product_id) THEN RAISE EXCEPTION 'product_not_found' USING ERRCODE='P0002'; END IF;
  -- prefix guard
  IF EXISTS (SELECT 1 FROM unnest(p_paths) p WHERE p NOT LIKE 'product-images/' || p_product_id || '/%') THEN
    RAISE EXCEPTION 'invalid_path' USING ERRCODE='22000';
  END IF;
  DELETE FROM product_images WHERE product_id=p_product_id;
  INSERT INTO product_images (product_id, storage_path, sort_order)
  SELECT p_product_id, p, ordinality-1 FROM unnest(p_paths) WITH ORDINALITY AS t(p, ordinality);
END $$;
REVOKE EXECUTE ON FUNCTION admin_set_product_images(UUID,TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_set_product_images(UUID,TEXT[]) TO authenticated;

CREATE OR REPLACE FUNCTION get_active_flash_sales() RETURNS SETOF flash_sales
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
  SELECT * FROM flash_sales WHERE is_active AND now() BETWEEN starts_at AND ends_at ORDER BY ends_at ASC;
$$;
REVOKE EXECUTE ON FUNCTION get_active_flash_sales() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_active_flash_sales() TO anon, authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 034_lock_audit_trail.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- Migration 034: lock state transitions audit trail
-- ═══════════════════════════════════════════════════════════
-- AUDIT-2026-08-24 HIGH-1:
--   * state_transitions had no RLS and no policies. Under Supabase
--     default grants, any client could read the full forensic trail
--     (incl. Paymob txn ids in metadata) and insert/update/delete rows.
--   * audit_transition() was SECURITY DEFINER with default PUBLIC
--     execute, allowing forged audit rows via PostgREST.
--
-- Fix:
--   1. Enable RLS; single admin-only SELECT policy (pattern from 032).
--   2. Grant-tighten the table: authenticated gets SELECT (filtered by
--      the policy); anon gets nothing. Writes stay service_role-only.
--   3. Revoke EXECUTE on audit_transition from PUBLIC/anon/authenticated.
--      Internal callers are SECURITY DEFINER functions running as the
--      owner, so they are unaffected by EXECUTE revokes.
-- Idempotent: safe to re-run.

-- ── 1. Table hardening ─────────────────────────────────────

ALTER TABLE public.state_transitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS state_transitions_select_admin
  ON public.state_transitions;

CREATE POLICY state_transitions_select_admin
  ON public.state_transitions
  FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);

REVOKE ALL ON public.state_transitions FROM anon;
REVOKE ALL ON public.state_transitions FROM authenticated;
GRANT SELECT ON public.state_transitions TO authenticated;
-- service_role bypasses RLS and retains its default grants: untouched.

-- ── 2. Helper function hardening ───────────────────────────

REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM anon;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 035_payment_initiation_and_expiry_hardening.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- 035: Payment initiation + expiry hardening
-- ============================================================
-- Closes four audit findings in the payment path:
--
--   P0-1  Non-atomic initiation. The Edge Function used a
--         read-then-insert sequence, so two concurrent requests
--         could each create a pending payment row and each
--         register a distinct Paymob provider order.
--
--   P0-2  Provider-order duplication. A retry could create a
--         second provider order for the same internal payment.
--
--   P0-3  batch_expire_pending_orders() was executable by
--         `authenticated`, letting any signed-in caller expire
--         every pending order in the system.
--
--   P1    Inconsistent lock ordering. process_paymob_callback
--         locked the payment row before the order row while
--         expire_pending_order locked the order first. That
--         inversion can deadlock against a concurrent expiry.
--
-- Forward-only. Idempotent where PostgreSQL allows it.
-- NOT applied to any remote project by this change.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Provider-order claim lease
-- ────────────────────────────────────────────────────────────
-- Records the moment a caller took responsibility for creating
-- the Paymob provider order. A crashed request leaves a stale
-- claim that expires on a bounded lease, so initiation can never
-- remain permanently claimable after a crashed initiation. Because
-- provider submission may have succeeded before a timeout, claims are
-- intentionally retained until provider-order persistence or manual
-- reconciliation.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_claimed_at TIMESTAMPTZ;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_phase TEXT NOT NULL DEFAULT 'none';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_claim_token UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'payments_paymob_initiation_phase_check'
      AND conrelid = 'public.payments'::regclass
  ) THEN
    ALTER TABLE payments
      ADD CONSTRAINT payments_paymob_initiation_phase_check
      CHECK (paymob_initiation_phase IN (
        'none', 'pre_provider', 'provider_submitted', 'provider_persisted'
      ));
  END IF;
END $$;

-- Supports the pending-card lookup in the claim RPC.
CREATE INDEX IF NOT EXISTS idx_payments_paymob_initiation_claim_token
  ON payments (paymob_initiation_claim_token)
  WHERE method = 'paymob_card' AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_payments_paymob_initiation_claimed_at
  ON payments (paymob_initiation_claimed_at)
  WHERE method = 'paymob_card' AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_payments_pending_card_claim
  ON payments (order_id)
  WHERE method = 'paymob_card' AND status = 'pending';

-- ────────────────────────────────────────────────────────────
-- 2. Refuse to create an invalid unique index
-- ────────────────────────────────────────────────────────────
-- Pre-existing duplicates must be resolved deliberately, not
-- papered over. Failing here keeps the invariant honest.
DO $$
DECLARE
  v_duplicate_orders INTEGER;
BEGIN
  SELECT count(*) INTO v_duplicate_orders
  FROM (
    SELECT order_id
    FROM payments
    WHERE method = 'paymob_card'
      AND status = 'pending'
    GROUP BY order_id
    HAVING COUNT(*) > 1
  ) duplicated;

  IF v_duplicate_orders > 0 THEN
    RAISE EXCEPTION
      'Cannot create uq_payments_one_pending_card_per_order: % order(s) have more than one pending paymob_card payment',
      v_duplicate_orders
      USING ERRCODE = '23505';
  END IF;
END $$;

-- One pending card payment per order, enforced by the database.
-- This is the concurrency boundary the Edge Function relies on:
-- `ON CONFLICT DO NOTHING` now means "someone else already has
-- the pending payment", not "insert failed".
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_card_per_order
  ON payments (order_id)
  WHERE method = 'paymob_card' AND status = 'pending';

-- ────────────────────────────────────────────────────────────
-- 3. Atomic get-or-create / claim RPC
-- ────────────────────────────────────────────────────────────
-- Replaces the read-then-insert sequence in paymob-initiate.
-- Single transaction, single lock scope, ownership enforced
-- server-side. Callable with the caller's own JWT — the Edge
-- Function no longer needs the service-role key.
CREATE OR REPLACE FUNCTION public.get_or_claim_paymob_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid     UUID;
  v_order   RECORD;
  v_payment RECORD;
  v_new_id  UUID;
  v_lease   INTERVAL := INTERVAL '5 minutes';
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  -- ─── Lock the order FIRST ───────────────────────────────
  -- Global lock order is order -> payment. Every payment path
  -- (this RPC, process_paymob_callback, expire_pending_order,
  -- confirm_cod_payment) takes the order lock first, so the
  -- graph stays acyclic.
  SELECT id, user_id, status, payment_method, total
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.user_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  -- Card-only, enforced in the database BEFORE any provider call.
  IF v_order.payment_method <> 'paymob_card' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unsupported_payment_method');
  END IF;

  -- ─── Lock the pending card payment, if one exists ───────
  SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_uid
      AND method = 'paymob_card'
      AND status = 'pending'
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Create exactly one pending card payment using the
    -- server-authoritative total. ON CONFLICT DO NOTHING turns a
    -- concurrent insert into a no-op instead of an error or a
    -- duplicate row.
    INSERT INTO payments (
      order_id, user_id, method, amount, status,
      paymob_initiation_claimed_at, paymob_initiation_phase,
      paymob_initiation_claim_token
    )
    VALUES (
      p_order_id, v_uid, 'paymob_card', v_order.total, 'pending',
      now(), 'pre_provider', gen_random_uuid()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_new_id;

    IF v_new_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', true, 'code', 'claimed',
        'payment_id', v_new_id,
        'claim_token', (SELECT paymob_initiation_claim_token FROM payments WHERE id = v_new_id),
        'claimed', true,
        'amount', v_order.total,
        'action', 'create_provider_order'
      );
    END IF;

    -- Lost the race: re-read the winner under the same lock.
      SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
             paymob_initiation_phase, paymob_initiation_claim_token
      INTO v_payment
      FROM payments
      WHERE order_id = p_order_id
        AND user_id = v_uid
        AND method = 'paymob_card'
        AND status = 'pending'
      ORDER BY created_at
      LIMIT 1
      FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_unavailable');
  END IF;

  -- ─── A provider order already exists ────────────────────
  -- Never create a second provider order. The caller reissues a
  -- payment key against the existing one.
  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'existing_provider_order',
      'payment_id', v_payment.id,
      'paymob_order_id', v_payment.paymob_order_id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'reissue_payment_key'
    );
  END IF;

  -- ─── Another request is already creating the order ──────
  -- A claim is permanent until the provider order id is persisted.
  -- There is no client release or lease-based reclamation: a timeout
  -- after provider submission is indistinguishable from a timeout before
  -- submission, so clearing it could create a duplicate external order.
  IF v_payment.paymob_initiation_claimed_at IS NOT NULL
     AND v_payment.paymob_initiation_phase = 'provider_submitted' THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'initiation_in_progress',
      'payment_id', v_payment.id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'retry'
    );
  END IF;

  IF v_payment.paymob_initiation_claimed_at IS NOT NULL
     AND v_payment.paymob_initiation_phase = 'pre_provider'
     AND v_payment.paymob_initiation_claimed_at > now() - v_lease THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'initiation_in_progress',
      'payment_id', v_payment.id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'retry'
    );
  END IF;

  -- ─── Claim provider-order creation ──────────────────────
  UPDATE payments
    SET paymob_initiation_claimed_at = now(),
        paymob_initiation_phase = 'pre_provider',
        paymob_initiation_claim_token = gen_random_uuid(),
        updated_at = now()
    WHERE id = v_payment.id;

  SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM payments
    WHERE id = v_payment.id
    FOR UPDATE;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'claimed',
    'payment_id', v_payment.id,
    'claim_token', v_payment.paymob_initiation_claim_token,
    'claimed', true,
    'amount', v_order.total,
    'action', 'create_provider_order'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO service_role;

-- Migration 015 grants this owner-bound persistence RPC to authenticated.
-- Redefine it here so phase advancement is atomic with provider-id persistence.
CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id(
  p_payment_id UUID,
  p_paymob_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_payment RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_payment_id IS NULL OR COALESCE(btrim(p_paymob_order_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT id, user_id, status, paymob_order_id
    INTO v_payment
    FROM payments
    WHERE id = p_payment_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_found');
  END IF;

  IF v_payment.user_id <> auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_pending');
  END IF;

  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_set');
  END IF;

  UPDATE payments
    SET paymob_order_id = btrim(p_paymob_order_id),
        paymob_initiation_phase = 'provider_persisted',
        updated_at = now()
    WHERE id = p_payment_id;

  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) TO authenticated;

-- The following internal service-only transitions are token-bound. A caller
-- cannot clear another attempt or reclaim a provider-submitted claim.
CREATE OR REPLACE FUNCTION public.mark_paymob_initiation_submitted(
  p_payment_id UUID,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE payments
    SET paymob_initiation_phase = 'provider_submitted',
        updated_at = now()
    WHERE id = p_payment_id
      AND paymob_initiation_claim_token = p_claim_token
      AND paymob_initiation_phase = 'pre_provider'
      AND status = 'pending'
      AND paymob_order_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pre_provider');
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'provider_submitted');
END;
$$;

CREATE OR REPLACE FUNCTION public.release_paymob_initiation_claim(
  p_payment_id UUID,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE payments
    SET paymob_initiation_claimed_at = NULL,
        paymob_initiation_phase = 'none',
        paymob_initiation_claim_token = NULL,
        updated_at = now()
    WHERE id = p_payment_id
      AND paymob_initiation_claim_token = p_claim_token
      AND paymob_initiation_phase = 'pre_provider'
      AND status = 'pending'
      AND paymob_order_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pre_provider');
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'released');
END;
$$;

REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) TO service_role;

-- ────────────────────────────────────────────────────────────
-- 4. Expiry is service-only
-- ────────────────────────────────────────────────────────────
-- Migration 031 granted this to `authenticated`. Any signed-in
-- caller could therefore expire every pending order globally.
-- pg_cron runs as service_role, which retains execution.
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM anon;
REVOKE EXECUTE ON FUNCTION public.batch_expire_pending_orders() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO service_role;

-- ────────────────────────────────────────────────────────────
-- 5. process_paymob_callback: order-first locking
-- ────────────────────────────────────────────────────────────
-- Behaviour and result contract are unchanged. Only the lock
-- order and the read-after-lock discipline change.
CREATE OR REPLACE FUNCTION process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id   TEXT,
  p_amount_cents    INTEGER,
  p_currency        TEXT,
  p_success         BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment        RECORD;
  v_order          RECORD;
  v_payment_id     UUID;
  v_order_id       UUID;
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Resolve payment -> order id (address resolution only) ──
  -- Deliberately unlocked. We cannot lock the payment first: the
  -- global lock order is order -> payment, and locking payment
  -- first is what produced the deadlock window against a
  -- concurrent expire_pending_order().
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  v_payment_id := v_payment.id;
  v_order_id := v_payment.order_id;

  -- ─── Lock the order FIRST and read the canonical total ──
  SELECT id, status, total, expires_at
    INTO v_order
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Acquire the payment lock second ─────────────────────
  PERFORM 1
    FROM payments
    WHERE id = v_payment_id
    FOR UPDATE;

  -- ─── Re-read both rows after both locks are held ─────────
  -- The first payment read only resolved the order id. These reads are
  -- authoritative and cannot be changed by callback/expiry peers now.
  SELECT id, status, total, expires_at
    INTO v_order
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE id = v_payment_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  v_order_total := v_order.total;

  -- ─── Validate amount/currency ──────────────────────────
  IF p_amount_cents IS NULL OR p_amount_cents <> v_order_total THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'amount_mismatch',
      'expected', v_order_total,
      'received', p_amount_cents
    );
  END IF;

  IF p_currency IS NOT NULL AND p_currency <> v_order_currency THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'currency_mismatch',
      'expected', v_order_currency,
      'received', p_currency
    );
  END IF;

  -- ─── RACE GUARD: check BOTH payment AND order status ───
  -- Payment already terminal → no-op.
  IF v_payment.status IN ('success', 'failed', 'expired', 'cancelled', 'refunded') THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- Order already terminal → no-op (do NOT mark payment success
  -- for an order that was cancelled/expired).
  IF v_order.status IN ('paid', 'processing', 'shipped', 'delivered',
                         'cancelled', 'refunded') THEN
    PERFORM audit_transition(
      'payment', v_payment.id,
      v_payment.status, v_payment.status,
      'paymob-callback',
      'late_callback_rejected',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'order_status', v_order.status::text,
        'success_intended', p_success
      )
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- ─── Apply the terminal transition ─────────────────────
  IF p_success THEN
    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'paid',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'success',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

    UPDATE payments
      SET status = 'success',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'paid'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'success',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  ELSE
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'failed',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'cancelled',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

    UPDATE payments
      SET status = 'failed',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'cancelled'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    -- Stock restoration: exactly once via restored flag + trigger.
    UPDATE order_items
      SET restored = true
      WHERE order_id = v_payment.order_id
        AND restored = false;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'failed',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Preserve the privilege matrix from migration 025.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- ────────────────────────────────────────────────────────────
-- 6. expire_pending_order: lock payment rows explicitly
-- ────────────────────────────────────────────────────────────
-- Previously the pending-payment UPDATE ran without an explicit
-- lock, leaving a window between the success check and the
-- expiry write.
CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order       RECORD;
  v_payment     RECORD;
  v_has_success BOOLEAN;
BEGIN
  -- Order lock first — consistent with the global lock order.
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'code', 'already_terminal');
  END IF;

  IF v_order.expires_at IS NULL OR v_order.expires_at >= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_expired');
  END IF;

  -- Lock every payment row for this order BEFORE reading or
  -- writing payment state. Because we already hold the order
  -- lock and the callback takes the order lock first, this
  -- cannot deadlock.
  PERFORM 1
    FROM payments
    WHERE order_id = p_order_id
    FOR UPDATE;

  -- Explicitly reread the locked order and payment rows before any
  -- success check or mutation. This keeps the callback/expiry contract
  -- visibly order-first and read-after-lock.
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  SELECT id, order_id, status
    INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE;

  -- ─── RACE GUARD: check if payment already succeeded ─────
  SELECT EXISTS(
    SELECT 1 FROM payments
    WHERE order_id = p_order_id
      AND status = 'success'
  ) INTO v_has_success;

  IF v_has_success THEN
    PERFORM audit_transition(
      'order', p_order_id,
      'pending', 'pending',
      'expire-worker',
      'expiry_aborted_payment_already_succeeded',
      '{}'::jsonb
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_paid',
      'order_id', p_order_id
    );
  END IF;

  -- ─── Apply expiry ──────────────────────────────────────
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'cancelled',
    'expire-worker',
    'order_expired',
    jsonb_build_object('expires_at', v_order.expires_at)
  );

  PERFORM audit_transition(
    'payment', p_order_id,
    'pending', 'expired',
    'expire-worker',
    'order_expired',
    '{}'::jsonb
  );

  UPDATE orders
    SET status = 'cancelled'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  UPDATE payments
    SET status = 'expired',
        updated_at = now()
    WHERE order_id = p_order_id
      AND status = 'pending';

  -- Stock restoration: exactly once via restored flag + trigger.
  UPDATE order_items
    SET restored = true
    WHERE order_id = p_order_id
      AND restored = false;

  RETURN jsonb_build_object('ok', true, 'code', 'expired');
END;
$$;

-- Preserve privilege matrix.
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 036_fix_audit_retention_cron.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- Migration 036: fix audit retention cron target table
-- ═══════════════════════════════════════════════════════════
-- AUDIT follow-up (2026-09-03):
--   * 031 scheduled 'audit-retention-90d' to prune public.audit_logs,
--     a table that never exists — the real forensic trail is
--     public.state_transitions (025). The guard made the job a daily
--     no-op, leaving state_transitions growing unbounded (it holds
--     Paymob txn ids in metadata).
--
-- Fix: reschedule the job to prune state_transitions by created_at,
-- keeping the same table-existence guard style as 031 so the job
-- stays valid even in fresh environments before 025.
-- Idempotent: unschedules then reschedules.
-- ═══════════════════════════════════════════════════════════

SELECT cron.unschedule('audit-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'audit-retention-90d');

SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='state_transitions') THEN DELETE FROM public.state_transitions WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 037_pending_order_payment_method.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- Migration 037: allow updating payment method on pending orders
-- ═══════════════════════════════════════════════════════════
-- PROBLEM (found live 2026-09-03):
--   * `create_checkout_order` (013) stores whatever payment method
--     the client passes (checkout defaults to 'Credit Card').
--   * The customer picks the REAL method later, on the payment
--     screen — AFTER the order already exists.
--   * `confirm_cod_payment` (018) requires the stored method to be
--     COD-like, so confirming COD on a 'Credit Card'-tagged order
--     always fails with `payment_not_cod` and the pay button
--     appears dead.
--
-- Fix: `set_pending_order_payment_method` lets the order OWNER move
-- their own PENDING order to a canonical method before confirming.
-- Allowlist keeps the domain tight ('cod' satisfies the 018
-- ILIKE '%cash%/%cod%' guard; 'card' keeps the Paymob path
-- explicit). Only pending orders may change method — paid /
-- cancelled / expired orders are immutable.
--
-- Conventions: SECURITY DEFINER, locked search_path, REVOKE from
-- PUBLIC/anon/authenticated (same as 033/035). Idempotent.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION set_pending_order_payment_method(
  p_order_id UUID,
  p_method   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner   UUID;
  v_status  TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;

  SELECT user_id, status::TEXT INTO v_owner, v_status
    FROM orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  UPDATE orders
     SET payment_method = p_method,
         updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method
  );
END;
$$;

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 038_fix_037_grants.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- Migration 038: fix 037 grant matrix for client-called RPC
-- ═══════════════════════════════════════════════════════════
-- BUG (found live 2026-09-03):
--   037 copied the service/cron-only grant pattern (REVOKE from
--   authenticated) from 033/035. But set_pending_order_payment_method
--   is called BY the Flutter client as the authenticated role, so
--   PostgREST rejected every call with 403 and COD checkout appeared
--   dead ("Failed to set payment method").
--
-- Correct convention for client-called RPCs (same as
-- confirm_cod_payment in 018/022 and the admin RPCs in 033):
--   REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated.
-- The function body itself enforces owner + pending + allowlist,
-- so granting EXECUTE is safe.
-- Idempotent: safe to re-run.
-- ═══════════════════════════════════════════════════════════

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 039_method_update_ensures_cod_row.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- Migration 039: set_pending_order_payment_method also ensures
-- the pending COD payment row
-- ═══════════════════════════════════════════════════════════
-- PROBLEM (found live 2026-09-03):
--   037 updates orders.payment_method, but confirm_cod_payment
--   (026 Decision 2) REJECTS with payment_not_found unless a
--   pending COD payment row already exists. At creation time 026
--   creates that row inside create_checkout_order — but only when
--   the creation-time method is COD. Orders created with another
--   method (e.g. the checkout default) and switched to COD later
--   via 037 had no payment row, so COD confirmation always failed
--   AFTER the method fix (038).
--
-- Fix: when switching TO 'cod', insert the pending COD payment row
-- exactly as 026 does at creation time
-- (method 'cash_on_delivery', amount = order total, status pending),
-- guarded by NOT EXISTS so repeats are idempotent no-ops.
-- Switching TO 'card' touches no payment rows (paymob-initiate
-- owns its own row lifecycle via the 035 claim protocol).
--
-- Grants: re-assert the 038 matrix (client-called RPC).
-- Idempotent: CREATE OR REPLACE + guarded INSERT + idempotent grants.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION set_pending_order_payment_method(
  p_order_id UUID,
  p_method   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner   UUID;
  v_status  TEXT;
  v_inserted INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;

  SELECT user_id, status::TEXT INTO v_owner, v_status
    FROM orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  UPDATE orders
     SET payment_method = p_method,
         updated_at = now()
   WHERE id = p_order_id;

  -- Mirror 026's creation-time behavior: a pending COD payment row
  -- must exist for confirm_cod_payment to find. Idempotent guard:
  -- only insert when no pending COD-like row exists yet.
  IF p_method = 'cod' THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'cash_on_delivery', total, 'pending'
      FROM orders
     WHERE id = p_order_id
       AND NOT EXISTS (
             SELECT 1 FROM payments
              WHERE order_id = p_order_id
                AND status = 'pending'
                AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
           );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method,
    'payment_row_ensured', (p_method <> 'cod' OR v_inserted > 0)
  );
END;
$$;

-- Re-assert the 038 client-called grant matrix (CREATE OR REPLACE
-- preserves grants, but be explicit — same convention as 022/026).
REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 040_account_deletion.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 040: relax user-ownership FKs for account deletion
-- (UX-043, decision B: retain transactional records, unlink the
-- user so the personal footprint is erased).
--
--   orders.user_id    NOT NULL, FK RESTRICT  → NULLABLE, FK ON DELETE SET NULL
--   payments.user_id  NOT NULL, FK CASCADE   → NULLABLE, FK ON DELETE SET NULL
--
-- After this migration, deleting an auth user cascades through
-- profiles and wipes addresses / wishlists / cart_items, while
-- order + payment rows survive with user_id = NULL (their
-- fulfillment/financial content is self-contained snapshots).
--
-- RLS impact: client SELECT policies filter by auth.uid() =
-- user_id, so orphaned retention rows are never visible through
-- the app. The edge function (delete-account) performs the delete
-- with the service role; no new client RLS path is introduced.
--
-- Forward-only, idempotent. Human review required before
-- `supabase db push`.
-- ============================================================

DO $$
BEGIN
  -- ─── orders: NOT NULL RESTRICT → NULLABLE SET NULL ─────────
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_user_id_fkey' AND conrelid = 'public.orders'::regclass
  ) THEN
    ALTER TABLE public.orders DROP CONSTRAINT orders_user_id_fkey;
  END IF;

  ALTER TABLE public.orders ALTER COLUMN user_id DROP NOT NULL;

  ALTER TABLE public.orders
    ADD CONSTRAINT orders_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

  -- ─── payments: NOT NULL CASCADE → NULLABLE SET NULL ────────
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payments_user_id_fkey' AND conrelid = 'public.payments'::regclass
  ) THEN
    ALTER TABLE public.payments DROP CONSTRAINT payments_user_id_fkey;
  END IF;

  ALTER TABLE public.payments ALTER COLUMN user_id DROP NOT NULL;

  ALTER TABLE public.payments
    ADD CONSTRAINT payments_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
END $$;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 041_instapay_payment_method.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 041: InstaPay payment method (manual confirmation)
-- Part of the InstaPay implementation plan
-- (docs/InstaPay-implementation-plan.md, PR #36). Owner approved
-- recommendations: D1 manual review, D2 24h expiry, D3 screenshot
-- required + reference optional, D4 dashboard-first review.
--
-- Adds 'instapay' to the payment-method allowlists and creates the
-- proof-of-transfer review surface:
--   1. set_pending_order_payment_method allowlist ('cod','card') ->
--      ('cod','card','instapay')            [037/039 seam]
--      and ensures a single pending 'instapay' payments row
--      (mirror of the 039 COD-row guarantee).
--   2. instapay_proofs table: owner-uploaded transfer proofs
--      (screenshot required per D3, reference optional), reviewed
--      by an admin. No new payments.status values — approval
--      reuses the COD terminal write pattern.
--   3. Private storage bucket 'instapay-proofs' with RLS.
--   4. review_instapay_proof(UUID, boolean, TEXT): admin-only RPC;
--      approve => payments.success + orders.paid in ONE transaction
--      (server-generated transaction id), reject => failed.
--   5. expire_pending_order gains a 24h (D2) instapay expiry:
--      pending instapay payments older than 24h are cancelled.
--
-- Conventions: SECURITY DEFINER, locked search_path, REVOKE from
-- PUBLIC/anon (033/035/037 style). Forward-only, idempotent.
-- This migration does NOT touch Paymob flows, RLS policies on
-- existing tables, or order state machinery beyond the RPC.
-- ============================================================

BEGIN;

-- ─── 1. Allowlist: 'instapay' joins 'cod' and 'card' ─────────
-- 039 shape preserved verbatim; only the allowlist tuple and the
-- row-ensure branch change. The instapay row guarantee mirrors the
-- COD one: exactly one pending 'instapay' payments row per order.
CREATE OR REPLACE FUNCTION set_pending_order_payment_method(
  p_order_id UUID,
  p_method   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner   UUID;
  v_status  TEXT;
  v_inserted INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card', 'instapay') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;

  SELECT user_id, status::TEXT INTO v_owner, v_status
    FROM orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  UPDATE orders
     SET payment_method = p_method,
         updated_at = now()
   WHERE id = p_order_id;

  -- Pending COD row guarantee (039, unchanged).
  IF p_method = 'cod' THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'cash_on_delivery', total, 'pending'
      FROM orders
     WHERE id = p_order_id
       AND NOT EXISTS (
             SELECT 1 FROM payments
              WHERE order_id = p_order_id
                AND status = 'pending'
                AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
           );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  -- Pending InstaPay row guarantee: the review flow keys off this
  -- row; keep it single and pending, mirroring COD semantics.
  IF p_method = 'instapay' THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'instapay', total, 'pending'
      FROM orders
     WHERE id = p_order_id
       AND NOT EXISTS (
             SELECT 1 FROM payments
              WHERE order_id = p_order_id
                AND status = 'pending'
                AND method = 'instapay'
           );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method,
    'payment_row_ensured', (p_method NOT IN ('cod', 'instapay') OR v_inserted > 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;

-- ─── 2. Proof-of-transfer review surface ─────────────────────
CREATE TABLE IF NOT EXISTS instapay_proofs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  reference TEXT,
  outcome TEXT CHECK (outcome IN ('approved','rejected')),
  reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_instapay_proofs_payment
  ON instapay_proofs(payment_id);
CREATE INDEX IF NOT EXISTS idx_instapay_proofs_outcome
  ON instapay_proofs(outcome);

ALTER TABLE instapay_proofs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "instapay_proofs_select_own" ON instapay_proofs;
CREATE POLICY "instapay_proofs_select_own"
  ON instapay_proofs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments p
       WHERE p.id = payment_id
         AND p.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles prof
       WHERE prof.id = auth.uid()
         AND prof.is_admin = true
    )
  );

DROP POLICY IF EXISTS "instapay_proofs_insert_own" ON instapay_proofs;
CREATE POLICY "instapay_proofs_insert_own"
  ON instapay_proofs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM payments p
       WHERE p.id = payment_id
         AND p.user_id = auth.uid()
         AND p.status = 'pending'
    )
  );

-- Admin review update path goes through the SECURITY DEFINER RPC
-- below; no direct UPDATE policy is granted to anyone.

-- ─── 3. Private storage bucket for proofs ────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('instapay-proofs', 'instapay-proofs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "instapay proofs owner read" ON storage.objects;
CREATE POLICY "instapay proofs owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'instapay-proofs'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM profiles prof
         WHERE prof.id = auth.uid()
           AND prof.is_admin = true
      )
    )
  );

DROP POLICY IF EXISTS "instapay proofs owner write" ON storage.objects;
CREATE POLICY "instapay proofs owner write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'instapay-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- ─── 4. Admin review RPC ─────────────────────────────────────
-- Approve: payment -> success (server-generated transaction id),
-- order -> paid, proof outcome recorded — all in one transaction.
-- Reject: payment -> failed, proof outcome recorded.
-- Fail-closed: non-admin callers get a generic refusal.
CREATE OR REPLACE FUNCTION review_instapay_proof(
  p_proof_id UUID,
  p_approve  BOOLEAN,
  p_note     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin  UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_payment RECORD;
  v_order_id UUID;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  SELECT is_admin INTO v_is_admin
    FROM profiles
   WHERE id = v_admin;

  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, outcome INTO v_payment
    FROM instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;

  IF v_payment.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;

  SELECT order_id INTO v_order_id
    FROM payments
   WHERE id = v_payment.payment_id
   FOR UPDATE;

  IF p_approve THEN
    UPDATE payments
       SET status = 'success',
           transaction_id = 'instapay_' || p_proof_id::TEXT,
           updated_at = now()
     WHERE id = v_payment.payment_id
       AND status = 'pending';

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;

    UPDATE orders
       SET status = 'paid',
           updated_at = now()
     WHERE id = v_order_id
       AND status = 'pending';

    UPDATE instapay_proofs
       SET outcome = 'approved',
           reviewed_by = v_admin,
           reviewed_at = now(),
           note = p_note
     WHERE id = p_proof_id;
  ELSE
    UPDATE payments
       SET status = 'failed',
           updated_at = now()
     WHERE id = v_payment.payment_id
       AND status = 'pending';

    UPDATE instapay_proofs
       SET outcome = 'rejected',
           reviewed_by = v_admin,
           reviewed_at = now(),
           note = p_note
     WHERE id = p_proof_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment.payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  FROM PUBLIC, anon, authenticated;

-- ─── 5. 24h expiry for pending instapay payments (D2) ────────
-- Mirrors the card/claim expiry machinery: stale pending instapay
-- claims self-heal via the cancel-expired-orders worker.
CREATE OR REPLACE FUNCTION expire_stale_instapay_payments()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cancelled INTEGER := 0;
BEGIN
  WITH stale AS (
    SELECT p.id, p.order_id
      FROM payments p
      JOIN orders o ON o.id = p.order_id
     WHERE p.method = 'instapay'
       AND p.status = 'pending'
       AND p.created_at < now() - INTERVAL '24 hours'
       AND o.status = 'pending'
     FOR UPDATE SKIP LOCKED
  )
  UPDATE payments pp
     SET status = 'expired',
         updated_at = now()
    FROM stale s
   WHERE pp.id = s.id;

  GET DIAGNOSTICS v_cancelled = ROW_COUNT;
  RETURN v_cancelled;
END;
$$;

REVOKE ALL ON FUNCTION expire_stale_instapay_payments()
  FROM PUBLIC, anon, authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 042_fix_041_review_grant.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 042: fix review_instapay_proof EXECUTE privilege
--
-- Bug: migration 041 created review_instapay_proof with
--   REVOKE ALL ... FROM PUBLIC, anon, authenticated
-- and never granted EXECUTE back to any role. The deployed ACL
-- ended up as {postgres, service_role} only, so the
-- instapay-review Edge Function — which calls the RPC under the
-- admin caller's JWT (role 'authenticated') — always failed with
-- SQLSTATE 42501 (permission denied for function), surfaced to
-- clients as { message: "rpc_error" }. Found by the staging E2E
-- (scripts/_pkgL/_e2e_instapay.mjs).
--
-- Fix: mirror the sibling RPC in 041
-- (set_pending_order_payment_method): REVOKE from PUBLIC/anon,
-- GRANT EXECUTE to authenticated. Admin-only safety is NOT
-- weakened: review_instapay_proof is SECURITY DEFINER and
-- re-verifies profiles.is_admin from the JWT inside its body,
-- returning admin_required otherwise. The grant only permits
-- entering the function. service_role keeps EXECUTE (dashboard/
-- service paths unchanged).
--
-- Conventions: forward-only, idempotent, locked search_path.
-- ============================================================

BEGIN;

REVOKE ALL ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  TO authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 043_low_stock_returns_variant_id.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 043: get_low_stock_products must return the variant id
--
-- Bug: the RPC has returned only
--   (product_name, variant_size, variant_color, current_stock)
-- since migration 008 (re-created unchanged by 017), but the
-- Flutter client contract — AdminMappers.lowStockVariantFromRow,
-- introduced with the T1 catalog-management API (PR #18) — requires
-- row['id'] to be product_variants.id: it is what the Inventory
-- page passes back to updateStock(). The mapper skips id-less rows
-- as unmappable, so against the deployed function shape EVERY row
-- is dropped and the admin Inventory page always renders
-- "All stock levels are healthy", even when variants sit at or
-- below the threshold. Confirmed on staging: variants with stock
-- 0..5 exist while the page shows the healthy empty state, and the
-- dashboard "Low Stock" stat reads 0.
--
-- Fix: add `id UUID` to RETURNS TABLE and select pv.id. The auth
-- contract from 017 is preserved verbatim: reject anonymous
-- callers, verify profiles.is_admin from the JWT, SECURITY DEFINER
-- with a locked search_path. Appending a column is additive —
-- existing consumers selecting columns by name keep working.
--
-- Conventions: forward-only, idempotent, locked search_path.
--
-- Deployment note: CREATE OR REPLACE cannot change a function's return
-- shape (SQLSTATE 42P13), so the old signature is dropped first. The
-- migration runs in a single transaction — the function is never absent
-- to concurrent callers — and the grants below restore the ACLs that
-- DROP removes.
-- ============================================================

BEGIN;

DROP FUNCTION IF EXISTS get_low_stock_products(INTEGER);

CREATE OR REPLACE FUNCTION get_low_stock_products(p_threshold INTEGER DEFAULT 5)
RETURNS TABLE (
  id UUID,
  product_name TEXT,
  variant_size TEXT,
  variant_color TEXT,
  current_stock INTEGER
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(profiles.is_admin, false)
    INTO v_is_admin
    FROM profiles
    WHERE profiles.id = auth.uid();

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    pv.id,
    p.name,
    pv.size,
    pv.color,
    pv.stock
  FROM product_variants pv
  JOIN products p ON p.id = pv.product_id
  WHERE pv.stock <= p_threshold
    AND pv.is_active = true
    AND p.is_active = true
  ORDER BY pv.stock ASC;
END;
$$;

-- DROP removed the ACLs attached to the old signature; re-assert the
-- desired final state explicitly so the migration is re-runnable.
REVOKE ALL ON FUNCTION get_low_stock_products(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_low_stock_products(INTEGER) TO authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 044_price_override_check.sql
-- ────────────────────────────────────────────────────────────
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


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 045_customer_numeric_checks.sql
-- ────────────────────────────────────────────────────────────
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


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 046_membership_tier.sql
-- ────────────────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────
-- 046: MEMBERSHIP TIER — real customer data behind the Premium badge
--
-- profiles.membership_tier joins the customer-facing schema. The tier is
-- SERVER-MANAGED: customers can never set it themselves (RLS WITH CHECK),
-- only admins can change it (SECURITY DEFINER RPC), mirroring how 003
-- protects is_admin.
--
-- Value contract (enforced by profiles_membership_tier_check):
--   'standard' (default) | 'premium'
--
-- Write paths after this migration:
--   - INSERT (self, new profile):  forced to is_admin=false AND
--     membership_tier='standard' — this also closes a pre-existing
--     escalation gap: 002's profiles_insert_own allowed a customer to
--     INSERT their own row with is_admin=true before any trigger-created
--     row existed (003 hardened UPDATE but never INSERT).
--   - UPDATE (self): is_admin and membership_tier must equal the current
--     row's values — name/phone/avatar stay editable, privileges do not.
--   - admin_set_membership_tier(UUID, TEXT): the only tier write path,
--     admin-gated via assert_admin() (033), revokes from PUBLIC/anon and
--     grants to authenticated like every admin RPC.
-- ─────────────────────────────────────────────────────────────

BEGIN;

-- 1. Column + value guard.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS membership_tier TEXT NOT NULL DEFAULT 'standard';

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_membership_tier_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_membership_tier_check
  CHECK (membership_tier IN ('standard', 'premium'));

-- 2. INSERT hardening: a self-created profile must start unprivileged.
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own_safe" ON profiles;
CREATE POLICY "profiles_insert_own_safe"
  ON profiles FOR INSERT
  WITH CHECK (
    auth.uid() = id
    AND is_admin = false
    AND membership_tier = 'standard'
  );

-- 3. UPDATE hardening: tier and admin flag are server-managed; the two
-- subqueries compare NEW values against the existing row (same pattern
-- as 003's is_admin guard, extended to the tier).
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own_safe" ON profiles;
CREATE POLICY "profiles_update_own_safe"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
    AND membership_tier = (SELECT membership_tier FROM profiles WHERE id = auth.uid())
  );

-- 4. The admin write path.
CREATE OR REPLACE FUNCTION admin_set_membership_tier(
  p_profile_id UUID,
  p_tier TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM assert_admin();

  IF p_tier NOT IN ('standard', 'premium') THEN
    RAISE EXCEPTION 'invalid_tier' USING ERRCODE = '22023';
  END IF;

  UPDATE profiles
     SET membership_tier = p_tier,
         updated_at = now()
   WHERE id = p_profile_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
  END IF;
END $$;

REVOKE EXECUTE ON FUNCTION admin_set_membership_tier(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_set_membership_tier(UUID, TEXT) TO authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 047_premium_free_shipping.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════
-- 047: PREMIUM PERK — free shipping for premium members
--
-- The perk is applied SERVER-SIDE inside create_checkout_order:
-- after the zone calculation zeroes shipping for profiles whose
-- membership_tier = 'premium' (migration 046). The client never
-- sends money — this keeps the server-authoritative pricing
-- invariant: a tampered client can only *request* an order, the
-- tier is read from the profile row, not from the request.
--
-- Everything else in the function is carried forward verbatim
-- from 026 (which restored 013/020/021). Signature unchanged, so
-- no client param changes; the RPC response already returns the
-- discounted `shipping` and recomputed `total`, so the checkout
-- "server confirmed totals" card needs no response-shape change.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
  v_is_cod       BOOLEAN;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ─── Validate payment method ─────────────────────────────
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- ─── Validate items ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- ─── Validate address ────────────────────────────────────
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- ─── Idempotency: return existing order if key matches ───
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true
      );
    END IF;
  END IF;

  -- ─── Validate items, read DB prices, check stock ────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- Look up variant and product in one query
    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    -- Collect validated item for later insert
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- ─── Calculate shipping from shipping-zone logic ────────
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);

  -- ─── Premium perk: free shipping (migration 047) ────────
  -- Read from the profile row, never from the request. Applied
  -- AFTER the zone calculation so the free-shipping threshold,
  -- zone fees, and config fallbacks keep working for everyone
  -- else exactly as before.
  IF (SELECT membership_tier FROM profiles WHERE id = v_user_id) = 'premium' THEN
    v_shipping := 0;
  END IF;

  v_total    := v_subtotal + v_shipping;

   -- ─── Compute expiry ──────────────────────────────────────
   v_expires_at := now() + interval '15 minutes';

   -- ─── Ensure a profile exists ──────────────────────────
   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   -- ─── Insert order (atomic with the rest) ─────────────────
   BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
      'expires_at', v_existing_expires,
      'idempotent', true
    );
  END;

  -- ─── Insert order items + decrement stock ────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- ─── Clear the user's server-side cart ──────────────────
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- ═══════════════════════════════════════════════════════
  -- Create pending COD payment row for COD orders
  -- ═══════════════════════════════════════════════════════
  -- confirm_cod_payment rejects with payment_not_found, so COD
  -- orders need their pending payment row created here.
  v_is_cod := p_payment_method ILIKE '%cash%'
           OR p_payment_method ILIKE '%cod%';

  IF v_is_cod THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (v_order_id, v_user_id, 'cash_on_delivery', v_total, 'pending');
  END IF;

  -- ─── Return the canonical order data ─────────────────────
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false
  );
END;
$$;

-- Privileges unchanged (019/024 posture): authenticated only.
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 048_external_lineage.sql
-- ────────────────────────────────────────────────────────────
-- 048–051 EXTERNAL LINEAGE STUB (2026-09-13)
-- The linked database has migrations 048–051 applied whose SQL files were
-- never committed to this repository (applied by a parallel work session).
-- Verified live objects attributable to them: analytics_events
-- (id, user_id, event, properties, created_at) and notifications.
-- Do NOT delete: keeps supabase db push history alignment. Content unknown.


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 049_external_lineage.sql
-- ────────────────────────────────────────────────────────────
-- See 048_external_lineage.sql — external-lineage stub (content unknown, applied remotely).


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 050_external_lineage.sql
-- ────────────────────────────────────────────────────────────
-- See 048_external_lineage.sql — external-lineage stub (content unknown, applied remotely).


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 051_external_lineage.sql
-- ────────────────────────────────────────────────────────────
-- See 048_external_lineage.sql — external-lineage stub (content unknown, applied remotely).


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 052_seed_demo_showcase.sql
-- ────────────────────────────────────────────────────────────
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


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 053_analytics_events.sql
-- ────────────────────────────────────────────────────────────
-- 053_analytics_events.sql (feature-batch section 11 -- REVIEWED pre-apply 2026-09-13)
-- Applies to a database where an analytics_events table ALREADY EXISTS
-- (created by remote migrations 048-051 with columns: id, user_id, event,
-- properties, created_at -- verified via REST OpenAPI). This migration only:
--   1. aligns indexes/policies with the storefront funnel contract,
--   2. provides the admin aggregate RPC reading the existing event column.
-- The client (AnalyticsService) inserts {event, properties} to match.

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_time
  ON public.analytics_events (event, created_at DESC);

-- Idempotent policy add (no IF NOT EXISTS for policies before PG15).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'analytics_events'
      AND policyname = 'analytics_insert_own'
  ) THEN
    CREATE POLICY analytics_insert_own ON public.analytics_events
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid() OR user_id IS NULL);
  END IF;
END
$$;

-- Admin aggregates for the dashboard widget (counts per event, last
-- 30 days) reading the existing event column.
CREATE OR REPLACE FUNCTION public.assert_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_admin
  );
$$;

CREATE OR REPLACE FUNCTION public.analytics_event_counts_admin()
RETURNS TABLE (event_name text, count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.assert_is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY
    SELECT e.event AS event_name, count(*)::bigint AS count
    FROM public.analytics_events e
    WHERE e.created_at > now() - interval '30 days'
    GROUP BY e.event
    ORDER BY count DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytics_event_counts_admin() TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 054_app_config.sql
-- ────────────────────────────────────────────────────────────
-- 054_app_config.sql (feature-batch §13 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Remote configuration: a flat key/value table readable by any client
-- (values are non-sensitive: feature flags, maintenance mode, minimum
-- supported version). Writes are admin-only.

CREATE TABLE IF NOT EXISTS public.app_config (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_config_read ON public.app_config
  FOR SELECT USING (true);

CREATE POLICY app_config_admin_write ON public.app_config
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

-- Sensible starting keys (values reviewed at deploy time):
INSERT INTO public.app_config (key, value) VALUES
  ('maintenance_mode', 'false'),
  ('min_supported_version', '0.0.0')
ON CONFLICT (key) DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 055_search_suggestions.sql
-- ────────────────────────────────────────────────────────────
-- 055_search_suggestions.sql (feature-batch §7 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Server-side fuzzy search suggestions for the catalog search bar.
-- The client ships a pure client-side fallback (suggestProductNames)
-- so the UX works before this migration is applied; once applied,
-- the storefront can switch to the RPC for cross-catalog fuzzy recall.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON public.products USING gin (name gin_trgm_ops);

-- Returns up to `limit` distinct product names that fuzzily match the
-- query, best (most similar) first. Exact matches are excluded — they
-- are already the primary search results. RLS: reads via the anon-
-- readable products table, no customer PII involved.
CREATE OR REPLACE FUNCTION public.search_suggestions(
  q text,
  lim integer DEFAULT 5
)
RETURNS TABLE (name text)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT p.name
  FROM public.products p
  WHERE p.name ILIKE '%' || q || '%'
    AND lower(p.name) <> lower(trim(q))
    AND similarity(p.name, trim(q)) > 0.1
  ORDER BY similarity(p.name, trim(q)) DESC
  LIMIT lim;
$$;

-- The RPC is intentionally read-only and invoker-scoped; no grants to
-- service_role changes needed. Expose to anon + authenticated:
GRANT EXECUTE ON FUNCTION public.search_suggestions(text, integer)
  TO anon, authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 056_coupons.sql
-- ────────────────────────────────────────────────────────────
-- 056_coupons.sql (feature-batch §8 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Promo codes end-to-end:
--   * `coupons` table (admin-managed, RLS: admin-write, none read by
--     clients directly — validation goes through the SECURITY DEFINER
--     RPC so inactive/expired rows never leak).
--   * `validate_coupon(p_code)` RPC for checkout validation.
--   * `create_checkout_order` update: accepts `p_coupon_code`, applies
--     the discount SERVER-SIDE and stamps `coupons_id` on the order.
--     Money math remains server-owned (design spec §1).

-- ─── Table ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.coupons (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text NOT NULL UNIQUE,
  discount_minor integer NOT NULL CHECK (discount_minor > 0),
  description    text,
  active         boolean NOT NULL DEFAULT true,
  expires_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- No public policies: only the service role (via SECURITY DEFINER
-- functions) and admins reach this table.
CREATE POLICY coupons_admin_read ON public.coupons
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );
CREATE POLICY coupons_admin_write ON public.coupons
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS coupons_id uuid REFERENCES public.coupons(id);
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS coupon_discount_minor integer NOT NULL DEFAULT 0;

-- ─── validate_coupon RPC ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.validate_coupon(p_code text)
RETURNS TABLE (code text, discount_minor integer, description text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.code, c.discount_minor, c.description
  FROM public.coupons c
  WHERE upper(trim(c.code)) = upper(trim(p_code))
    AND c.active
    AND (c.expires_at IS NULL OR c.expires_at > now())
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.validate_coupon(text)
  TO anon, authenticated;

-- ─── create_checkout_order: accept p_coupon_code ─────────────────────
-- NOTE FOR REVIEWER: this section must be merged into the CURRENT
-- create_checkout_order definition (migration 013 + later revisions).
-- The essential deltas are:
--   1. new parameter  `p_coupon_code text DEFAULT NULL`,
--   2. before pricing: resolve the coupon via validate_coupon semantics
--      (NULL when absent/invalid — an invalid code must NOT block the
--      order, it simply applies no discount),
--   3. `v_total := GREATEST(v_total - v_coupon_discount, 0)` after the
--      shipping computation and before the order insert,
--   4. store `coupons_id` + `coupon_discount_minor` on the order row.
-- The full rewritten function body is intentionally NOT inlined here so
-- it is diffed against the live definition during owner review instead
-- of clobbering a newer revision.


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 057_product_reviews.sql
-- ────────────────────────────────────────────────────────────
-- 057_product_reviews.sql (feature-batch §9 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Buy-to-review photo reviews with moderation:
--   * customers who received an order containing the product may submit,
--   * rows start `pending` and are only publicly readable when
--     `approved`,
--   * the storefront reads via a joined view that carries the author's
--     display name (never an email — PII boundary).

CREATE TABLE IF NOT EXISTS public.product_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating      integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  text        text NOT NULL DEFAULT '',
  photo_url   text,
  status      text NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_reviews_product
  ON public.product_reviews (product_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user
  ON public.product_reviews (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_reviews_one_per_user
  ON public.product_reviews (product_id, user_id);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

-- INSERT: any authenticated user (the buy-to-review check is enforced
-- by this policy itself — delivery proof via orders).
CREATE POLICY reviews_insert_buyers ON public.product_reviews
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.orders o
      JOIN public.order_items oi ON oi.order_id = o.id
      WHERE o.user_id = auth.uid()
        AND o.status IN ('delivered', 'paid', 'shipped', 'processing')
        AND oi.product_id = product_reviews.product_id
    )
  );

-- READ: approved rows for everyone; own rows (any status) for the author.
CREATE POLICY reviews_read_public ON public.product_reviews
  FOR SELECT USING (
    status = 'approved'
    OR user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.is_admin)
  );

-- UPDATE/DELETE: admins only (moderation).
CREATE POLICY reviews_admin_write ON public.product_reviews
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );
CREATE POLICY reviews_admin_delete ON public.product_reviews
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.is_admin)
  );

-- ─── Public read view with the author display name ───────────────────
CREATE OR REPLACE VIEW public.product_reviews_public AS
SELECT
  r.id,
  r.product_id,
  r.rating,
  r.text,
  r.photo_url,
  r.created_at,
  COALESCE(NULLIF(p.full_name, ''), 'Al Batal') AS author_name
FROM public.product_reviews r
LEFT JOIN public.profiles p ON p.id = r.user_id
WHERE r.status = 'approved';

GRANT SELECT ON public.product_reviews_public TO anon, authenticated;

-- ─── Storage: customer review photos ─────────────────────────────────
-- Bucket lives in the product-images bucket policy family; review
-- objects are namespaced `reviews/` and served publicly (images are
-- attached to approved reviews only by moderation).


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 058_fabric_attributes.sql
-- ────────────────────────────────────────────────────────────
-- 058_fabric_attributes.sql (feature-batch §10 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- Fabric-specific commerce data:
--   * roll width (cm) and weight (GSM) surfaced on the product details,
--   * sell-by-length: when enabled, shoppers pick a custom cut length
--     (0.5 m steps, >= min_cut_meters) and the metered line is validated
--     server-side inside create_checkout_order (delta below).

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS width_cm integer
    CHECK (width_cm IS NULL OR width_cm BETWEEN 50 AND 400);
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS gsm integer
    CHECK (gsm IS NULL OR gsm BETWEEN 50 AND 1500);
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS sell_by_length boolean NOT NULL DEFAULT false;
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS min_cut_meters numeric(4, 1)
    CHECK (min_cut_meters IS NULL OR min_cut_meters >= 0.5);

-- ─── admin_upsert_product: new optional parameters ───────────────────
-- NOTE FOR REVIEWER: extend the CURRENT admin_upsert_product definition
-- (033 + 044 revisions) with, in this order:
--     p_care text DEFAULT NULL,
--     p_origin text DEFAULT NULL,
--     p_width_cm integer DEFAULT NULL,
--     p_gsm integer DEFAULT NULL,
--     p_sell_by_length boolean DEFAULT NULL,
--     p_min_cut_meters numeric DEFAULT NULL,
-- and include them in the UPDATE/INSERT column lists. The client sends
-- these named parameters ONLY when set, so pre-051 deployments keep
-- working (unknown-parameter errors surface only for admins who fill
-- the new fields before the migration is applied).

-- ─── create_checkout_order: metered-line validation delta ────────────
-- NOTE FOR REVIEWER: for lines whose product has sell_by_length = true,
-- validate the requested size against the fabric contract instead of the
-- fixed variant table:
--     1. parse `size` as '<meters>m' (e.g. '3.5m'),
--     2. reject when meters < products.min_cut_meters,
--     3. snap to the 0.5 m grid server-side (authoritative rounding),
--     4. price the line as base_price (per meter) x snapped meters,
--     5. decrement roll stock tracked in whole meters on the baseline
--        '1m' variant (stock column already holds integer units).
-- Keeping this in the RPC preserves the server-first money math
-- contract pinned by the checkout tests.


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 059_cache_reload.sql
-- ────────────────────────────────────────────────────────────
-- 059_cache_reload.sql (2026-09-13): post-migration PostgREST schema
-- cache reload. The migrations 053-058 ran through the management API,
-- which does not NOTIFY the pgrst channel; without this the REST layer
-- keeps serving the pre-migration schema (app_config 404 etc.).
NOTIFY pgrst, 'reload schema';


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 060_rate_limits.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================
-- Migration 060: Edge-function rate limiting (audit 2026-09-13)
--
-- Backs the shared `_shared/rate_limit.ts` helper: one atomic
-- INSERT .. ON CONFLICT per check, SECURITY DEFINER so the
-- edge functions (user-scoped or service-role clients) can take
-- a token without any table grants.
--
-- DEPLOY GATE: human review + staging apply first (041/046
-- precedent). No client behavior changes until the functions
-- that call rate_limit_take are deployed.
-- ============================================================

create table if not exists public.rate_limits (
  bucket     text   not null,
  window_id  bigint not null,
  count      bigint not null default 0,
  primary key (bucket, window_id)
);

comment on table public.rate_limits is
  'Per-caller rate-limit counters for edge functions (migration 060). '
  'One row per (bucket, window); windows are epoch / window_seconds.';

-- No client ever reads the table directly: all access goes through
-- the SECURITY DEFINER function below.
revoke all on public.rate_limits from anon, authenticated, public;

create or replace function public.rate_limit_take(
  p_bucket          text,
  p_limit           int,
  p_window_seconds  int
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window bigint :=
    extract(epoch from now())::bigint / greatest(p_window_seconds, 1);
  v_allowed boolean;
begin
  -- Atomic take: insert the window row on first sight, else bump the
  -- counter only while the budget lasts. `found` is false once the
  -- window's budget is exhausted -> the caller returns 429.
  insert into public.rate_limits (bucket, window_id, count)
    values (p_bucket, v_window, 1)
    on conflict (bucket, window_id)
    do update set count = public.rate_limits.count + 1
    where public.rate_limits.count < p_limit;
  -- Capture the TAKE result immediately: FOUND is overwritten by
  -- every subsequent DML (verifier round 2 must-fix — the prune's
  -- DELETE below must not mask the take's outcome).
  v_allowed := found;
  -- Opportunistic housekeeping: ~1% of takes prune dead windows
  -- (>48h old). Runs AFTER the take result is captured.
  if random() < 0.01 then
    delete from public.rate_limits
    where window_id < extract(epoch from now())::bigint - 172800;
  end if;
  return v_allowed;
end;
$$;

-- Every authenticated edge-function caller (user-scoped clients) may
-- take a token; anon must never reach it (functions authenticate
-- before checking). Service-role bypasses grants by design.
revoke all on function public.rate_limit_take(text, int, int) from public, anon;
grant execute on function public.rate_limit_take(text, int, int) to authenticated;



-- ────────────────────────────────────────────────────────────
-- MIGRATION: 061_admin_profiles_read.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================================
-- 061_admin_profiles_read.sql — AUD-008 remediation (route a)
-- ============================================================================
-- Provenance: docs/audit/2026-09-15/proposals/061_admin_profiles_read.sql
-- (owner-reviewed 2026-09-15; route (a) chosen over route (b) because the
-- client never calls admin_list_customers — SupabaseAdminRepository
-- .fetchCustomers reads profiles(id, full_name, phone, membership_tier)
-- directly, so the table-level SELECT policy is the change that makes the
-- live admin Customers screen list other users).
--
-- Problem
-- -------
-- public.profiles grants SELECT only for the caller's own row
-- (002_rls_policies.sql "profiles_select_own" USING auth.uid() = id), so an
-- admin sees ONLY their own profile row and the customer directory silently
-- under-reports.
--
-- Security analysis
-- -----------------
-- * The fix widens SELECT to ADMINS only, never to all authenticated users:
--   phone is PII (profiles has no email column; auth.users holds it).
-- * is_admin is read from the caller's own row; profiles_update_own_safe
--   (029) prevents self-escalation, so trusting is_admin here is sound.
-- * The admin check is wrapped in a SECURITY DEFINER helper to avoid
--   recursive RLS evaluation, matching the 017 (get_order_details) pattern.
-- * Additive: the own-row policy stays; non-admins still see exactly one row.
-- ============================================================================

-- 1. SECURITY DEFINER admin check (avoids recursive RLS evaluation).
create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.is_current_user_admin() from public;
grant execute on function public.is_current_user_admin() to authenticated;

-- 2. Admin-only SELECT policy on profiles (additive: the own-row policy stays).
drop policy if exists "profiles_select_admin" on public.profiles;
create policy "profiles_select_admin"
  on public.profiles
  for select
  to authenticated
  using ( public.is_current_user_admin() );

-- ============================================================================
-- Rollback
-- ============================================================================
-- drop policy if exists "profiles_select_admin" on public.profiles;
-- drop function if exists public.is_current_user_admin();
-- (Rollback restores the pre-061 behaviour: directory limited to own row.)
-- ============================================================================


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 062_products_color_name.sql
-- ────────────────────────────────────────────────────────────
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


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 063_profiles_keyset_index.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================================
-- 063_profiles_keyset_index.sql — index for the admin directory's keyset walk
-- ============================================================================
-- Provenance: owner-requested follow-up to the customer-directory paging work
-- (branch feat/admin-customer-tier). The directory stopped reading a silent
-- `limit(500)` and started walking keyset pages; this makes that walk
-- index-backed instead of sort-backed.
--
-- Problem
-- -------
-- SupabaseAdminRepository.fetchCustomers asks for profiles ordered
-- newest-first by `(created_at DESC, id DESC)` and resumes each page with
--     created_at < :ts OR (created_at = :ts AND id < :id)
-- (see `customerKeysetFilter` in
-- lib/features/admin/data/supabase_admin_repository.dart).
--
-- public.profiles currently carries ONLY its primary key
-- (001_initial_schema.sql). Nothing serves that ordering, so Postgres sorts the
-- matching rows on every page request. On an empty or 25-row table that is
-- invisible; it is the shape of thing that stops being invisible at a few
-- hundred thousand rows.
--
-- Correctness is NOT affected. Keyset paging is correct with or without this
-- index — this is a performance change only, which is why it is a separate
-- migration that can land, or be rejected, on its own.
--
-- Why `(created_at DESC, id DESC)` and not `created_at` alone
-- ----------------------------------------------------------
-- The sort key has to be TOTAL, because `created_at` is not unique: a seed, a
-- bulk import, or two signups in the same clock tick all share an instant, and
-- ordering by the instant alone leaves those ties unordered between queries.
-- Both columns are listed in the same direction as the ORDER BY so the index
-- satisfies the ordering directly; a single-column index would still have to
-- sort the ties, and could not serve the `id < :id` tie-break predicate at all.
--
-- Directed DESC to match the client's ORDER BY. A plain ASC index would be
-- usable by a backward scan, but matches the request as written, which is what
-- an EXPLAIN can be read against.
--
-- Why no NULLS LAST
-- -----------------
-- profiles.created_at is `TIMESTAMPTZ NOT NULL DEFAULT now()`
-- (001_initial_schema.sql, line 17), so null placement cannot arise and the
-- client's `nullsFirst: false` is served by a plain DESC index. If that column
-- is ever made nullable, revisit this — a keyset cursor and a NULL-bearing sort
-- key do not mix (000/063 both assume a strict total order).
--
-- Why not CONCURRENTLY
-- --------------------
-- CREATE INDEX CONCURRENTLY cannot run inside a transaction block, and tooling
-- applies each migration in one. At today's row counts a plain build is
-- instant. A table large enough to need CONCURRENTLY would need this index
-- built out-of-band instead, not by editing this statement.
--
-- Why no trigram/serving column for the search
-- --------------------------------------------
-- Deliberately out of scope here. fetchCustomers' `ilike '%term%'` search on
-- full_name/phone cannot use a btree index; the analogous fix is a pg_trgm GIN
-- index (there is precedent: idx_products_name_trgm, 055_search_suggestions).
-- That is a separate decision about search cost, not about this walk, so it is
-- left for the owner rather than smuggled into a keyset-paging change.
--
-- Rollback
-- --------
-- DROP INDEX IF EXISTS public.idx_profiles_created_at_id;
-- (Rollback restores the pre-063 plan: one sort per page request. No data
-- change either way.)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_profiles_created_at_id
  ON public.profiles (created_at DESC, id DESC);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 064_profiles_search_trgm_index.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================================
-- 064_profiles_search_trgm_index.sql — REVIEW-GATED PROPOSAL
-- ============================================================================
-- Owner review required before applying (AGENTS.md migration gate).
-- Provenance: owner-requested follow-up on branch feat/admin-customer-tier,
-- after the customer directory's search moved server-side (d9ffb92) and started
-- running on every debounced keystroke.
--
-- Problem
-- -------
-- SupabaseAdminRepository.fetchCustomers searches with a LEADING wildcard:
--     full_name.ilike.'%term%'   (OR  phone.ilike.'%term%')
-- (see `customerSearchFilter` in
-- lib/features/admin/data/supabase_admin_repository.dart).
--
-- A pattern that begins with `%` cannot use a btree index, and public.profiles
-- has no index on either column, so every search is a sequential scan of the
-- whole table. Search is debounced (300ms), so this is not one scan per
-- keystroke, but it is still one scan per typing pause — and it grows with the
-- table rather than with the number of matches.
--
-- Fix
-- ---
-- A trigram GIN index on `full_name`, matching the precedent in
-- 055_search_suggestions.sql (idx_products_name_trgm, created for exactly this
-- shape of query). Between those two migrations the pattern is already
-- established in this repo.
--
-- SCOPE — why only `full_name`, and not `phone`
-- -------------------------------------------
-- An earlier revision of this migration also indexed `phone`. That index has
-- been DROPPED from it as vestigial, on the owner's call, because 065 changed
-- which column a phone search reads. The routing is:
--
--   phone-SHAPED term  (digits and phone punctuation only) -> phone_digits
--   anything else      (contains a letter or symbol)       -> phone, literal
--
-- So `phone` is now reached only by a term that is NOT phone-shaped yet still
-- appears in a stored number — in practice "the admin pasted the stored value
-- verbatim, letters and all". Digits, which is how a number is actually read
-- back, never land there. Indexing a column that routine queries no longer
-- touch costs write amplification on every signup and profile edit for a path
-- that is rare by construction.
--
-- The capability does narrow, deliberately: a paste of the STORED VALUE with
-- its separators is still matched (that term is phone-shaped, so it goes to
-- `phone_digits`, which is indexed), but a paste containing letters is matched
-- by an unindexed scan of `phone`. Accepting a seq scan on a rare path is the
-- trade being made.
--
-- `phone_digits` carries its own trigram index — see 065, which cannot be
-- folded in here because the column does not exist until that migration runs.
--
-- Be precise about what `gin_trgm_ops` does and does not give:
--   * It DOES accelerate `ILIKE '%x%'` — leading wildcards are the case a
--     trigram index exists for. (Measured: see the planner check in
--     supabase/tests/keyset-proof/, which shows the plan switching to a bitmap
--     index scan once the table is large enough for the planner to care.)
--   * It DOES NOT help patterns with fewer than 3 extractable characters.
--     `'%ab%'` yields no trigrams, so a 1- or 2-character search still scans.
--     That is a real limit of the technique, not a misconfiguration, and it is
--     why the directory's own debounce still matters.
--   * It adds write cost to profiles. That trade is cheap here: profiles are
--     written on signup and on profile edit, and searched on every typing
--     pause.
--   * It has no NULL to be silent about here: `full_name` is
--     NOT NULL DEFAULT '' (001_initial_schema.sql), so every row is indexed.
--     The equivalent hazard in 065 is avoided by COALESCE-ing `phone` to ''
--     rather than leaving the generated column NULL.
--
-- The companion migration — 065
-- ----------------------------
-- 065_profiles_phone_digits.sql adds a generated `phone_digits` column so a
-- digit-only search can match a stored value containing separators, AND
-- transliterates Arabic-Indic digits so a customer who typed ٠١٢… is reachable
-- at all. It ships that column's own trigram index. Which columns a search
-- actually reads, and why `phone` is no longer one of them for digit terms, is
-- in SCOPE above.
--
-- Why not CONCURRENTLY
-- --------------------
-- CREATE INDEX CONCURRENTLY cannot run inside a transaction block, and tooling
-- applies each migration in one. At today's row counts a plain build is
-- instant. A table large enough to need CONCURRENTLY would need these built
-- out-of-band instead, not by editing these statements.
--
-- Rollback
-- --------
-- DROP INDEX IF EXISTS public.idx_profiles_full_name_trgm;
-- (The pg_trgm extension is left in place — 055 depends on it.)
-- Rollback restores the pre-064 plan for the NAME search only. The digit search
-- is unaffected either way: its index belongs to 065. No data change.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Case-insensitive substring search on the customer's name. This is the only
-- index this migration creates — see SCOPE for why `phone` was dropped.
CREATE INDEX IF NOT EXISTS idx_profiles_full_name_trgm
  ON public.profiles USING gin (full_name gin_trgm_ops);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 065_profiles_phone_digits.sql
-- ────────────────────────────────────────────────────────────
-- ============================================================================
-- 065_profiles_phone_digits.sql — REVIEW-GATED PROPOSAL
-- ============================================================================
-- Owner review required before applying (AGENTS.md migration gate).
-- Provenance: owner-requested follow-up on branch feat/admin-customer-tier.
-- Closes the residual recorded in 064's "Interaction with phone normalisation"
-- section, in STATE.md, and in the PR description.
--
-- Problem
-- -------
-- `profiles.phone` is raw TEXT captured from auth metadata
-- (003_auth_profiles_and_hardening.sql reads
-- `NEW.raw_user_meta_data->>'phone'`), so it stores whatever the customer
-- typed: '+966 50 123 4567', '050-123-4567', '(010) 987-6543'. Nothing in this
-- repo normalises it — there is no write-time trigger and no client-side
-- reformat.
--
-- The admin directory's search matches that column literally:
--     phone.ilike.'%<term>%'
-- (see `customerSearchFilter` in
-- lib/features/admin/data/supabase_admin_repository.dart). So an admin who
-- types a bare digit run — which is how a phone number is normally read back
-- and searched — matches NOTHING whenever the stored value carries separators.
-- The search looks broken while being technically correct, and the admin has no
-- way to tell the difference between "no such customer" and "the customer's
-- number has spaces in it".
--
-- Fix
-- ---
-- A STORED generated column holding the digits of `phone`, giving the query a
-- punctuation-free column to match a digit-only term against.
--
-- Generated rather than trigger-maintained because Postgres then owns the
-- invariant: `phone_digits` cannot drift from `phone`, no write path has to
-- remember to maintain it, and clients cannot write it at all (a generated
-- column rejects INSERT/UPDATE, so this cannot be used to smuggle a value past
-- RLS).
--
-- Design notes
-- ------------
-- * Expression: COALESCE(phone, '') first, then strip every non-digit.
--   COALESCE is load-bearing, not defensive: without it a NULL `phone` makes
--   the generated value NULL, and a NULL is not "no digits" — it is a
--   comparison that can never be true. With it, a row that has no phone yields
--   '' and simply never matches a digit term, which is the correct outcome.
-- * `regexp_replace(text, text, text, text)` and `translate(text, text, text)`
--   are both IMMUTABLE in PostgreSQL 15, which STORED requires. Not taken on
--   trust: the probe in supabase/tests/keyset-proof/ applies this exact
--   statement against a live PostgreSQL 15.19 instance (postgres:15-alpine,
--   matching this project's pinned major_version) and then READS THE COMPUTED
--   VALUES BACK, so a non-immutable expression would fail at the ALTER and a
--   wrong expression would fail the read-back rather than reach production.
-- * The `translate` tables are GENERATED, not hand-written: 75 blocks x 10
--   codepoints is 750 characters of exotic Unicode, and a wrong entry does not
--   merely miss a match — it CORRUPTS the stored value. They are emitted by
--   supabase/tests/gen_phone_digit_ranges.py from Python's `unicodedata` (the
--   Unicode database), which also asserts the structural facts the SQL
--   depends on: every block starts at digit value 0, values map positionally
--   (base + i -> i), and no block appears twice. The TO table is
--   `repeat('0123456789', N)` rather than a second literal, so it cannot fall
--   out of alignment with the FROM table. Re-run with --verify to check the
--   shipped artifacts still agree with the Unicode database.
-- * Column name matches the one 064's header already anticipates.
-- * NOT added to the client's SELECT list. The directory filters on this column
--   but never displays it — `phone` stays the value the admin sees. Returning
--   both would be the same PII twice.
-- Native digits of EVERY script — the same defect, generalised
-- ------------------------------------------------------------
-- The strip is `[^0-9]`, which is ASCII-only. A customer who entered ٠١٠١٢٣٤٥٦٧٨
-- does NOT get a `phone_digits` that keeps the digits differently — Postgres
-- DELETES every one of them, and the column comes out EMPTY. So the row is
-- unreachable by any digit search at all, including an ASCII one typed by an
-- admin who knows nothing about the encoding.
--
-- That is a strictly worse failure than the separator one this migration was
-- written for, and it is why the expression transliterates BEFORE it strips:
-- `translate` maps the digit characters to ASCII, and the strip then has ASCII
-- digits left to keep. This is why the order of the two calls is load-bearing
-- rather than stylistic.
--
-- EVERY Unicode Nd (decimal digit) block is mapped, not only the Arabic ones:
-- Arabic-Indic (U+0660–U+0669), Extended Arabic-Indic (U+06F0–U+06F9),
-- Devanagari (U+0966–U+096F), Thai (U+0E50–U+0E59), fullwidth (U+FF10–U+FF19),
-- the five Mathematical Alphanumeric digit blocks, and every other Nd block in
-- Unicode 16.0.0 — 75 in all. Digit systems are not confined to Arabic script,
-- and a table covering only the ranges the author had heard of would reproduce
-- this exact bug for a customer who typed a number in any of the others. The
-- full list lives in the generated region below; the generator is the source
-- of truth, not this prose.
--
-- `translate(text, text, text)` and `repeat(text, int)` are IMMUTABLE, so the
-- generated column accepts them. Not taken on trust either — the ALTER below
-- is what proves it, and the harness reads the computed values back.
--
-- ORDERING COUPLING — read before deploying the matching client build
-- ------------------------------------------------------------------
-- The client build on this branch emits `phone_digits.ilike.'%…%'` for a
-- phone-shaped search term. PostgREST answers an unknown column with
-- `42703`/HTTP 400, i.e. THE WHOLE DIRECTORY REQUEST FAILS, not just the phone
-- branch of the search. So this migration must be applied BEFORE that client
-- build ships. Pairing already exists in this branch (the tier control calls
-- `admin_set_membership_tier` from 046), so the deploy order is: migrations
-- 063–065, then the app.
--
-- Cost
-- ----
-- ADD COLUMN … STORED rewrites `profiles` and holds ACCESS EXCLUSIVE for the
-- duration. At today's row counts that is a blink; on a large table this would
-- need an out-of-band build instead of a plain statement in a migration.
--
-- ⚠️ `IF NOT EXISTS` does NOT cover the expression
-- ------------------------------------------------
-- `ADD COLUMN IF NOT EXISTS` makes the STATEMENT idempotent, not the column
-- DEFINITION. If this migration has already been applied anywhere with an
-- earlier revision of the expression, re-running it is a silent no-op and the
-- column keeps the OLD expression — with no error, and the only visible
-- symptom being searches that quietly miss rows. This is exactly how the
-- Arabic-Indic transliteration below could fail to take effect on a database
-- where a pre-transliteration 065 was already applied. Check first:
--     select pg_get_expr(d.adbin, d.adrelid)
--       from pg_attrdef d join pg_attribute a
--         on a.attrelid = d.adrelid and a.attnum = d.adnum
--      where d.adrelid = 'public.profiles'::regclass
--        and a.attname = 'phone_digits';
-- If it does not mention `translate`, drop and re-add the column (see Rollback,
-- then apply 065 again). Verified NOT yet applied anywhere, so today the plain
-- statement is correct as written.
--
-- Rollback
-- --------
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS phone_digits;
-- (Dropping the column drops idx_profiles_phone_digits_trgm with it.)
-- Rollback restores the pre-065 behaviour: a digit-only search again matches
-- nothing when the stored number has separators. No other data changes either
-- way — `phone` is never modified by this migration.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- The digits of `phone`, with every separator removed. Read-only, server-owned.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_digits TEXT
  GENERATED ALWAYS AS (
    regexp_replace(
      -- TRANSLITERATE FIRST, then strip. The order is the whole point: the
      -- strip is `[^0-9]`, i.e. ASCII-only, so native digits are not "not a
      -- digit" in a way it can keep — they are characters it DELETES.
-- unicode-digit-tables:generated — do not edit by hand
      -- 75 non-ASCII Nd blocks, unicodedata 16.0.0; regenerate with
      --   python3 supabase/tests/gen_phone_digit_ranges.py --apply
      translate(
        COALESCE(phone, ''),
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹߀߁߂߃߄߅߆߇߈߉०१२३४५६७८९০১২৩৪৫৬৭৮৯੦੧੨੩੪੫੬੭੮੯૦૧૨૩૪૫૬૭૮૯୦୧୨୩୪୫୬୭୮୯௦௧௨௩௪௫௬௭௮௯౦౧౨౩౪౫౬౭౮౯೦೧೨೩೪೫೬೭೮೯൦൧൨൩൪൫൬൭൮൯෦෧෨෩෪෫෬෭෮෯๐๑๒๓๔๕๖๗๘๙໐໑໒໓໔໕໖໗໘໙༠༡༢༣༤༥༦༧༨༩၀၁၂၃၄၅၆၇၈၉႐႑႒႓႔႕႖႗႘႙០១២៣៤៥៦៧៨៩᠐᠑᠒᠓᠔᠕᠖᠗᠘᠙᥆᥇᥈᥉᥊᥋᥌᥍᥎᥏᧐᧑᧒᧓᧔᧕᧖᧗᧘᧙᪀᪁᪂᪃᪄᪅᪆᪇᪈᪉᪐᪑᪒᪓᪔᪕᪖᪗᪘᪙᭐᭑᭒᭓᭔᭕᭖᭗᭘᭙᮰᮱᮲᮳᮴᮵᮶᮷᮸᮹᱀᱁᱂᱃᱄᱅᱆᱇᱈᱉᱐᱑᱒᱓᱔᱕᱖᱗᱘᱙꘠꘡꘢꘣꘤꘥꘦꘧꘨꘩꣐꣑꣒꣓꣔꣕꣖꣗꣘꣙꤀꤁꤂꤃꤄꤅꤆꤇꤈꤉꧐꧑꧒꧓꧔꧕꧖꧗꧘꧙꧰꧱꧲꧳꧴꧵꧶꧷꧸꧹꩐꩑꩒꩓꩔꩕꩖꩗꩘꩙꯰꯱꯲꯳꯴꯵꯶꯷꯸꯹０１２３４５６７８９𐒠𐒡𐒢𐒣𐒤𐒥𐒦𐒧𐒨𐒩𐴰𐴱𐴲𐴳𐴴𐴵𐴶𐴷𐴸𐴹𐵀𐵁𐵂𐵃𐵄𐵅𐵆𐵇𐵈𐵉𑁦𑁧𑁨𑁩𑁪𑁫𑁬𑁭𑁮𑁯𑃰𑃱𑃲𑃳𑃴𑃵𑃶𑃷𑃸𑃹𑄶𑄷𑄸𑄹𑄺𑄻𑄼𑄽𑄾𑄿𑇐𑇑𑇒𑇓𑇔𑇕𑇖𑇗𑇘𑇙𑋰𑋱𑋲𑋳𑋴𑋵𑋶𑋷𑋸𑋹𑑐𑑑𑑒𑑓𑑔𑑕𑑖𑑗𑑘𑑙𑓐𑓑𑓒𑓓𑓔𑓕𑓖𑓗𑓘𑓙𑙐𑙑𑙒𑙓𑙔𑙕𑙖𑙗𑙘𑙙𑛀𑛁𑛂𑛃𑛄𑛅𑛆𑛇𑛈𑛉𑛐𑛑𑛒𑛓𑛔𑛕𑛖𑛗𑛘𑛙𑛚𑛛𑛜𑛝𑛞𑛟𑛠𑛡𑛢𑛣𑜰𑜱𑜲𑜳𑜴𑜵𑜶𑜷𑜸𑜹𑣠𑣡𑣢𑣣𑣤𑣥𑣦𑣧𑣨𑣩𑥐𑥑𑥒𑥓𑥔𑥕𑥖𑥗𑥘𑥙𑯰𑯱𑯲𑯳𑯴𑯵𑯶𑯷𑯸𑯹𑱐𑱑𑱒𑱓𑱔𑱕𑱖𑱗𑱘𑱙𑵐𑵑𑵒𑵓𑵔𑵕𑵖𑵗𑵘𑵙𑶠𑶡𑶢𑶣𑶤𑶥𑶦𑶧𑶨𑶩𑽐𑽑𑽒𑽓𑽔𑽕𑽖𑽗𑽘𑽙𖄰𖄱𖄲𖄳𖄴𖄵𖄶𖄷𖄸𖄹𖩠𖩡𖩢𖩣𖩤𖩥𖩦𖩧𖩨𖩩𖫀𖫁𖫂𖫃𖫄𖫅𖫆𖫇𖫈𖫉𖭐𖭑𖭒𖭓𖭔𖭕𖭖𖭗𖭘𖭙𖵰𖵱𖵲𖵳𖵴𖵵𖵶𖵷𖵸𖵹𜳰𜳱𜳲𜳳𜳴𜳵𜳶𜳷𜳸𜳹𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡𝟢𝟣𝟤𝟥𝟦𝟧𝟨𝟩𝟪𝟫𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿𞅀𞅁𞅂𞅃𞅄𞅅𞅆𞅇𞅈𞅉𞋰𞋱𞋲𞋳𞋴𞋵𞋶𞋷𞋸𞋹𞓰𞓱𞓲𞓳𞓴𞓵𞓶𞓷𞓸𞓹𞗱𞗲𞗳𞗴𞗵𞗶𞗷𞗸𞗹𞗺𞥐𞥑𞥒𞥓𞥔𞥕𞥖𞥗𞥘𞥙🯰🯱🯲🯳🯴🯵🯶🯷🯸🯹',
        repeat('0123456789', 75)
      ),
-- unicode-digit-tables:end
      '[^0-9]', '', 'g'
    )
  )
  STORED;

-- Digit-only searches match this column with a LEADING wildcard, exactly as
-- 064's indexes serve the name search, so it needs the same trigram treatment.
-- Without it, every phone-shaped search is a sequential scan — and digits are
-- the *common* case, which would make 064's benefit the rarer half.
--
-- Measured at 20 127 rows (the planner check in supabase/tests/keyset-proof/),
-- searching for a run that matches 100 of them:
--   without this index   Seq Scan, 20 027 rows removed by filter, 288 buffers
--   with this index      Bitmap Index Scan, 106 buffers
-- Buffers rather than wall-clock are the scale-relevant number: 12.5 ms →
-- 2.8 ms is not the point, 288 pages → 106 is.
CREATE INDEX IF NOT EXISTS idx_profiles_phone_digits_trgm
  ON public.profiles USING gin (phone_digits gin_trgm_ops);


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 066_coupon_checkout_and_validate_lockdown.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════
-- 066: coupons end-to-end + validate_coupon lockdown
--
-- Closes OWNER_ACTIONS.md Issues 1 + 2 (P1 money path / P1 security).
-- Promoted from docs/proposals/066_coupon_checkout_and_validate_lockdown.sql
-- (drafted + live-premise-verified 2026-09-23; autonomy grant: "finish the
-- app, proceed without waiting for confirmation").
--
-- Live evidence on staging (2026-09-23, pre-deploy probes):
--   Issue 1: POST /rest/v1/rpc/create_checkout_order with p_coupon_code
--     as an authenticated user -> PGRST202 (no function accepts that
--     parameter). Every coupon-attached checkout fails at runtime.
--   Issue 2: POST /rest/v1/rpc/validate_coupon with the anon key -> HTTP
--     200. The function is an unauthenticated code-enumeration oracle.
--
-- Issue 1 (P1 money path): the client sends `p_coupon_code` to
--   create_checkout_order (checkout_service.dart), but no applied
--   migration declares the parameter — Postgres rejects the unknown
--   named argument, so EVERY coupon checkout fails at runtime today.
--   This migration merges the review-gated coupon section of 056
--   (which was never inlined) into the CURRENT function body (047,
--   which carries 013/020/021/026 verbatim). Money math stays
--   server-owned: an invalid code must NOT block the order — it
--   simply applies no discount (056 reviewer note #2).
--
-- Issue 2 (P1 security): 056 granted EXECUTE on validate_coupon to
--   `anon, authenticated` — an unauthenticated code-enumeration
--   oracle on the money path. Locked to `authenticated` only and
--   throttled through the existing 060 rate_limit_take infrastructure
--   (per-user bucket, 20 takes / 60 s). The client only calls
--   validate_coupon from inside authenticated checkout
--   (coupon_card.dart), so the anon revoke changes no UX today.
--
-- Overload note: adding the 5th parameter creates a NEW function
-- identity. The old 4-arg overload is intentionally KEPT so older
-- app builds (which omit p_coupon_code) keep resolving it — both are
-- authenticated-only. A later migration can
-- `DROP FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT);`
-- once old builds age out.
--
-- Post-apply checklist (staging, then prod):
--   1. `\df+ create_checkout_order` — both overloads present, 5-arg
--      grants = authenticated only.
--   2. As anon: `select validate_coupon('X');` → permission denied.
--   3. As authenticated: 21 validate_coupon calls in a minute → the
--      21st raises 'Too many coupon checks'.
--   4. Checkout with a valid coupon → order row carries coupons_id +
--      coupon_discount_minor, total = max(subtotal+shipping-D, 0),
--      COD payment row created at the discounted total.
--   5. Checkout with a bogus coupon → order still placed, discount 0.
--
-- Rollback: the pre-066 bodies of create_checkout_order (4-arg) and
-- validate_coupon are migration 047 and 056 respectively — re-apply
-- those definitions to revert. No data is touched by this migration.
-- ═══════════════════════════════════════════════════════════════════

-- ─── Issue 1: create_checkout_order + p_coupon_code ────────────────
-- Body = 047 verbatim with the 056 §reviewer-note deltas:
--   1. new parameter  `p_coupon_code text DEFAULT NULL`,
--   2. coupon resolved AFTER shipping + premium perk (discount hits
--      the full total), floored at zero,
--   3. order row stores `coupons_id` + `coupon_discount_minor`,
--   4. RPC response exposes `coupon_discount_minor` (additive; the
--      client ignores unknown keys).

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL,
  p_coupon_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires    TIMESTAMPTZ;
  v_existing_coupon_discount INTEGER;
  v_order_items_to_insert JSONB := '[]'::JSONB;
  v_is_cod       BOOLEAN;
  v_coupon_id     UUID;
  v_coupon_discount INTEGER := 0;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ─── Validate payment method ─────────────────────────────
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- ─── Validate items ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- ─── Validate address ────────────────────────────────────
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- ─── Idempotency: return existing order if key matches ───
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at, coupon_discount_minor
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires,
           v_existing_coupon_discount
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true,
        'coupon_discount_minor', COALESCE(v_existing_coupon_discount, 0)
      );
    END IF;
  END IF;

  -- ─── Validate items, read DB prices, check stock ────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- Look up variant and product in one query
    SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
      INTO v_variant_id, v_stock, v_unit_price, v_product_name
      FROM product_variants pv
      JOIN products p ON p.id = pv.product_id
      WHERE pv.product_id = v_product_id
        AND pv.size = v_size
        AND pv.color = v_color
        AND pv.is_active = true
        AND p.is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
    END IF;

    IF v_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
        v_product_name, v_size, v_color, v_stock;
    END IF;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    -- Collect validated item for later insert
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- ─── Calculate shipping from shipping-zone logic ────────
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);

  -- ─── Premium perk: free shipping (migration 047) ────────
  -- Read from the profile row, never from the request. Applied
  -- AFTER the zone calculation so the free-shipping threshold,
  -- zone fees, and config fallbacks keep working for everyone
  -- else exactly as before.
  IF (SELECT membership_tier FROM profiles WHERE id = v_user_id) = 'premium' THEN
    v_shipping := 0;
  END IF;

  v_total    := v_subtotal + v_shipping;

  -- ─── Coupon: server-owned discount (056 §8, merged here) ─
  -- Resolved AFTER shipping + premium so the discount applies to
  -- the full total. Unknown/expired code => no exception, no
  -- discount (order still placed). Floored at zero.
  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT c.id, c.discount_minor
      INTO v_coupon_id, v_coupon_discount
      FROM coupons c
     WHERE upper(trim(c.code)) = upper(trim(p_coupon_code))
       AND c.active
       AND (c.expires_at IS NULL OR c.expires_at > now())
     LIMIT 1;

    IF NOT FOUND THEN
      v_coupon_id := NULL;
      v_coupon_discount := 0;
    END IF;

    v_total := GREATEST(v_total - v_coupon_discount, 0);
  END IF;

   -- ─── Compute expiry ──────────────────────────────────────
   v_expires_at := now() + interval '15 minutes';

   -- ─── Ensure a profile exists ──────────────────────────
   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   -- ─── Insert order (atomic with the rest) ─────────────────
   BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at,
      coupons_id, coupon_discount_minor
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now(),
      v_coupon_id, v_coupon_discount
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at, coupon_discount_minor
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires,
           v_existing_coupon_discount
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
       'expires_at', v_existing_expires,
       'idempotent', true,
       'coupon_discount_minor', COALESCE(v_existing_coupon_discount, 0)
     );
  END;

  -- ─── Insert order items + decrement stock ────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    UPDATE product_variants
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- ─── Clear the user's server-side cart ──────────────────
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- ═══════════════════════════════════════════════════════
  -- Create pending COD payment row for COD orders
  -- ═══════════════════════════════════════════════════════
  -- confirm_cod_payment rejects with payment_not_found, so COD
  -- orders need their pending payment row created here.
  -- (amount = v_total, i.e. already coupon-discounted.)
  v_is_cod := p_payment_method ILIKE '%cash%'
           OR p_payment_method ILIKE '%cod%';

  IF v_is_cod THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (v_order_id, v_user_id, 'cash_on_delivery', v_total, 'pending');
  END IF;

  -- ─── Return the canonical order data ─────────────────────
  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false,
    'coupon_discount_minor', v_coupon_discount
  );
END;
$$;

-- New overload: authenticated only (019/024 posture, same as 047).
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) TO authenticated;

-- ─── Issue 2: validate_coupon — anon lockdown + throttle ───────────
-- Same return shape (coupon_mapper.dart is untouched). STABLE →
-- VOLATILE because it now takes a rate-limit token (writes to
-- public.rate_limits via the 060 SECURITY DEFINER helper).
-- Bucket is per-user; 20 checks / 60 s is far above human typing
-- pace and far below useful enumeration pace.

CREATE OR REPLACE FUNCTION public.validate_coupon(p_code text)
RETURNS TABLE (code text, discount_minor integer, description text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.rate_limit_take(
       'validate_coupon:' || COALESCE(auth.uid()::text, 'anon'),
       20, 60) THEN
    RAISE EXCEPTION 'Too many coupon checks — retry in a minute'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT c.code, c.discount_minor, c.description
  FROM public.coupons c
  WHERE upper(trim(c.code)) = upper(trim(p_code))
    AND c.active
    AND (c.expires_at IS NULL OR c.expires_at > now())
  LIMIT 1;
END;
$$;

-- Lockdown: anon loses the oracle (056 had granted anon + authenticated).
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_coupon(text) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 067_lock_external_lineage_tables.sql
-- ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════
-- 067: lock the external-lineage tables (notifications, analytics_events)
--
-- Closes OWNER_ACTIONS.md Issue 6 (RLS parity) from the 2026-09-21
-- security audit, section "external-lineage tables".
--
-- Background: `analytics_events` and `notifications` were created on the
-- linked database by migrations 048–051 whose SQL files were never
-- committed to this repo (048–051 stubs document them). Objects created
-- through the SQL editor default to GRANT ALL ... TO anon, authenticated
-- and — as the audit proved for the policy half — RLS state is unknown.
--
-- Live evidence on staging (2026-09-23, pre-deploy probes, anon key):
--   analytics_events:
--     - GET  -> 200 [] (rows filtered or empty)
--     - INSERT -> 42501 "new row violates row-level security policy"
--       => RLS is ENABLED and the 053 insert-own posture is effective.
--   notifications:
--     - GET  -> 200 [] (rows filtered or empty)
--     - INSERT -> PGRST204 "Could not find the 'probe' column" — the
--       insert reached the table's column resolution, i.e. NO RLS
--       violation was raised => RLS is OFF with permissive default
--       grants. Any authenticated (and possibly anon) client can read
--       the notification log — a silent PII exposure per the audit.
--
-- No client feature reads `notifications` (grep 2026-09-23: zero
-- `from('notifications')` call sites in lib/ — push is handled natively
-- by OneSignal and order-status notifications are client-local §12), so
-- an admin-read-only policy breaks nothing.
--
-- Rollback:
--   DROP POLICY IF EXISTS notifications_admin_read ON public.notifications;
--   ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
--   GRANT ALL ON public.notifications TO anon, authenticated;
--   (analytics_events rollback: DISABLE ROW LEVEL SECURITY — not
--   recommended; it reopens world-writable analytics.)
-- ═══════════════════════════════════════════════════════════════════

-- ─── notifications: enable RLS + admin-read-only ───────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_admin_read ON public.notifications;
CREATE POLICY notifications_admin_read ON public.notifications
  FOR SELECT
  USING (public.is_current_user_admin());

-- Lockdown: nobody reads or writes through PostgREST except
-- authenticated, and the policy above filters SELECT to admins only.
-- The service role (edge functions / server jobs) bypasses RLS and
-- keeps its own grants, so server-side writers are unaffected.
REVOKE ALL ON public.notifications FROM anon;
REVOKE ALL ON public.notifications FROM authenticated;
GRANT SELECT ON public.notifications TO authenticated;

-- ─── analytics_events: idempotent parity ───────────────────────────
-- Already ENABLED on staging (proven live above). Stated explicitly so
-- prod — whose RLS state was never proven — converges to the same
-- posture. The 053 policies (analytics_insert_own + admin aggregate)
-- remain the operative policy set.
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 068_admin_catalog_rpc_extension.sql
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_upsert_product(
  p_id UUID,
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_composition TEXT,
  p_category_id UUID,
  p_base_price NUMERIC,
  p_is_active BOOL,
  p_care TEXT DEFAULT NULL,
  p_origin TEXT DEFAULT NULL,
  p_width_cm INTEGER DEFAULT NULL,
  p_gsm INTEGER DEFAULT NULL,
  p_sell_by_length BOOLEAN DEFAULT NULL,
  p_min_cut_meters NUMERIC DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM public.assert_admin();

  IF p_name IS NULL OR btrim(p_name) = '' OR p_slug IS NULL OR btrim(p_slug) = '' THEN
    RAISE EXCEPTION 'invalid_product_identity' USING ERRCODE = '22023';
  END IF;
   IF p_base_price IS NULL
      OR p_base_price <= 0
      OR p_base_price::TEXT IN ('NaN', 'Infinity', '-Infinity')
      OR p_base_price <> trunc(p_base_price) THEN
     RAISE EXCEPTION 'invalid_product_price' USING ERRCODE = '22023';
   END IF;
   IF p_width_cm IS NOT NULL
      AND (p_width_cm::TEXT IN ('NaN', 'Infinity', '-Infinity')
           OR p_width_cm < 50 OR p_width_cm > 400) THEN
     RAISE EXCEPTION 'invalid_product_width' USING ERRCODE = '22023';
   END IF;
   IF p_gsm IS NOT NULL
      AND (p_gsm::TEXT IN ('NaN', 'Infinity', '-Infinity')
           OR p_gsm < 50 OR p_gsm > 1500) THEN
     RAISE EXCEPTION 'invalid_product_gsm' USING ERRCODE = '22023';
   END IF;
   IF p_min_cut_meters IS NOT NULL
      AND (p_min_cut_meters < 0.5
           OR p_min_cut_meters > 999.9
           OR p_min_cut_meters::TEXT IN ('NaN', 'Infinity', '-Infinity')) THEN
     RAISE EXCEPTION 'invalid_product_min_cut' USING ERRCODE = '22023';
   END IF;
   IF COALESCE(p_sell_by_length, false)
      AND p_min_cut_meters IS NULL THEN
     RAISE EXCEPTION 'invalid_product_min_cut' USING ERRCODE = '22023';
   END IF;

  IF p_id IS NULL THEN
    INSERT INTO products (
      name, slug, description, composition, care, origin, category_id,
      base_price, is_active, width_cm, gsm, sell_by_length, min_cut_meters
    )
    VALUES (
      btrim(p_name), btrim(p_slug), p_description, p_composition, p_care,
      p_origin, p_category_id, p_base_price::INTEGER, COALESCE(p_is_active, true),
      p_width_cm, p_gsm, COALESCE(p_sell_by_length, false), p_min_cut_meters
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE products
       SET name = btrim(p_name),
           slug = btrim(p_slug),
           description = p_description,
           composition = p_composition,
           care = p_care,
           origin = p_origin,
           category_id = p_category_id,
           base_price = p_base_price::INTEGER,
           is_active = COALESCE(p_is_active, true),
           width_cm = p_width_cm,
           gsm = p_gsm,
           sell_by_length = COALESCE(p_sell_by_length, sell_by_length),
           min_cut_meters = p_min_cut_meters,
           updated_at = now()
     WHERE id = p_id
     RETURNING id INTO v_id;
    IF v_id IS NULL THEN
      RAISE EXCEPTION 'product_not_found' USING ERRCODE = 'P0002';
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_product(UUID, TEXT, TEXT, TEXT, TEXT, UUID, NUMERIC, BOOL, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(UUID, TEXT, TEXT, TEXT, TEXT, UUID, NUMERIC, BOOL, TEXT, TEXT, INTEGER, INTEGER, BOOLEAN, NUMERIC) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_upsert_product(UUID, TEXT, TEXT, TEXT, TEXT, UUID, NUMERIC, BOOL);

CREATE OR REPLACE FUNCTION public.admin_upsert_product(
  p_id UUID,
  p_name TEXT,
  p_slug TEXT,
  p_description TEXT,
  p_composition TEXT,
  p_category_id UUID,
  p_base_price NUMERIC,
  p_is_active BOOL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_care TEXT;
  v_origin TEXT;
  v_width_cm INTEGER;
  v_gsm INTEGER;
  v_sell_by_length BOOLEAN;
  v_min_cut_meters NUMERIC;
BEGIN
  PERFORM public.assert_admin();

  IF p_id IS NOT NULL THEN
    SELECT care, origin, width_cm, gsm, sell_by_length, min_cut_meters
      INTO v_care, v_origin, v_width_cm, v_gsm,
           v_sell_by_length, v_min_cut_meters
      FROM public.products
     WHERE id = p_id
     FOR UPDATE;
  END IF;

  RETURN public.admin_upsert_product(
    p_id, p_name, p_slug, p_description, p_composition,
    p_category_id, p_base_price, p_is_active,
    v_care, v_origin, v_width_cm, v_gsm,
    v_sell_by_length, v_min_cut_meters
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_product(UUID, TEXT, TEXT, TEXT, TEXT, UUID, NUMERIC, BOOL) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_product(UUID, TEXT, TEXT, TEXT, TEXT, UUID, NUMERIC, BOOL) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 069_product_review_security.sql
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'product_reviews_text_length_check'
      AND conrelid = 'public.product_reviews'::regclass
  ) THEN
    ALTER TABLE public.product_reviews
      ADD CONSTRAINT product_reviews_text_length_check
      CHECK (char_length(text) <= 2000);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'product_reviews_photo_path_length_check'
      AND conrelid = 'public.product_reviews'::regclass
  ) THEN
    ALTER TABLE public.product_reviews
      ADD CONSTRAINT product_reviews_photo_path_length_check
      CHECK (photo_url IS NULL OR char_length(photo_url) <= 512);
  END IF;
END;
$$;

DROP POLICY IF EXISTS reviews_insert_buyers ON public.product_reviews;

INSERT INTO storage.buckets (id, name, public)
VALUES ('review-images', 'review-images', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "review images owner read" ON storage.objects;
CREATE POLICY "review images owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'review-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.is_admin = true
      )
      OR EXISTS (
        SELECT 1 FROM public.product_reviews r
        WHERE r.photo_url = name AND r.status = 'approved'
      )
    )
  );

DROP POLICY IF EXISTS "review images owner write" ON storage.objects;
CREATE POLICY "review images owner write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'review-images'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
    AND metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
    AND COALESCE(metadata->>'size', metadata->>'contentLength') ~ '^[0-9]+$'
    AND (COALESCE(metadata->>'size', metadata->>'contentLength'))::BIGINT
        <= 5 * 1024 * 1024
  );

DROP POLICY IF EXISTS "review images owner delete" ON storage.objects;
CREATE POLICY "review images owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'review-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.is_admin = true
      )
    )
  );

CREATE OR REPLACE FUNCTION public.submit_product_review(
  p_product_id UUID,
  p_rating INTEGER,
  p_text TEXT,
  p_photo_path TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_photo_path TEXT;
  v_review public.product_reviews;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'Invalid rating' USING ERRCODE = '22023';
  END IF;
  IF p_text IS NULL OR btrim(p_text) = '' OR char_length(p_text) > 2000 THEN
    RAISE EXCEPTION 'Invalid review text' USING ERRCODE = '22023';
  END IF;
  IF p_photo_path IS NOT NULL THEN
    v_photo_path := btrim(p_photo_path);
    IF v_photo_path = ''
       OR v_photo_path !~ ('^' || v_user_id::TEXT || '/' || p_product_id::TEXT || '/') THEN
      RAISE EXCEPTION 'Invalid review photo path' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM storage.objects o
      WHERE o.bucket_id = 'review-images'
        AND o.name = v_photo_path
        AND (storage.foldername(o.name))[1] = v_user_id::TEXT
        AND (storage.foldername(o.name))[2] = p_product_id::TEXT
        AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
        AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
        AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT
            <= 5 * 1024 * 1024
    ) THEN
      RAISE EXCEPTION 'Review photo not found' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.order_items oi ON oi.order_id = o.id
    WHERE o.user_id = v_user_id
      AND o.status IN ('delivered', 'paid', 'shipped', 'processing')
      AND oi.product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'Purchase required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.product_reviews (
    product_id, user_id, rating, text, photo_url, status
  )
  VALUES (
    p_product_id, v_user_id, p_rating, btrim(p_text), v_photo_path, 'pending'
  )
  RETURNING * INTO v_review;

  RETURN to_jsonb(v_review) || jsonb_build_object(
    'author_name', COALESCE(
      (SELECT NULLIF(p.full_name, '') FROM public.profiles p WHERE p.id = v_user_id),
      'Al Batal'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_product_review(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, INTEGER, TEXT, TEXT) TO authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 070_payment_review_rate_limit_hardening.sql
-- ────────────────────────────────────────────────────────────
BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('instapay-proofs', 'instapay-proofs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

UPDATE storage.buckets
   SET public = false
 WHERE id IN ('instapay-proofs', 'review-images');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name = 'file_size_limit'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'storage'
      AND table_name = 'buckets'
      AND column_name = 'allowed_mime_types'
  ) THEN
    RAISE EXCEPTION 'Supabase Storage bucket hardening columns are unavailable';
  END IF;
END;
$$;

UPDATE storage.buckets
   SET file_size_limit = 5 * 1024 * 1024,
       allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::TEXT[]
 WHERE id IN ('instapay-proofs', 'review-images');

CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id_claim(
  p_payment_id UUID,
  p_paymob_order_id TEXT,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment RECORD;
BEGIN
  IF p_payment_id IS NULL OR p_claim_token IS NULL
     OR COALESCE(btrim(p_paymob_order_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT id, user_id, method, status, paymob_order_id,
         paymob_initiation_claim_token, paymob_initiation_phase
    INTO v_payment
    FROM public.payments
   WHERE id = p_payment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_found');
  END IF;
  IF v_payment.method <> 'paymob_card' OR v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
  END IF;
  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_set');
  END IF;
  IF v_payment.paymob_initiation_phase <> 'provider_submitted'
     OR v_payment.paymob_initiation_claim_token IS DISTINCT FROM p_claim_token THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_claim');
  END IF;

  UPDATE public.payments
     SET paymob_order_id = btrim(p_paymob_order_id),
         paymob_initiation_phase = 'provider_persisted',
         updated_at = now()
   WHERE id = p_payment_id
     AND status = 'pending'
     AND paymob_order_id IS NULL
     AND paymob_initiation_phase = 'provider_submitted'
     AND paymob_initiation_claim_token = p_claim_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_race');
  END IF;
  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id_claim(UUID, TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id_claim(UUID, TEXT, UUID) TO service_role;
REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC, anon, authenticated, service_role;

UPDATE public.payments
   SET method = 'cash_on_delivery', updated_at = now()
 WHERE method = 'cod'
   AND status = 'pending';

WITH ranked AS (
  SELECT p.id,
         row_number() OVER (
           PARTITION BY p.order_id,
             CASE
               WHEN p.method IN ('cod', 'cash_on_delivery') THEN 'cash_on_delivery'
               ELSE p.method
             END
           ORDER BY
             (EXISTS (
                SELECT 1
                FROM public.instapay_proofs ip
                WHERE ip.payment_id = p.id
                  AND ip.outcome IS NULL
             )) DESC,
             (p.paymob_order_id IS NOT NULL) DESC,
             p.created_at ASC,
             p.id ASC
         ) AS rn
    FROM public.payments p
   WHERE p.status = 'pending'
     AND p.method IN ('cod', 'cash_on_delivery', 'instapay')
)
UPDATE public.payments p
   SET status = 'cancelled', updated_at = now()
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_instapay_per_order
  ON public.payments(order_id)
  WHERE method = 'instapay' AND status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_cod_per_order
  ON public.payments(order_id)
  WHERE method IN ('cod', 'cash_on_delivery') AND status = 'pending';

CREATE OR REPLACE FUNCTION public.set_pending_order_payment_method(
  p_order_id UUID,
  p_method TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner UUID;
  v_status TEXT;
  v_method TEXT;
  v_payment_method TEXT;
  v_previous_method TEXT;
  v_current_expires_at TIMESTAMPTZ;
  v_inserted INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card', 'paymob_card', 'instapay') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;
  v_method := CASE WHEN p_method = 'card' THEN 'paymob_card' ELSE p_method END;
  v_payment_method := CASE
    WHEN v_method = 'cod' THEN 'cash_on_delivery'
    ELSE v_method
  END;

  SELECT user_id, status::TEXT, payment_method, expires_at
    INTO v_owner, v_status, v_previous_method, v_current_expires_at
    FROM public.orders
   WHERE id = p_order_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;
  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;
  IF v_current_expires_at IS NOT NULL
     AND v_current_expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  PERFORM 1
    FROM public.payments
   WHERE order_id = p_order_id
     AND status = 'pending'
   FOR UPDATE;

  IF v_method IS DISTINCT FROM 'paymob_card'
     AND EXISTS (
       SELECT 1
       FROM public.payments
       WHERE order_id = p_order_id
         AND status = 'pending'
         AND (
           paymob_order_id IS NOT NULL
           OR paymob_initiation_phase IN ('provider_submitted', 'provider_persisted')
         )
     ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_in_progress');
  END IF;

  UPDATE public.orders
     SET payment_method = v_method,
          expires_at = CASE
             WHEN v_previous_method IS DISTINCT FROM v_method
               OR v_current_expires_at IS NULL THEN
              CASE WHEN v_method = 'instapay'
                   THEN now() + interval '24 hours'
                   ELSE now() + interval '15 minutes' END
            ELSE v_current_expires_at
          END,
         updated_at = now()
   WHERE id = p_order_id;

  UPDATE public.payments
     SET status = 'cancelled', updated_at = now()
   WHERE order_id = p_order_id
     AND user_id = v_user_id
     AND status = 'pending'
     AND CASE
       WHEN method IN ('cod', 'cash_on_delivery') THEN 'cod'
       WHEN method = 'paymob_card' THEN 'paymob_card'
       WHEN method = 'instapay' THEN 'instapay'
       ELSE method
     END <> v_method
     AND NOT (
       method = 'paymob_card'
       AND (
         paymob_order_id IS NOT NULL
         OR paymob_initiation_phase IN ('provider_submitted', 'provider_persisted')
       )
     );

  IF v_method = 'cod' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, v_payment_method, total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method IN ('cod', 'cash_on_delivery')
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  ELSIF v_method = 'instapay' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'instapay', total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method = 'instapay'
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  ELSIF v_method = 'paymob_card' THEN
    INSERT INTO public.payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'paymob_card', total, 'pending'
      FROM public.orders
     WHERE id = p_order_id
       AND NOT EXISTS (
         SELECT 1 FROM public.payments
          WHERE order_id = p_order_id
            AND status = 'pending'
            AND method = 'paymob_card'
       );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', v_method,
    'payment_row_ensured', v_inserted > 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_pending_order_payment_method(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_pending_order_payment_method(UUID, TEXT) TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.instapay_proofs
    WHERE (reference IS NOT NULL AND char_length(reference) > 64)
       OR (note IS NOT NULL AND char_length(note) > 2000)
  ) THEN
    RAISE EXCEPTION 'instapay_proofs contains oversized reference or note values';
  END IF;
END;
$$;

ALTER TABLE public.instapay_proofs
  DROP CONSTRAINT IF EXISTS instapay_proofs_reference_length_check;
ALTER TABLE public.instapay_proofs
  ADD CONSTRAINT instapay_proofs_reference_length_check
  CHECK (reference IS NULL OR char_length(reference) <= 64);
ALTER TABLE public.instapay_proofs
  DROP CONSTRAINT IF EXISTS instapay_proofs_note_length_check;
ALTER TABLE public.instapay_proofs
  ADD CONSTRAINT instapay_proofs_note_length_check
  CHECK (note IS NULL OR char_length(note) <= 2000);

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY payment_id
           ORDER BY created_at DESC, id DESC
         ) AS rn
    FROM public.instapay_proofs
   WHERE outcome IS NULL
)
UPDATE public.instapay_proofs p
   SET outcome = 'rejected',
       reviewed_at = now(),
       note = COALESCE(p.note, 'Superseded duplicate proof')
  FROM ranked r
 WHERE p.id = r.id
   AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_instapay_proofs_one_pending_per_payment
  ON public.instapay_proofs(payment_id)
  WHERE outcome IS NULL;

DROP POLICY IF EXISTS "instapay_proofs_insert_own" ON public.instapay_proofs;
CREATE POLICY "instapay_proofs_insert_own"
  ON public.instapay_proofs FOR INSERT
  WITH CHECK (
    outcome IS NULL
    AND reviewed_by IS NULL
    AND reviewed_at IS NULL
    AND (storage.foldername(storage_path))[1] = auth.uid()::TEXT
    AND (storage.foldername(storage_path))[2] = payment_id::TEXT
    AND EXISTS (
      SELECT 1
      FROM public.payments p
      JOIN public.orders o ON o.id = p.order_id
      WHERE p.id = payment_id
        AND p.user_id = auth.uid()
        AND p.status = 'pending'
        AND p.method = 'instapay'
        AND o.status = 'pending'
        AND (o.expires_at IS NULL OR o.expires_at > now())
    )
    AND EXISTS (
      SELECT 1
      FROM storage.objects o
      WHERE o.bucket_id = 'instapay-proofs'
        AND o.name = storage_path
        AND (storage.foldername(o.name))[1] = auth.uid()::TEXT
        AND (storage.foldername(o.name))[2] = payment_id::TEXT
        AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
         AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
         AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT <= 5 * 1024 * 1024
    )
  );

CREATE OR REPLACE FUNCTION public.review_instapay_proof(
  p_proof_id UUID,
  p_approve BOOLEAN,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_payment RECORD;
  v_order_id UUID;
  v_method TEXT;
  v_payment_status TEXT;
  v_order_status TEXT;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;
  SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_admin;
  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, outcome INTO v_payment
    FROM public.instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;
  IF v_payment.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;

  SELECT p.order_id, p.method, p.status, o.status::TEXT
    INTO v_order_id, v_method, v_payment_status, v_order_status
    FROM public.payments p
    JOIN public.orders o ON o.id = p.order_id
   WHERE p.id = v_payment.payment_id
   FOR UPDATE OF p, o;
  IF NOT FOUND OR v_method IS DISTINCT FROM 'instapay'
     OR v_payment_status IS DISTINCT FROM 'pending'
     OR v_order_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  IF p_approve THEN
    UPDATE public.payments
       SET status = 'success',
           transaction_id = 'instapay_' || p_proof_id::TEXT,
           updated_at = now()
     WHERE id = v_payment.payment_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;
  UPDATE public.orders
       SET status = 'paid', updated_at = now()
     WHERE id = v_order_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
    END IF;
    UPDATE public.instapay_proofs
       SET outcome = 'approved', reviewed_by = v_admin,
           reviewed_at = now(), note = p_note
     WHERE id = p_proof_id;
  ELSE
    UPDATE public.payments
       SET status = 'failed', updated_at = now()
     WHERE id = v_payment.payment_id AND status = 'pending';
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;
    UPDATE public.instapay_proofs
       SET outcome = 'rejected', reviewed_by = v_admin,
           reviewed_at = now(), note = p_note
     WHERE id = p_proof_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment.payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.review_instapay_proof(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_instapay_proof(UUID, BOOLEAN, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.expire_stale_instapay_payments() TO service_role;

CREATE OR REPLACE FUNCTION public.rate_limit_take(
  p_bucket TEXT,
  p_limit INTEGER,
  p_window_seconds INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_window BIGINT := extract(epoch FROM now())::BIGINT / greatest(p_window_seconds, 1);
  v_bucket TEXT;
  v_allowed BOOLEAN;
BEGIN
  IF p_bucket IS NULL OR length(p_bucket) > 200
     OR p_bucket !~ '^(acct|init|proof|cb|validate_coupon):[A-Za-z0-9:._-]+$'
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 1000
     OR p_window_seconds IS NULL OR p_window_seconds < 1
     OR p_window_seconds > 86400 THEN
    RETURN false;
  END IF;

  v_bucket := CASE
    WHEN auth.uid() IS NOT NULL THEN split_part(p_bucket, ':', 1) || ':' || auth.uid()::TEXT
    ELSE p_bucket
  END;

  INSERT INTO public.rate_limits (bucket, window_id, count)
  VALUES (v_bucket, v_window, 1)
  ON CONFLICT (bucket, window_id)
  DO UPDATE SET count = public.rate_limits.count + 1
  WHERE public.rate_limits.count < p_limit;
  v_allowed := found;

  IF random() < 0.01 THEN
    DELETE FROM public.rate_limits
     WHERE window_id < extract(epoch FROM now())::BIGINT - 172800;
  END IF;
  RETURN v_allowed;
END;
$$;

REVOKE ALL ON FUNCTION public.rate_limit_take(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rate_limit_take(TEXT, INTEGER, INTEGER) TO authenticated, service_role;

COMMIT;



-- ────────────────────────────────────────────────────────────
-- MIGRATION: 071_query_indexes_and_sales_aggregate.sql
-- ────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_orders_user_placed_at
  ON public.orders(user_id, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_placed_at
  ON public.orders(placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status_placed_at
  ON public.orders(status, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order_product
  ON public.order_items(order_id, product_id);
CREATE INDEX IF NOT EXISTS idx_variants_stock_active
  ON public.product_variants(stock, product_id)
  WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_product_reviews_status_created_at
  ON public.product_reviews(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_order_method_status
  ON public.payments(order_id, method, status);

CREATE OR REPLACE FUNCTION public.admin_sales_overview(p_days INTEGER DEFAULT 14)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days INTEGER := greatest(least(coalesce(p_days, 14), 1), 90);
  v_start DATE := current_date - (greatest(least(coalesce(p_days, 14), 1), 90) - 1);
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
  END IF;

  WITH day_series AS (
    SELECT generate_series(
      v_start::timestamp,
      date_trunc('day', now()),
      interval '1 day'
    )::date AS day
  ),
  revenue AS (
    SELECT d.day,
           COALESCE(SUM(o.total), 0)::BIGINT AS revenue_minor
      FROM day_series d
      LEFT JOIN public.orders o
        ON o.placed_at >= d.day
       AND o.placed_at < d.day + 1
       AND o.status NOT IN ('cancelled', 'refunded')
     GROUP BY d.day
  ),
  status_rows AS (
    SELECT o.status::TEXT AS status, COUNT(*)::INTEGER AS count
      FROM public.orders o
     WHERE o.placed_at >= v_start
     GROUP BY o.status
  ),
  product_rows AS (
    SELECT oi.product_name, SUM(oi.quantity)::INTEGER AS units_sold
      FROM public.orders o
      JOIN public.order_items oi ON oi.order_id = o.id
     WHERE o.placed_at >= v_start
       AND o.status NOT IN ('cancelled', 'refunded')
     GROUP BY oi.product_name
     ORDER BY units_sold DESC, product_name
     LIMIT 5
  )
  SELECT jsonb_build_object(
    'revenue_by_day', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'day', to_char(day, 'YYYY-MM-DD'),
          'revenue_minor', revenue_minor
        ) ORDER BY day
      )
      FROM revenue
    ), '[]'::jsonb),
    'top_products', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'product_name', product_name,
          'units_sold', units_sold
        ) ORDER BY units_sold DESC
      )
      FROM product_rows
    ), '[]'::jsonb),
    'status_counts', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object('status', status, 'count', count)
        ORDER BY count DESC, status
      )
      FROM status_rows
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_sales_overview(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_sales_overview(INTEGER) TO authenticated;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 072_checkout_bounds_and_expiry.sql
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.create_checkout_order(text,jsonb,jsonb,text,text)') IS NOT NULL
     AND to_regprocedure('public.create_checkout_order_unchecked_072(text,jsonb,jsonb,text,text)') IS NULL THEN
    EXECUTE 'ALTER FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) RENAME TO create_checkout_order_unchecked_072';
  END IF;
  IF to_regprocedure('public.create_checkout_order_unchecked_072(text,jsonb,jsonb,text,text)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.create_checkout_order_unchecked_072(TEXT, JSONB, JSONB, TEXT, TEXT) FROM PUBLIC, anon, authenticated, service_role';
  END IF;
  IF to_regprocedure('public.create_checkout_order_unchecked_072(text,jsonb,jsonb,text,text)') IS NULL THEN
    RAISE EXCEPTION 'checkout_unchecked_072 is unavailable';
  END IF;
  IF to_regprocedure('public.create_checkout_order(text,jsonb,jsonb,text)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC, anon, authenticated, service_role';
    EXECUTE 'DROP FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT)';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL,
  p_coupon_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_method TEXT;
  v_item JSONB;
  v_quantity TEXT;
  v_result JSONB;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF p_payment_method IS NULL
     OR p_payment_method NOT IN ('cod', 'card', 'paymob_card', 'instapay') THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;
  v_method := CASE WHEN p_payment_method = 'card' THEN 'paymob_card' ELSE p_payment_method END;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 50
     OR octet_length(p_items::TEXT) > 100000 THEN
    RAISE EXCEPTION 'Invalid cart payload' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) item
    CROSS JOIN LATERAL (
      SELECT lower(btrim(item->>'product_id')) AS raw_id,
             regexp_replace(lower(btrim(item->>'product_id')), '[^0-9a-f]', '', 'g') AS hex_id
    ) input_id
    JOIN products p
      ON p.id = CASE
           WHEN input_id.raw_id ~* '^[{}0-9a-f-]+$'
             AND char_length(input_id.hex_id) = 32
             THEN (
               substring(input_id.hex_id FROM 1 FOR 8) || '-' ||
               substring(input_id.hex_id FROM 9 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 13 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 17 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 21 FOR 12)
             )::UUID
           ELSE NULL
         END
    WHERE p.sell_by_length
  ) THEN
    RAISE EXCEPTION 'Metered checkout is not available'
      USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION 'Invalid cart item' USING ERRCODE = '22023';
    END IF;
    v_quantity := v_item ->> 'quantity';
    IF v_quantity IS NULL OR v_quantity !~ '^[0-9]+$'
       OR (v_quantity::INTEGER < 1 OR v_quantity::INTEGER > 99) THEN
      RAISE EXCEPTION 'Invalid cart quantity' USING ERRCODE = '22023';
    END IF;
    IF v_item ? 'sample' OR v_item ? 'meters' OR v_item ? 'line_total'
       OR v_item ? 'tiered_price' THEN
      RAISE EXCEPTION 'Metered checkout is not available for this order'
        USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF p_idempotency_key IS NOT NULL
     AND (char_length(p_idempotency_key) < 1 OR char_length(p_idempotency_key) > 128) THEN
    RAISE EXCEPTION 'Invalid idempotency key' USING ERRCODE = '22023';
  END IF;
  IF p_address IS NULL
     OR octet_length(p_address::TEXT) > 4096
     OR COALESCE(btrim(p_address ->> 'recipient'), '') = ''
     OR char_length(btrim(p_address ->> 'recipient')) > 120
     OR COALESCE(btrim(p_address ->> 'line'), '') = ''
     OR char_length(btrim(p_address ->> 'line')) > 240
     OR COALESCE(btrim(p_address ->> 'city'), '') = ''
     OR char_length(btrim(p_address ->> 'city')) > 80
     OR COALESCE(btrim(p_address ->> 'phone'), '') = ''
     OR char_length(btrim(p_address ->> 'phone')) > 32
     OR btrim(p_address ->> 'phone') !~ '^\+?[0-9][0-9 ()-]{6,30}$' THEN
    RAISE EXCEPTION 'A valid shipping address with phone is required'
      USING ERRCODE = '22023';
  END IF;

  v_result := public.create_checkout_order_unchecked_072(
    v_method,
    p_address,
    p_items,
    p_idempotency_key,
    p_coupon_code
  );

  IF COALESCE((v_result ->> 'total')::INTEGER, 0) <= 0 THEN
    RAISE EXCEPTION 'Checkout total must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF v_method = 'instapay'
     AND COALESCE(v_result ->> 'idempotent', 'false') <> 'true'
     AND NULLIF(v_result ->> 'order_id', '') IS NOT NULL THEN
    v_expires_at := now() + interval '24 hours';
    UPDATE public.orders
       SET expires_at = v_expires_at
     WHERE id = (v_result ->> 'order_id')::UUID
       AND status = 'pending';
    v_result := jsonb_set(v_result, '{expires_at}', to_jsonb(v_expires_at), true);
  END IF;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) TO authenticated;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- MIGRATION: 073_payment_expiry_and_proof_integrity.sql
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.get_or_claim_paymob_payment_legacy_073(UUID)') IS NULL THEN
    IF to_regprocedure('public.get_or_claim_paymob_payment(UUID)') IS NOT NULL THEN
      ALTER FUNCTION public.get_or_claim_paymob_payment(UUID)
        RENAME TO get_or_claim_paymob_payment_legacy_073;
    END IF;
  END IF;
  IF to_regprocedure('public.process_paymob_callback_legacy_073(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)') IS NULL THEN
    IF to_regprocedure('public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)') IS NOT NULL THEN
      ALTER FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
        RENAME TO process_paymob_callback_legacy_073;
    END IF;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment_legacy_073(UUID)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.process_paymob_callback_legacy_073(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_or_claim_paymob_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = p_order_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  RETURN public.get_or_claim_paymob_payment_legacy_073(p_order_id);
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id TEXT,
  p_amount_cents INTEGER,
  p_currency TEXT,
  p_success BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_order RECORD;
BEGIN
  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE paymob_order_id = p_paymob_order_id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unmapped_payment');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;
  IF v_order.status = 'pending'
     AND v_order.expires_at IS NOT NULL
     AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_expired',
      'order_id', v_order.id
    );
  END IF;

  RETURN public.process_paymob_callback_legacy_073(
    p_paymob_order_id,
    p_paymob_txn_id,
    p_amount_cents,
    p_currency,
    p_success
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN)
  TO service_role;

CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id_claim(
  p_payment_id UUID,
  p_paymob_order_id TEXT,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_order RECORD;
  v_payment RECORD;
  v_updated_id UUID;
BEGIN
  IF p_payment_id IS NULL
     OR p_claim_token IS NULL
     OR p_paymob_order_id IS NULL
     OR btrim(p_paymob_order_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;
  IF v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pending');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  SELECT id, order_id, status, method, paymob_order_id,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM public.payments
   WHERE id = p_payment_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_found');
  END IF;
  IF v_payment.status IS DISTINCT FROM 'pending'
     OR v_payment.method IS DISTINCT FROM 'paymob_card' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pending');
  END IF;
  IF v_payment.paymob_order_id IS NOT NULL THEN
    IF v_payment.paymob_order_id = btrim(p_paymob_order_id) THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_set',
        'paymob_order_id', btrim(p_paymob_order_id)
      );
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'claim_already_submitted');
  END IF;

  UPDATE public.payments
     SET paymob_order_id = btrim(p_paymob_order_id),
         paymob_initiation_phase = 'provider_persisted',
         updated_at = now()
   WHERE id = p_payment_id
     AND status = 'pending'
     AND paymob_initiation_claim_token = p_claim_token
     AND paymob_initiation_phase = 'provider_submitted'
     AND paymob_order_id IS NULL
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_matched');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'updated',
    'paymob_order_id', btrim(p_paymob_order_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id_claim(UUID,TEXT,UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id_claim(UUID,TEXT,UUID)
  TO service_role;

CREATE OR REPLACE FUNCTION public.review_instapay_proof(
  p_proof_id UUID,
  p_approve BOOLEAN,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_proof RECORD;
  v_payment RECORD;
  v_order RECORD;
  v_payment_id UUID;
  v_order_id UUID;
  v_storage_path TEXT;
  v_note TEXT;
  v_updated_id UUID;
  v_updated_order_id UUID;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;
  IF p_proof_id IS NULL OR p_approve IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;
  IF p_note IS NOT NULL AND char_length(p_note) > 2000 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_note');
  END IF;
  v_note := NULLIF(btrim(p_note), '');

  SELECT is_admin
    INTO v_is_admin
    FROM public.profiles
   WHERE id = v_admin;
  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, storage_path, outcome
    INTO v_proof
    FROM public.instapay_proofs
   WHERE id = p_proof_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;
  IF v_proof.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;
  v_payment_id := v_proof.payment_id;
  v_storage_path := v_proof.storage_path;

  SELECT order_id
    INTO v_order_id
    FROM public.payments
   WHERE id = v_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  SELECT id, status, expires_at
    INTO v_order
    FROM public.orders
   WHERE id = v_order_id
   FOR UPDATE;
  IF NOT FOUND OR v_order.status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;
  IF v_order.expires_at IS NOT NULL AND v_order.expires_at <= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_expired');
  END IF;

  SELECT id, order_id, user_id, status, method
    INTO v_payment
    FROM public.payments
   WHERE id = v_payment_id
   FOR UPDATE;
  IF NOT FOUND
     OR v_payment.order_id IS DISTINCT FROM v_order.id
     OR v_payment.status IS DISTINCT FROM 'pending'
     OR v_payment.method IS DISTINCT FROM 'instapay' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending_instapay');
  END IF;

  SELECT payment_id, storage_path, outcome
    INTO v_proof
    FROM public.instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;
  IF NOT FOUND OR v_proof.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;
  IF v_proof.payment_id IS DISTINCT FROM v_payment_id
     OR v_proof.storage_path IS DISTINCT FROM v_storage_path THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_changed');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM storage.objects o
    WHERE o.bucket_id = 'instapay-proofs'
      AND o.name = v_storage_path
      AND (storage.foldername(o.name))[1] = v_payment.user_id::TEXT
      AND (storage.foldername(o.name))[2] = v_payment_id::TEXT
      AND o.metadata->>'mimetype' IN ('image/jpeg', 'image/png', 'image/webp')
       AND COALESCE(o.metadata->>'size', o.metadata->>'contentLength') ~ '^[0-9]+$'
       AND (COALESCE(o.metadata->>'size', o.metadata->>'contentLength'))::BIGINT <= 5 * 1024 * 1024
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_storage_missing');
  END IF;

  UPDATE public.payments
     SET status = CASE WHEN p_approve THEN 'success' ELSE 'failed' END,
         transaction_id = CASE
           WHEN p_approve THEN 'instapay_' || p_proof_id::TEXT
           ELSE transaction_id
         END,
         updated_at = now()
   WHERE id = v_payment_id
     AND status = 'pending'
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RAISE EXCEPTION 'payment_not_pending' USING ERRCODE = 'P0001';
  END IF;

  IF p_approve THEN
    UPDATE public.orders
       SET status = 'paid',
           updated_at = now()
     WHERE id = v_order_id
       AND status = 'pending'
     RETURNING id INTO v_updated_order_id;
    IF v_updated_order_id IS NULL THEN
      RAISE EXCEPTION 'order_not_pending' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  UPDATE public.instapay_proofs
     SET outcome = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = v_admin,
         reviewed_at = now(),
         note = v_note
   WHERE id = p_proof_id
     AND outcome IS NULL
   RETURNING id INTO v_updated_id;
  IF v_updated_id IS NULL THEN
    RAISE EXCEPTION 'proof_already_reviewed' USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.review_instapay_proof(UUID,BOOLEAN,TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_instapay_proof(UUID,BOOLEAN,TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_variant(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_stock INTEGER,
  p_price_override NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id UUID;
BEGIN
  PERFORM public.assert_admin();
  IF p_product_id IS NULL
     OR p_size IS NULL
     OR btrim(p_size) = ''
     OR p_color IS NULL
     OR btrim(p_color) = ''
     OR p_stock IS NULL
     OR p_stock < 0 THEN
    RAISE EXCEPTION 'invalid_variant' USING ERRCODE = '22023';
  END IF;
  IF p_price_override IS NOT NULL
     AND (p_price_override <= 0
          OR p_price_override::TEXT IN ('NaN', 'Infinity', '-Infinity')
          OR p_price_override <> trunc(p_price_override)) THEN
    RAISE EXCEPTION 'invalid_variant_price' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id) THEN
    RAISE EXCEPTION 'product_not_found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.product_variants (product_id, size, color, stock, price_override)
  VALUES (p_product_id, btrim(p_size), btrim(p_color), p_stock, p_price_override::INTEGER)
  ON CONFLICT (product_id, size, color)
  DO UPDATE SET stock = EXCLUDED.stock, price_override = EXCLUDED.price_override
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_variant(UUID,TEXT,TEXT,INTEGER,NUMERIC)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_variant(UUID,TEXT,TEXT,INTEGER,NUMERIC)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_product_images(
  p_product_id UUID,
  p_paths TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.assert_admin();
  IF p_product_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id) THEN
    RAISE EXCEPTION 'product_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF p_paths IS NULL OR cardinality(p_paths) > 20 THEN
    RAISE EXCEPTION 'invalid_image_paths' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM unnest(p_paths) AS path
    WHERE path IS NULL
       OR btrim(path) = ''
       OR path !~ ('^product-images/' || p_product_id::TEXT || '/')
       OR (
         NOT EXISTS (
           SELECT 1
           FROM storage.objects o
           WHERE o.bucket_id = 'product-images'
             AND o.name = path
         )
         AND NOT EXISTS (
           SELECT 1
           FROM public.product_images existing
           WHERE existing.product_id = p_product_id
             AND existing.storage_path = path
         )
       )
  ) THEN
    RAISE EXCEPTION 'invalid_image_path' USING ERRCODE = '22023';
  END IF;
  IF cardinality(p_paths) <> (SELECT count(DISTINCT path) FROM unnest(p_paths) AS paths(path)) THEN
    RAISE EXCEPTION 'duplicate_image_path' USING ERRCODE = '22023';
  END IF;
  DELETE FROM public.product_images WHERE product_id = p_product_id;
  INSERT INTO public.product_images (product_id, storage_path, sort_order, is_primary)
  SELECT p_product_id, path, ordinality - 1, ordinality = 1
  FROM unnest(p_paths) WITH ORDINALITY AS paths(path, ordinality);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_product_images(UUID,TEXT[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_product_images(UUID,TEXT[])
  TO authenticated;

COMMIT;



-- ============================================================
-- All migrations included. Reload the PostgREST schema cache.
NOTIFY pgrst, 'reload schema';
-- Run verify_schema.sql to confirm the schema.
-- ============================================================

