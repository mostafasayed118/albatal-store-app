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
