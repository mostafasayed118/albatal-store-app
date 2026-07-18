-- ============================================================
-- Al Batal Elite — Row Level Security Policies
-- Run AFTER 001_initial_schema.sql
-- ============================================================

-- Enable RLS on all tables
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
-- Users can read/update only their own profile.
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- ─── CATEGORIES ────────────────────────────────────────────
-- Public read for everyone. Admin write (handled by service role).
CREATE POLICY "categories_select_public"
  ON categories FOR SELECT
  USING (is_active = true);

-- ─── PRODUCTS ──────────────────────────────────────────────
-- Public read for active products.
CREATE POLICY "products_select_public"
  ON products FOR SELECT
  USING (is_active = true);

-- ─── PRODUCT VARIANTS ─────────────────────────────────────
-- Public read for active variants of active products.
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
-- Public read for images of active products.
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
-- Users can CRUD only their own addresses.
CREATE POLICY "addresses_select_own"
  ON addresses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "addresses_insert_own"
  ON addresses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "addresses_update_own"
  ON addresses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "addresses_delete_own"
  ON addresses FOR DELETE
  USING (auth.uid() = user_id);

-- ─── WISHLISTS ────────────────────────────────────────────
-- Users can CRUD only their own wishlist items.
CREATE POLICY "wishlists_select_own"
  ON wishlists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "wishlists_insert_own"
  ON wishlists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wishlists_delete_own"
  ON wishlists FOR DELETE
  USING (auth.uid() = user_id);

-- ─── CART ITEMS ───────────────────────────────────────────
-- Users can CRUD only their own cart items.
CREATE POLICY "cart_select_own"
  ON cart_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "cart_insert_own"
  ON cart_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cart_update_own"
  ON cart_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "cart_delete_own"
  ON cart_items FOR DELETE
  USING (auth.uid() = user_id);

-- ─── ORDERS ───────────────────────────────────────────────
-- Users can read only their own orders.
-- Orders are created through a server-side function (Phase 8).
CREATE POLICY "orders_select_own"
  ON orders FOR SELECT
  USING (auth.uid() = user_id);

-- ─── ORDER ITEMS ──────────────────────────────────────────
-- Users can read items only for their own orders.
CREATE POLICY "order_items_select_own"
  ON order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
        AND orders.user_id = auth.uid()
    )
  );

-- ─── SERVICE ROLE ACCESS ──────────────────────────────────
-- The service role bypasses RLS — used for admin operations
-- and server-side functions. No policy needed; RLS is
-- automatically bypassed for service_role.
