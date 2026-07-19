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
