-- 074_checkout_throttle_and_phone.sql
-- Forward fix for audit Top-5 #1 (checkout RPC unthrottled) + #4 phone split.
--
-- 072 created a bounded checkout wrapper but left it unthrottled while
-- validate_coupon is throttled (066) and rate_limit_take allowlists 'init:'
-- (070). This replaces the wrapper in place:
--   * 10 checkouts / 60s per authenticated user via public.rate_limit_take
--     ('init:checkout' scopes to auth.uid() inside the function).
--   * Phone keeps the 072 format regex AND requires 8-15 digits (E.164
--     length) so non-EG junk that passes the loose pattern is rejected
--     while the client's EG-only UX stays the stricter surface.
-- Idempotent: CREATE OR REPLACE + grants restated. No backfill.

BEGIN;

-- 072 hardening preamble, restated idempotently: the wrapper delegates to
-- the unchecked core, so refuse to install when it is missing (fail closed
-- instead of deploying a wrapper that raises at call time).
DO $$
BEGIN
  IF to_regprocedure('public.create_checkout_order_unchecked_072(text,jsonb,jsonb,text,text)') IS NULL THEN
    RAISE EXCEPTION 'checkout_unchecked_072 is unavailable';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL,
  p_coupon_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_method TEXT;
  v_item JSONB;
  v_quantity TEXT;
  v_result JSONB;
  v_expires_at TIMESTAMPTZ;
  v_phone_digits TEXT;
BEGIN
  -- Spam guard: fail fast before any stock/order work.
  -- Unauthenticated callers cannot reach here (EXECUTE is authenticated-only)
  -- but the guard is null-safe so a mis-granted path still fails closed.
  IF auth.uid() IS NOT NULL THEN
    IF NOT public.rate_limit_take('init:checkout', 10, 60) THEN
      RAISE EXCEPTION 'Too many checkouts' USING ERRCODE = 'P0001';
    END IF;
  ELSE
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_payment_method IS NULL
     OR p_payment_method NOT IN ('cod', 'card', 'paymob_card', 'instapay') THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;
  v_method := CASE WHEN p_payment_method = 'card' THEN 'paymob_card' ELSE p_payment_method END;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 50
     OR octet_length(p_items::TEXT) > 100000 THEN
    RAISE EXCEPTION 'Invalid cart payload' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) item
    CROSS JOIN LATERAL (
      SELECT lower(btrim(item->>'product_id')) AS raw_id,
             regexp_replace(lower(btrim(item->>'product_id')), '[^0-9a-f]', '', 'g') AS hex_id
    ) input_id
    JOIN products p
      ON p.id = CASE
           WHEN input_id.raw_id ~* '^[{}0-9a-f-]+$'
             AND char_length(input_id.hex_id) = 32
             THEN (
               substring(input_id.hex_id FROM 1 FOR 8) || '-' ||
               substring(input_id.hex_id FROM 9 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 13 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 17 FOR 4) || '-' ||
               substring(input_id.hex_id FROM 21 FOR 12)
             )::UUID
           ELSE NULL
         END
    WHERE p.sell_by_length
  ) THEN
    RAISE EXCEPTION 'Metered checkout is not available'
      USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION 'Invalid cart item' USING ERRCODE = '22023';
    END IF;
    v_quantity := v_item ->> 'quantity';
    IF v_quantity IS NULL OR v_quantity !~ '^[0-9]+$'
       OR (v_quantity::INTEGER < 1 OR v_quantity::INTEGER > 99) THEN
      RAISE EXCEPTION 'Invalid cart quantity' USING ERRCODE = '22023';
    END IF;
    IF v_item ? 'sample' OR v_item ? 'meters' OR v_item ? 'line_total'
       OR v_item ? 'tiered_price' THEN
      RAISE EXCEPTION 'Metered checkout is not available for this order'
        USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF p_idempotency_key IS NOT NULL
     AND (char_length(p_idempotency_key) < 1 OR char_length(p_idempotency_key) > 128) THEN
    RAISE EXCEPTION 'Invalid idempotency key' USING ERRCODE = '22023';
  END IF;
  v_phone_digits := regexp_replace(
    COALESCE(btrim(p_address ->> 'phone'), ''), '[^0-9]', '', 'g');
  IF p_address IS NULL
     OR octet_length(p_address::TEXT) > 4096
     OR COALESCE(btrim(p_address ->> 'recipient'), '') = ''
     OR char_length(btrim(p_address ->> 'recipient')) > 120
     OR COALESCE(btrim(p_address ->> 'line'), '') = ''
     OR char_length(btrim(p_address ->> 'line')) > 240
     OR COALESCE(btrim(p_address ->> 'city'), '') = ''
     OR char_length(btrim(p_address ->> 'city')) > 80
     OR COALESCE(btrim(p_address ->> 'phone'), '') = ''
     OR char_length(btrim(p_address ->> 'phone')) > 32
     OR btrim(p_address ->> 'phone') !~ '^\+?[0-9][0-9 ()-]{6,30}$'
     OR char_length(v_phone_digits) < 8
     OR char_length(v_phone_digits) > 15 THEN
    RAISE EXCEPTION 'A valid shipping address with phone is required'
      USING ERRCODE = '22023';
  END IF;

  v_result := public.create_checkout_order_unchecked_072(
    v_method,
    p_address,
    p_items,
    p_idempotency_key,
    p_coupon_code
  );

  IF COALESCE((v_result ->> 'total')::INTEGER, 0) <= 0 THEN
    RAISE EXCEPTION 'Checkout total must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF v_method = 'instapay'
     AND COALESCE(v_result ->> 'idempotent', 'false') <> 'true'
     AND NULLIF(v_result ->> 'order_id', '') IS NOT NULL THEN
    v_expires_at := now() + interval '24 hours';
    UPDATE public.orders
       SET expires_at = v_expires_at
     WHERE id = (v_result ->> 'order_id')::UUID
       AND status = 'pending';
    v_result := jsonb_set(v_result, '{expires_at}', to_jsonb(v_expires_at), true);
  END IF;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) TO authenticated;

COMMIT;
