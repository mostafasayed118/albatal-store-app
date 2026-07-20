-- ============================================================
-- Al Batal Elite — Combined Migration Script
-- Generated: 2026-07-20 13:44:11
--
-- Paste into Supabase SQL Editor → Run
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


-- ============================================================
-- All migrations complete. Run verify_schema.sql to confirm.
-- ============================================================

