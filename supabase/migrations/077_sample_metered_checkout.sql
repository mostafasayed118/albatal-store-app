-- 077_sample_metered_checkout.sql — REVIEW-GATED PROPOSAL (Batch 3 #1 swatch-kit)
-- Owner review required before applying (AGENTS.md migration gate).
-- DO NOT APPLY without owner approval. DO NOT ship the client flip first:
-- pre-077 backends reject sample/metered lines, so the client MUST keep
-- gating them behind serverMeteredCheckoutEnabled until 077 is live.
--
-- What this enables (full 051 scope: samples + metered):
--   * Sample lines (`'sample': true`) are priced server-side at a fixed
--     per-line price from app_config `sample_price_minor` instead of
--     being rejected. Quantity is fixed to 1 (client one-per-color
--     convention); at most `sample_max_per_order` sample lines per order.
--     One unit of stock is decremented from an active variant of the
--     same product+color (physical swatches consume inventory).
--   * Metered lines (`meters` + `line_total`, optional `tiered_price`)
--     for sell_by_length products: the server re-derives the cut from
--     the fabric contract (min_cut_meters, 0.5 m grid snap, wholesale
--     tier ladder mirrored from cut_length_pricing.dart) and REJECTS on
--     any mismatch with the client-submitted totals. Stock is tracked
--     in whole meters on the baseline '1m' variant (058 plan); the
--     decrement is CEIL(snapped_meters * quantity) — conservative, never
--     oversells a fractional remainder.
--
-- Contract notes (client = cut_length_pricing.dart + checkout_service.dart):
--   * `size` for metered lines is the plain meters string ('2.5') that
--     double.tryParse accepts — NOT the '<meters>m' sketch from the 058
--     reviewer note. The core cross-checks size::numeric = meters.
--   * Tier ladder mirrored here: >= 25 m -> 10 %, >= 10 m -> 5 %
--     (kWholesaleTiers, descending). Truncation uses SQL integer
--     division, which matches Dart `~/`; the line-total rounding adds
--     500/1000, which matches Dart `.round()` (half up, positives).
--   * Money math stays server-owned: client totals are cross-checked,
--     never trusted.
--
-- Structure (072 precedent): the current wrapper is left in place as
-- the rollback target; a NEW unchecked core `..._unchecked_077`
-- (= 066/072-core body verbatim + sample/metered branches, EXECUTE
-- revoked from everyone) does the money work, and the wrapper
-- (074 body + new per-line key gating) delegates to it.
--
-- Reviewer-tunable seeds (values reviewed at deploy time):
--   sample_price_minor  = '5000'  (50 EGP per swatch line)
--   sample_max_per_order = '10'
--   cut_max_meters      = '50'    (mirrors kCutLengthMaxMeters)
--
-- Post-apply checklist (staging, then prod):
--   1. `\df+ create_checkout_order` — wrapper + unchecked_077 present;
--      unchecked_077 has NO grants; wrapper = authenticated only.
--   2. Sample checkout (1 line, qty 1) prices at sample_price_minor,
--      decrements 1 unit, order_items row has size='sample'.
--   3. Sample with quantity <> 1, or > sample_max_per_order sample
--      lines, or extra meters/line_total keys -> rejected.
--   4. Metered checkout 12.5 m tier-5 % product: total matches the
--      app's cart estimate; tampered line_total / tiered_price ->
--      'Metered price mismatch'; below min_cut_meters -> rejected;
--      non-sell_by_length product with meters -> rejected.
--   5. Plain fixed-size checkout unchanged (existing proofs re-run).
--   6. Sample-only order total > 0 passes the wrapper total guard.
--
-- Rollback: re-point the wrapper delegation back to
-- create_checkout_order_unchecked_072 (one-line change) or re-apply
-- 074 verbatim. No data is touched by this migration (seeds are
-- ON CONFLICT DO NOTHING).

BEGIN;

-- ─── Reviewer-tunable pricing keys ──────────────────────────────
INSERT INTO public.app_config (key, value) VALUES
  ('sample_price_minor', '5000'),
  ('sample_max_per_order', '10'),
  ('cut_max_meters', '50')
ON CONFLICT (key) DO NOTHING;

-- ─── New unchecked core: 066/072 body + sample/metered branches ─
-- NOT granted to anyone (072 preamble pattern): only the wrapper calls it.
CREATE OR REPLACE FUNCTION public.create_checkout_order_unchecked_077(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL,
  p_coupon_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_order_id     UUID;
  v_subtotal     INTEGER := 0;
  v_shipping     INTEGER := 0;
  v_total        INTEGER := 0;
  v_governorate   TEXT;
  v_expires_at   TIMESTAMPTZ;
  v_item         JSONB;
  v_product_id   UUID;
  v_size         TEXT;
  v_color        TEXT;
  v_quantity     INTEGER;
  v_unit_price   INTEGER;
  v_product_name TEXT;
  v_variant_id   UUID;
  v_stock        INTEGER;
  v_existing_id      UUID;
  v_existing_status  TEXT;
  v_existing_subtotal INTEGER;
  v_existing_shipping INTEGER;
  v_existing_total    INTEGER;
  v_existing_expires    TIMESTAMPTZ;
  v_existing_coupon_discount INTEGER;
  v_order_items_to_insert JSONB := '[]'::JSONB;
  v_is_cod       BOOLEAN;
  v_coupon_id     UUID;
  v_coupon_discount INTEGER := 0;
  -- 077 additions:
  v_is_sample    BOOLEAN;
  v_sample_price INTEGER;
  v_sample_count INTEGER := 0;
  v_sample_max   INTEGER;
  v_meters       NUMERIC;
  v_snapped      NUMERIC;
  v_snapped_tenths INTEGER;
  v_min_cut      NUMERIC;
  v_max_cut      NUMERIC;
  v_base_per_meter INTEGER;
  v_tier_pct     INTEGER;
  v_tiered_per_meter INTEGER;
  v_expected_total INTEGER;
  v_client_total INTEGER;
  v_client_tiered INTEGER;
  v_need         INTEGER;
  v_sell_by_length BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- Pricing keys: fail closed when the owner has not seeded them.
  SELECT value::INTEGER INTO v_sample_price FROM public.app_config
    WHERE key = 'sample_price_minor';
  IF NOT FOUND OR v_sample_price IS NULL OR v_sample_price <= 0 THEN
    RAISE EXCEPTION 'Sample pricing is not configured' USING ERRCODE = '22023';
  END IF;
  SELECT value::INTEGER INTO v_sample_max FROM public.app_config
    WHERE key = 'sample_max_per_order';
  IF NOT FOUND OR v_sample_max IS NULL OR v_sample_max < 1 THEN
    RAISE EXCEPTION 'Sample pricing is not configured' USING ERRCODE = '22023';
  END IF;
  SELECT value::NUMERIC INTO v_max_cut FROM public.app_config
    WHERE key = 'cut_max_meters';
  IF NOT FOUND OR v_max_cut IS NULL OR v_max_cut < 0.5 THEN
    RAISE EXCEPTION 'Metered checkout is not configured' USING ERRCODE = '22023';
  END IF;

  -- Idempotency: return existing order if key matches (066 verbatim).
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at, coupon_discount_minor
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires,
           v_existing_coupon_discount
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'order_id',   v_existing_id,
        'subtotal',   v_existing_subtotal,
        'shipping',   v_existing_shipping,
        'total',      v_existing_total,
        'status',     v_existing_status,
        'expires_at', v_existing_expires,
        'idempotent', true,
        'coupon_discount_minor', COALESCE(v_existing_coupon_discount, 0)
      );
    END IF;
  END IF;

  -- Validate items, read DB prices, check stock.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- String comparison (no ::boolean cast): garbage values fail closed
    -- in the wrapper, and anything but the literal 'true' is plain here.
    v_is_sample := COALESCE(v_item->>'sample', 'false') = 'true';

    IF v_is_sample THEN
      -- ─── Sample branch ──────────────────────────────────
      -- Fixed server-side price; one unit per line; consumes stock.
      IF v_quantity <> 1 THEN
        RAISE EXCEPTION 'Sample lines allow quantity 1'
          USING ERRCODE = '22023';
      END IF;
      v_sample_count := v_sample_count + 1;
      IF v_sample_count > v_sample_max THEN
        RAISE EXCEPTION 'Too many sample lines in one order'
          USING ERRCODE = '22023';
      END IF;

      SELECT p.name INTO v_product_name
        FROM products p
        WHERE p.id = v_product_id AND p.is_active = true;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', v_product_id;
      END IF;

      -- Any active variant of the same color proves the color exists
      -- and donates one unit of stock; prefer the '1m' baseline row
      -- so metered roll stock stays the single source of truth.
      SELECT pv.id, pv.stock
        INTO v_variant_id, v_stock
        FROM product_variants pv
        WHERE pv.product_id = v_product_id
          AND pv.color = v_color
          AND pv.is_active = true
        ORDER BY (pv.size = '1m') DESC
        LIMIT 1;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Variant not found: %/% for product %',
          v_size, v_color, v_product_id;
      END IF;
      IF v_stock < 1 THEN
        RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
          v_product_name, v_size, v_color, v_stock;
      END IF;

      v_unit_price := v_sample_price;
      v_need := 1;
      v_subtotal := v_subtotal + v_unit_price;

    ELSIF v_item ? 'meters' THEN
      -- ─── Metered branch ─────────────────────────────────
      -- Both casts live inside the guard: non-numeric input fails
      -- closed with a 22023 instead of leaking a 22P02 cast error.
      -- The size string is the same contract the client parses with
      -- double.tryParse; cross-check it against the meters key.
      BEGIN
        v_meters := (v_item->>'meters')::NUMERIC;
        IF v_size IS NULL OR v_size::NUMERIC <> v_meters THEN
          v_meters := NULL;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_meters := NULL;
      END;
      IF v_meters IS NULL THEN
        RAISE EXCEPTION 'Invalid meters for item %/%', v_size, v_color
          USING ERRCODE = '22023';
      END IF;

      SELECT COALESCE(pv.price_override, p.base_price),
             p.name, p.sell_by_length,
             COALESCE(p.min_cut_meters, 0.5)
        INTO v_base_per_meter, v_product_name, v_sell_by_length, v_min_cut
        FROM products p
        LEFT JOIN product_variants pv
          ON pv.product_id = p.id
         AND pv.size = '1m'
         AND pv.color = v_color
         AND pv.is_active = true
        WHERE p.id = v_product_id AND p.is_active = true;
      IF NOT FOUND OR v_product_name IS NULL THEN
        RAISE EXCEPTION 'Product not found: %', v_product_id;
      END IF;
      IF NOT COALESCE(v_sell_by_length, false) THEN
        RAISE EXCEPTION 'Metered checkout is not available for this order'
          USING ERRCODE = '22023';
      END IF;
      IF v_base_per_meter IS NULL THEN
        RAISE EXCEPTION 'Metered cut requires a 1m stock variant (%/%)',
          v_size, v_color USING ERRCODE = '22023';
      END IF;
      IF v_meters < v_min_cut OR v_meters > v_max_cut THEN
        RAISE EXCEPTION 'Cut length % m is outside %–% m for %',
          v_meters, v_min_cut, v_max_cut, v_product_name
          USING ERRCODE = '22023';
      END IF;

      -- Authoritative grid snap (0.5 m) + wholesale tier mirror.
      v_snapped := ROUND(v_meters * 2) / 2;
      v_snapped_tenths := (v_snapped * 10)::INTEGER;
      v_tier_pct := CASE
        WHEN v_snapped >= 25 THEN 10
        WHEN v_snapped >= 10 THEN 5
        ELSE 0
      END;
      -- Integer division truncates like Dart `~/`.
      v_tiered_per_meter := v_base_per_meter * (100 - v_tier_pct) / 100;
      -- +500/1000 mirrors Dart `.round()` (half up) in
      -- meteredLineTotalWithTier: base*(100-pct)*tenths*qty/1000.
      v_expected_total :=
        (v_base_per_meter * (100 - v_tier_pct) * v_snapped_tenths * v_quantity + 500) / 1000;

      -- Client-submitted totals are cross-checked, never trusted;
      -- non-integer input counts as a mismatch (22023), not a 22P02.
      BEGIN
        v_client_total := (v_item->>'line_total')::INTEGER;
        v_client_tiered := CASE WHEN v_item ? 'tiered_price'
          THEN (v_item->>'tiered_price')::INTEGER ELSE NULL END;
      EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Metered price mismatch for %', v_product_name
          USING ERRCODE = '22023';
      END;
      IF v_client_total IS NULL OR v_client_total <> v_expected_total THEN
        RAISE EXCEPTION 'Metered price mismatch for %', v_product_name
          USING ERRCODE = '22023';
      END IF;
      IF v_client_tiered IS NOT NULL
         AND v_client_tiered <> v_tiered_per_meter THEN
        RAISE EXCEPTION 'Metered price mismatch for %', v_product_name
          USING ERRCODE = '22023';
      END IF;

      SELECT pv.id, pv.stock INTO v_variant_id, v_stock
        FROM product_variants pv
        WHERE pv.product_id = v_product_id
          AND pv.size = '1m'
          AND pv.color = v_color
          AND pv.is_active = true;
      -- Whole-meter tracking: CEIL never oversells a fractional remainder.
      v_need := CEIL(v_snapped * v_quantity)::INTEGER;
      IF v_stock < v_need THEN
        RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: % m',
          v_product_name, v_size, v_color, v_stock;
      END IF;

      v_unit_price := v_tiered_per_meter;
      v_size := v_snapped::TEXT;
      v_subtotal := v_subtotal + v_expected_total;

    ELSE
      -- ─── Plain fixed-size branch (066 verbatim) ─────────
      SELECT pv.id, pv.stock, COALESCE(pv.price_override, p.base_price), p.name
        INTO v_variant_id, v_stock, v_unit_price, v_product_name
        FROM product_variants pv
        JOIN products p ON p.id = pv.product_id
        WHERE pv.product_id = v_product_id
          AND pv.size = v_size
          AND pv.color = v_color
          AND pv.is_active = true
          AND p.is_active = true;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Variant not found: %/% for product %', v_size, v_color, v_product_id;
      END IF;

      IF v_stock < v_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for % (%/%). Available: %',
          v_product_name, v_size, v_color, v_stock;
      END IF;

      v_need := v_quantity;
      v_subtotal := v_subtotal + (v_unit_price * v_quantity);
    END IF;

    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity,
        'need',         v_need
      )
    );
  END LOOP;

  -- Shipping, premium perk, coupon, expiry, profile (066 verbatim).
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);

  IF (SELECT membership_tier FROM profiles WHERE id = v_user_id) = 'premium' THEN
    v_shipping := 0;
  END IF;

  v_total    := v_subtotal + v_shipping;

  IF p_coupon_code IS NOT NULL AND btrim(p_coupon_code) <> '' THEN
    SELECT c.id, c.discount_minor
      INTO v_coupon_id, v_coupon_discount
      FROM coupons c
     WHERE upper(trim(c.code)) = upper(trim(p_coupon_code))
       AND c.active
       AND (c.expires_at IS NULL OR c.expires_at > now())
     LIMIT 1;

    IF NOT FOUND THEN
      v_coupon_id := NULL;
      v_coupon_discount := 0;
    END IF;

    v_total := GREATEST(v_total - v_coupon_discount, 0);
  END IF;

   v_expires_at := now() + interval '15 minutes';

   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   BEGIN
    INSERT INTO orders (
      user_id, status, subtotal, shipping, total,
      payment_method, address_snapshot,
      idempotency_key, expires_at, placed_at,
      coupons_id, coupon_discount_minor
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now(),
      v_coupon_id, v_coupon_discount
    )
    RETURNING id INTO v_order_id;

  EXCEPTION WHEN unique_violation THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at, coupon_discount_minor
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires,
           v_existing_coupon_discount
      FROM orders
      WHERE idempotency_key = p_idempotency_key
        AND user_id = v_user_id;

    RETURN jsonb_build_object(
      'order_id',   v_existing_id,
      'subtotal',   v_existing_subtotal,
      'shipping',   v_existing_shipping,
      'total',      v_existing_total,
      'status',     v_existing_status,
       'expires_at', v_existing_expires,
       'idempotent', true,
       'coupon_discount_minor', COALESCE(v_existing_coupon_discount, 0)
    );
  END;

  -- Insert order items + decrement stock by the collected `need`
  -- (quantity for plain lines, 1 for samples, CEIL meters for cuts).
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;
    v_need := (v_item->>'need')::INTEGER;

    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, color,
      unit_price, quantity
    ) VALUES (
      v_order_id, v_product_id, v_variant_id,
      v_product_name, v_size, v_color,
      v_unit_price, v_quantity
    );

    UPDATE product_variants
      SET stock = stock - v_need
      WHERE id = v_variant_id
        AND stock >= v_need;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  DELETE FROM cart_items WHERE user_id = v_user_id;

  v_is_cod := p_payment_method ILIKE '%cash%'
           OR p_payment_method ILIKE '%cod%';

  IF v_is_cod THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (v_order_id, v_user_id, 'cash_on_delivery', v_total, 'pending');
  END IF;

  RETURN jsonb_build_object(
    'order_id',   v_order_id,
    'subtotal',   v_subtotal,
    'shipping',   v_shipping,
    'total',      v_total,
    'status',     'pending',
    'expires_at', v_expires_at,
    'idempotent', false,
    'coupon_discount_minor', v_coupon_discount
  );
END;
$$;

-- Fail closed: nobody calls the core directly (072 pattern).
REVOKE ALL ON FUNCTION public.create_checkout_order_unchecked_077(TEXT, JSONB, JSONB, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

-- ─── Wrapper: 074 body + per-line key gating, delegates to 077 ──
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

  -- sell_by_length products MUST go through the metered contract
  -- (or a sample line); plain fixed-size lines for them stay rejected.
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
      AND NOT (item ? 'meters'
               OR COALESCE(item->>'sample', 'false') = 'true')
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
    -- Per-line key gating (replaces the 072/074 blanket rejection):
    -- sample lines carry ONLY the sample flag; metered lines carry
    -- meters + line_total (+ optional tiered_price); plain lines
    -- carry none of the four keys.
    IF COALESCE(v_item->>'sample', 'false') = 'true' THEN
      IF v_item ? 'meters' OR v_item ? 'line_total'
         OR v_item ? 'tiered_price' THEN
        RAISE EXCEPTION 'Invalid sample line' USING ERRCODE = '22023';
      END IF;
    ELSIF v_item ? 'sample' THEN
      -- Key present but not literal true: fail closed (no ::boolean
      -- cast, so garbage can never coerce).
      RAISE EXCEPTION 'Invalid sample flag' USING ERRCODE = '22023';
    ELSIF v_item ? 'meters' THEN
      IF v_item ? 'sample' OR NOT (v_item ? 'line_total') THEN
        RAISE EXCEPTION 'Invalid metered line' USING ERRCODE = '22023';
      END IF;
    ELSIF v_item ? 'line_total' OR v_item ? 'tiered_price' THEN
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

  -- 077: delegate to the sample/metered-aware core. The 072 core stays
  -- in place untouched as the one-line rollback target.
  v_result := public.create_checkout_order_unchecked_077(
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
