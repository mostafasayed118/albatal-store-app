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
