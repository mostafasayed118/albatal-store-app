-- ============================================================
-- Migration 018: confirm_cod_payment RPC
--
-- The Flutter client calls `confirm_cod_payment` via
-- `supabase.rpc('confirm_cod_payment', params: {'p_order_id': ...})`
-- when the user selects Cash on Delivery. No Edge Function is
-- involved — the authenticated client calls the RPC directly.
--
-- PROBLEM THIS FIXES:
--   The RPC was referenced in Dart code (PaymobPaymentService,
--   PaymentCubit, PaymentService interface) and in unit tests
--   but never defined in any migration. Every COD payment
--   attempt failed with a PostgREST "function not found" error.
--
-- BEHAVIOR:
--   1. Verifies authentication (auth.uid() not null)
--   2. Finds the order, verifies ownership and pending status
--   3. Verifies the order's payment_method is COD
--      (tolerant ILIKE match on 'cash' or 'cod')
--   4. Finds or creates a COD payment row for this order
--   5. Atomically: payment.status = 'success', order.status = 'paid'
--   6. Returns { ok: true, transaction_id } or error code
--
-- The RPC is SECURITY DEFINER with search_path = public, auth
-- (same pattern as create_checkout_order, process_paymob_callback).
--
-- ERROR CODES (mapped to user-safe messages in PaymobPaymentService):
--   authentication_required  — not signed in
--   order_not_found          — no order with this ID
--   not_owner                — order belongs to another user
--   order_not_pending        — order already paid/cancelled/etc.
--   payment_not_cod          — order is not a Cash-on-Delivery order
--   payment_not_pending      — payment exists but not pending
--   already_confirmed        — payment already succeeded (idempotent)
--
-- IDEMPOTENCY:
--   Calling twice for the same order returns ok:true with
--   code 'already_confirmed' and the existing transaction_id.
--   No side effects on the second call.
--
-- Rollback:
--   DROP FUNCTION IF EXISTS confirm_cod_payment(UUID);
-- ============================================================

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
  -- ─── Authentication ───────────────────────────────────────
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  -- ─── Find and lock the order ──────────────────────────────
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

  -- ─── Ownership check ─────────────────────────────────────
  -- Defense in depth: RLS already restricts orders to the
  -- owner, but this RPC is SECURITY DEFINER so it runs as the
  -- owner. We re-check user_id so a forged JWT or misconfigured
  -- RLS cannot confirm another user's order.
  IF v_order.user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  -- ─── Verify the order is Cash on Delivery ────────────────
  -- The checkout stores the Flutter PaymentMethod.label string
  -- ("Cash on Delivery") in orders.payment_method. Match
  -- tolerantly so a future label change does not break COD.
  v_is_cod := v_order.payment_method ILIKE '%cash%'
           OR v_order.payment_method ILIKE '%cod%';

  IF NOT v_is_cod THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_cod'
    );
  END IF;

  -- ─── Idempotency: order already paid ─────────────────────
  -- If the order is already 'paid', a repeat confirmation is
  -- a no-op. Return the existing transaction_id.
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

  -- ─── Order must be pending ────────────────────────────────
  -- Any non-pending, non-paid status (cancelled, expired,
  -- shipped, etc.) cannot be confirmed.
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending'
    );
  END IF;

  -- ─── Find or create the COD payment row ───────────────────
  -- The checkout RPC (migration 013) creates the order but
  -- does NOT create a payment row. For Paymob, the Edge
  -- Function creates it. For COD, this RPC creates it here.
  -- Match on order_id + user_id + a COD-like method so a
  -- stray Paymob payment row is never reused for COD.
  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Create the COD payment row atomically. Store the method
    -- as 'cash_on_delivery' (lowercase convention, matches the
    -- paymob-initiate style of 'paymob_card').
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (p_order_id, v_user_id, 'cash_on_delivery', v_order.total, 'pending')
      RETURNING id, status INTO v_payment;
  END IF;

  -- ─── Payment already succeeded (idempotent) ──────────────
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

  -- ─── Payment must be pending ──────────────────────────────
  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending'
    );
  END IF;

  -- ─── Generate server-side transaction ID ──────────────────
  -- Format: COD-{unix_timestamp}-{8_hex_chars}
  -- Guarantees uniqueness via the timestamp + random suffix.
  -- The payments.transaction_id UNIQUE constraint is the
  -- ultimate guard; on collision the transaction rolls back.
  v_txn_id := 'COD-'
    || floor(extract(epoch FROM now()))::BIGINT::TEXT
    || '-'
    || substr(md5(random()::TEXT || v_payment.id::TEXT), 1, 8);

  -- ─── Atomic transition: payment + order ───────────────────
  -- Guarded UPDATE: only flips a still-pending payment. A
  -- concurrent confirmation that won the race leaves this
  -- UPDATE matching 0 rows, and we read the current state.
  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id
      AND status = 'pending';

  IF NOT FOUND THEN
    -- Another concurrent call won the race. Read the final state.
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

  -- Promote the order to 'paid' ONLY if still pending. A
  -- duplicate confirmation cannot downgrade a 'paid',
  -- 'processing', 'shipped', or 'delivered' order.
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

-- Execute permission: the Flutter client calls this with the
-- authenticated user's JWT. The RPC verifies auth.uid() and
-- order ownership internally, so authenticated execute is safe.
-- Anonymous calls fail at the auth check inside the function.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;
