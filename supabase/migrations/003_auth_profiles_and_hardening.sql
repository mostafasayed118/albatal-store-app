-- ============================================================
-- Al Batal Elite — Auth, Profiles & Admin Role
-- Run AFTER 002_rls_policies.sql
-- ============================================================

-- ─── PROFILE AUTO-CREATION TRIGGER ────────────────────────
-- Creates a profile row automatically when a new user signs up.
-- This prevents missing profiles if the app closes after registration.

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

-- Trigger on auth.users inserts
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── ADMIN ROLE ───────────────────────────────────────────
-- Uses a simple is_admin column on profiles for future staff access.
-- Admin operations use the service-role key, not the anon key.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- Admins can read all orders (for future admin dashboard)
CREATE POLICY "admin_select_all_orders"
  ON orders FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- Admins can update order status
CREATE POLICY "admin_update_orders"
  ON orders FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- Admins can manage products
CREATE POLICY "admin_manage_products"
  ON products FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- Admins can manage categories
CREATE POLICY "admin_manage_categories"
  ON categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_admin = true
    )
  );

-- Admins can manage variants
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
-- Users can only update their own non-sensitive profile fields.
-- is_admin and id cannot be changed by the user.

CREATE POLICY "profiles_update_own_safe"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
  );

-- ─── ORDER CREATION PROTECTION ────────────────────────────
-- Orders cannot be created directly from the client.
-- They must go through a server-side function (Phase 8).
-- This policy denies all INSERT from the anon/authenticated role.

CREATE POLICY "orders_insert_denied"
  ON orders FOR INSERT
  WITH CHECK (false);

-- Order items also cannot be created directly.
CREATE POLICY "order_items_insert_denied"
  ON order_items FOR INSERT
  WITH CHECK (false);
