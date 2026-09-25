CREATE INDEX IF NOT EXISTS idx_orders_user_placed_at
  ON public.orders(user_id, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_placed_at
  ON public.orders(placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status_placed_at
  ON public.orders(status, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order_product
  ON public.order_items(order_id, product_id);
CREATE INDEX IF NOT EXISTS idx_variants_stock_active
  ON public.product_variants(stock, product_id)
  WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_product_reviews_status_created_at
  ON public.product_reviews(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_order_method_status
  ON public.payments(order_id, method, status);

CREATE OR REPLACE FUNCTION public.admin_sales_overview(p_days INTEGER DEFAULT 14)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days INTEGER := greatest(least(coalesce(p_days, 14), 1), 90);
  v_start DATE := current_date - (greatest(least(coalesce(p_days, 14), 1), 90) - 1);
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
  END IF;

  WITH day_series AS (
    SELECT generate_series(
      v_start::timestamp,
      date_trunc('day', now()),
      interval '1 day'
    )::date AS day
  ),
  revenue AS (
    SELECT d.day,
           COALESCE(SUM(o.total), 0)::BIGINT AS revenue_minor
      FROM day_series d
      LEFT JOIN public.orders o
        ON o.placed_at >= d.day
       AND o.placed_at < d.day + 1
       AND o.status NOT IN ('cancelled', 'refunded')
     GROUP BY d.day
  ),
  status_rows AS (
    SELECT o.status::TEXT AS status, COUNT(*)::INTEGER AS count
      FROM public.orders o
     WHERE o.placed_at >= v_start
     GROUP BY o.status
  ),
  product_rows AS (
    SELECT oi.product_name, SUM(oi.quantity)::INTEGER AS units_sold
      FROM public.orders o
      JOIN public.order_items oi ON oi.order_id = o.id
     WHERE o.placed_at >= v_start
       AND o.status NOT IN ('cancelled', 'refunded')
     GROUP BY oi.product_name
     ORDER BY units_sold DESC, product_name
     LIMIT 5
  )
  SELECT jsonb_build_object(
    'revenue_by_day', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'day', to_char(day, 'YYYY-MM-DD'),
          'revenue_minor', revenue_minor
        ) ORDER BY day
      )
      FROM revenue
    ), '[]'::jsonb),
    'top_products', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'product_name', product_name,
          'units_sold', units_sold
        ) ORDER BY units_sold DESC
      )
      FROM product_rows
    ), '[]'::jsonb),
    'status_counts', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object('status', status, 'count', count)
        ORDER BY count DESC, status
      )
      FROM status_rows
    ), '[]'::jsonb)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_sales_overview(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_sales_overview(INTEGER) TO authenticated;
