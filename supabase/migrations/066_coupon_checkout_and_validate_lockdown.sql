-- ═══════════════════════════════════════════════════════════════════
-- 066: coupons end-to-end + validate_coupon lockdown
--
-- Closes OWNER_ACTIONS.md Issues 1 + 2 (P1 money path / P1 security).
-- Promoted from docs/proposals/066_coupon_checkout_and_validate_lockdown.sql
-- (drafted + live-premise-verified 2026-09-23; autonomy grant: "finish the
-- app, proceed without waiting for confirmation").
--
-- Live evidence on staging (2026-09-23, pre-deploy probes):
--   Issue 1: POST /rest/v1/rpc/create_checkout_order with p_coupon_code
--     as an authenticated user -> PGRST202 (no function accepts that
--     parameter). Every coupon-attached checkout fails at runtime.
--   Issue 2: POST /rest/v1/rpc/validate_coupon with the anon key -> HTTP
--     200. The function is an unauthenticated code-enumeration oracle.
--
-- Issue 1 (P1 money path): the client sends `p_coupon_code` to
--   create_checkout_order (checkout_service.dart), but no applied
--   migration declares the parameter — Postgres rejects the unknown
--   named argument, so EVERY coupon checkout fails at runtime today.
--   This migration merges the review-gated coupon section of 056
--   (which was never inlined) into the CURRENT function body (047,
--   which carries 013/020/021/026 verbatim). Money math stays
--   server-owned: an invalid code must NOT block the order — it
--   simply applies no discount (056 reviewer note #2).
--
-- Issue 2 (P1 security): 056 granted EXECUTE on validate_coupon to
--   `anon, authenticated` — an unauthenticated code-enumeration
--   oracle on the money path. Locked to `authenticated` only and
--   throttled through the existing 060 rate_limit_take infrastructure
--   (per-user bucket, 20 takes / 60 s). The client only calls
--   validate_coupon from inside authenticated checkout
--   (coupon_card.dart), so the anon revoke changes no UX today.
--
-- Overload note: adding the 5th parameter creates a NEW function
-- identity. The old 4-arg overload is intentionally KEPT so older
-- app builds (which omit p_coupon_code) keep resolving it — both are
-- authenticated-only. A later migration can
-- `DROP FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT);`
-- once old builds age out.
--
-- Post-apply checklist (staging, then prod):
--   1. `\df+ create_checkout_order` — both overloads present, 5-arg
--      grants = authenticated only.
--   2. As anon: `select validate_coupon('X');` → permission denied.
--   3. As authenticated: 21 validate_coupon calls in a minute → the
--      21st raises 'Too many coupon checks'.
--   4. Checkout with a valid coupon → order row carries coupons_id +
--      coupon_discount_minor, total = max(subtotal+shipping-D, 0),
--      COD payment row created at the discounted total.
--   5. Checkout with a bogus coupon → order still placed, discount 0.
--
-- Rollback: the pre-066 bodies of create_checkout_order (4-arg) and
-- validate_coupon are migration 047 and 056 respectively — re-apply
-- those definitions to revert. No data is touched by this migration.
-- ═══════════════════════════════════════════════════════════════════

-- ─── Issue 1: create_checkout_order + p_coupon_code ────────────────
-- Body = 047 verbatim with the 056 §reviewer-note deltas:
--   1. new parameter  `p_coupon_code text DEFAULT NULL`,
--   2. coupon resolved AFTER shipping + premium perk (discount hits
--      the full total), floored at zero,
--   3. order row stores `coupons_id` + `coupon_discount_minor`,
--   4. RPC response exposes `coupon_discount_minor` (additive; the
--      client ignores unknown keys).

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL,
  p_coupon_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
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
  v_existing_expires  TIMESTAMPTZ;
  v_order_items_to_insert JSONB := '[]'::JSONB;
  v_is_cod       BOOLEAN;
  v_coupon_id     UUID;
  v_coupon_discount INTEGER := 0;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- ─── Validate payment method ─────────────────────────────
  IF p_payment_method IS NULL OR p_payment_method = '' THEN
    RAISE EXCEPTION 'Payment method is required';
  END IF;

  -- ─── Validate items ──────────────────────────────────────
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- ─── Validate address ────────────────────────────────────
  IF p_address IS NULL
     OR COALESCE(p_address->>'recipient', '') = ''
     OR COALESCE(p_address->>'line', '') = ''
     OR COALESCE(p_address->>'city', '') = '' THEN
    RAISE EXCEPTION 'A valid shipping address is required';
  END IF;

  v_governorate := p_address->>'city';

  -- ─── Idempotency: return existing order if key matches ───
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
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
        'idempotent', true
      );
    END IF;
  END IF;

  -- ─── Validate items, read DB prices, check stock ────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_size       := v_item->>'size';
    v_color      := v_item->>'color';
    v_quantity   := (v_item->>'quantity')::INTEGER;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for item %/%', v_size, v_color;
    END IF;

    -- Look up variant and product in one query
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

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    -- Collect validated item for later insert
    v_order_items_to_insert := v_order_items_to_insert || jsonb_build_array(
      jsonb_build_object(
        'variant_id',   v_variant_id,
        'product_id',   v_product_id,
        'product_name', v_product_name,
        'size',         v_size,
        'color',        v_color,
        'unit_price',   v_unit_price,
        'quantity',     v_quantity
      )
    );
  END LOOP;

  -- ─── Calculate shipping from shipping-zone logic ────────
  v_shipping := calculate_shipping_fee(v_governorate, v_subtotal);

  -- ─── Premium perk: free shipping (migration 047) ────────
  -- Read from the profile row, never from the request. Applied
  -- AFTER the zone calculation so the free-shipping threshold,
  -- zone fees, and config fallbacks keep working for everyone
  -- else exactly as before.
  IF (SELECT membership_tier FROM profiles WHERE id = v_user_id) = 'premium' THEN
    v_shipping := 0;
  END IF;

  v_total    := v_subtotal + v_shipping;

  -- ─── Coupon: server-owned discount (056 §8, merged here) ─
  -- Resolved AFTER shipping + premium so the discount applies to
  -- the full total. Unknown/expired code => no exception, no
  -- discount (order still placed). Floored at zero.
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

   -- ─── Compute expiry ──────────────────────────────────────
   v_expires_at := now() + interval '15 minutes';

   -- ─── Ensure a profile exists ──────────────────────────
   INSERT INTO profiles (id, full_name, phone)
   VALUES (v_user_id, '', '')
   ON CONFLICT (id) DO NOTHING;

   -- ─── Insert order (atomic with the rest) ─────────────────
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
    SELECT id, status::TEXT, subtotal, shipping, total, expires_at
      INTO v_existing_id, v_existing_status, v_existing_subtotal,
           v_existing_shipping, v_existing_total, v_existing_expires
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
      'idempotent', true
    );
  END;

  -- ─── Insert order items + decrement stock ────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_order_items_to_insert) LOOP
    v_variant_id := (v_item->>'variant_id')::UUID;
    v_product_id := (v_item->>'product_id')::UUID;
    v_product_name := v_item->>'product_name';
    v_size := v_item->>'size';
    v_color := v_item->>'color';
    v_unit_price := (v_item->>'unit_price')::INTEGER;
    v_quantity := (v_item->>'quantity')::INTEGER;

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
      SET stock = stock - v_quantity
      WHERE id = v_variant_id
        AND stock >= v_quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock race: insufficient stock for % (%/%)',
        v_product_name, v_size, v_color;
    END IF;
  END LOOP;

  -- ─── Clear the user's server-side cart ──────────────────
  DELETE FROM cart_items WHERE user_id = v_user_id;

  -- ═══════════════════════════════════════════════════════
  -- Create pending COD payment row for COD orders
  -- ═══════════════════════════════════════════════════════
  -- confirm_cod_payment rejects with payment_not_found, so COD
  -- orders need their pending payment row created here.
  -- (amount = v_total, i.e. already coupon-discounted.)
  v_is_cod := p_payment_method ILIKE '%cash%'
           OR p_payment_method ILIKE '%cod%';

  IF v_is_cod THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (v_order_id, v_user_id, 'cash_on_delivery', v_total, 'pending');
  END IF;

  -- ─── Return the canonical order data ─────────────────────
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

-- New overload: authenticated only (019/024 posture, same as 047).
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT, TEXT) TO authenticated;

-- ─── Issue 2: validate_coupon — anon lockdown + throttle ───────────
-- Same return shape (coupon_mapper.dart is untouched). STABLE →
-- VOLATILE because it now takes a rate-limit token (writes to
-- public.rate_limits via the 060 SECURITY DEFINER helper).
-- Bucket is per-user; 20 checks / 60 s is far above human typing
-- pace and far below useful enumeration pace.

CREATE OR REPLACE FUNCTION public.validate_coupon(p_code text)
RETURNS TABLE (code text, discount_minor integer, description text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.rate_limit_take(
       'validate_coupon:' || COALESCE(auth.uid()::text, 'anon'),
       20, 60) THEN
    RAISE EXCEPTION 'Too many coupon checks — retry in a minute'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT c.code, c.discount_minor, c.description
  FROM public.coupons c
  WHERE upper(trim(c.code)) = upper(trim(p_code))
    AND c.active
    AND (c.expires_at IS NULL OR c.expires_at > now())
  LIMIT 1;
END;
$$;

-- Lockdown: anon loses the oracle (056 had granted anon + authenticated).
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.validate_coupon(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_coupon(text) TO authenticated;
