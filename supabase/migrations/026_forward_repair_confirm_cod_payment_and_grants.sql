-- ============================================================
-- Migration 026: Forward repair — confirm_cod_payment + grants
--
-- PROBLEM:
--   Migration 018/022/025 defined confirm_cod_payment with
--   auto-create behavior for missing COD payment rows. The
--   approved Decision 2 changes this to reject with
--   payment_not_found. However, create_checkout_order (013)
--   does NOT create a payment row for COD orders. If we
--   reject without creating the payment row first, valid
--   COD orders will always fail.
--
-- FIX:
--   1. Update create_checkout_order to create a pending COD
--      payment row when payment_method is COD.
--   2. Update confirm_cod_payment to reject payment_not_found
--      when no valid pending COD payment row exists.
--   3. Re-assert all privilege grants for consistency.
--
-- APPROVED BEHAVIOR (Decision 2):
--   confirm_cod_payment returns:
--     payment_not_found  — no valid pending COD payment row
--     confirmed          — successful confirmation
--     already_confirmed  — idempotent re-confirmation
--
-- SAFETY:
--   - All CREATE OR REPLACE (idempotent)
--   - Does NOT renumber applied migrations
--   - Does NOT delete applied migration history
--   - Does NOT push to git
--   - Does NOT apply to staging (human must run manually)
--
-- ROLLBACK (staging only):
--   Restore create_checkout_order from migration 013.
--   Restore confirm_cod_payment from migration 025.
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. UPDATED create_checkout_order
-- ═══════════════════════════════════════════════════════════
-- After creating the order, if payment_method is COD, also
-- create a pending COD payment row. This ensures that
-- confirm_cod_payment can find a valid pending payment row
-- and does not need to auto-create one.

CREATE OR REPLACE FUNCTION create_checkout_order(
  p_payment_method TEXT,
  p_address JSONB,
  p_items JSONB,
  p_idempotency_key TEXT DEFAULT NULL
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
  v_total    := v_subtotal + v_shipping;

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
      idempotency_key, expires_at, placed_at
    ) VALUES (
      v_user_id, 'pending'::order_status, v_subtotal, v_shipping, v_total,
      p_payment_method, p_address,
      p_idempotency_key, v_expires_at, now()
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
  -- NEW: Create pending COD payment row for COD orders
  -- ═══════════════════════════════════════════════════════
  -- Decision 2 requires confirm_cod_payment to reject
  -- payment_not_found. For COD orders, we must create a
  -- pending payment row here so confirm_cod_payment can
  -- find and confirm it later.
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
    'idempotent', false
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 2. UPDATED confirm_cod_payment
-- ═══════════════════════════════════════════════════════════
-- Decision 2: reject with payment_not_found when no valid
-- pending COD payment row exists. No auto-create.

CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id    UUID := auth.uid();
  v_order      RECORD;
  v_payment    RECORD;
  v_txn_id     TEXT;
  v_is_cod     BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  SELECT id, user_id, status, total, payment_method
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── RACE GUARD: order already terminal ────────────────
  IF v_order.status = 'paid' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE order_id = p_order_id
        AND status = 'success'
      LIMIT 1;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  -- ═══════════════════════════════════════════════════════
  -- Decision 2: REJECT payment_not_found (no auto-create)
  -- ═══════════════════════════════════════════════════════
  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_found'
    );
  END IF;

  -- ─── RACE GUARD: payment already terminal ──────────────
  IF v_payment.status = 'success' THEN
    SELECT transaction_id INTO v_txn_id
      FROM payments
      WHERE id = v_payment.id;

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', COALESCE(v_txn_id, '')
    );
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ───────────────
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- Audit: payment transition.
  PERFORM audit_transition(
    'payment', v_payment.id,
    'pending', 'success',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    SELECT status, transaction_id INTO v_payment
      FROM payments
      WHERE id = v_payment.id;

    IF v_payment.status = 'success' THEN
      RETURN jsonb_build_object(
        'ok', true,
        'code', 'already_confirmed',
        'transaction_id', COALESCE(v_payment.transaction_id, '')
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- Audit: order transition.
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'paid',
    'cod-confirm',
    'cod_payment_confirmed',
    jsonb_build_object('transaction_id', v_txn_id)
  );

  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 3. PRIVILEGE GRANTS
-- ═══════════════════════════════════════════════════════════
-- Re-assert the complete privilege matrix. All REVOKE/GRANT
-- are idempotent (no-op when already in desired state).

-- create_checkout_order: authenticated only
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- confirm_cod_payment: authenticated only
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- process_paymob_callback: service_role only
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- expire_pending_order: service_role only
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- payments_insert_own policy: removed (defense in depth)
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;

COMMIT;
