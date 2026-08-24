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
