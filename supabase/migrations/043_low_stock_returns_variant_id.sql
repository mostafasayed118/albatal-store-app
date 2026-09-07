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
