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
