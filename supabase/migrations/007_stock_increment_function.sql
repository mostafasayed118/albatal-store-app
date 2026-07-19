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
