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
