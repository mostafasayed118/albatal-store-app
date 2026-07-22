-- ============================================================
-- Migration 020: Server-confirmed COD + late-callback hardening
--
-- This migration implements two approved policies:
--
--   1. COD is server-confirmed with a durable lifecycle (Option A).
--      A new `confirm_cod_payment` RPC replaces the client-only
--      COD success path. The client must call this RPC after a
--      pending order exists, and the server atomically marks the
--      payment as success and the order as paid.
--
--   2. Late Paymob success after cancellation is rejected (Option 1).
--      The `process_paymob_callback` RPC now inspects the canonical
--      order status. If the payment is success but the order is
--      already cancelled/expired, the callback returns
--      `late_success_rejected` and does NOT resurrect the order.
--
-- Forward-only. Do NOT edit historical migrations.
--
-- Rollback (staging only, pre-production):
--   DROP FUNCTION IF EXISTS confirm_cod_payment(UUID, TEXT);
--   -- Restore the original process_paymob_callback from migration 014.
-- ============================================================

-- ─── 1. Server-confirmed COD payment ──────────────────────
-- The Flutter client calls this RPC after creating a pending
-- order via `create_checkout_order`. It:
--   a. Verifies auth.uid() (rejects null).
--   b. Reads the payment row by (order_id, user_id, method='cod').
--   c. Checks the order is still 'pending'.
--   d. Atomically sets payment.status='success',
--      payment.transaction_id='COD-<server-generated-id>',
--      order.status='paid'.
--   e. Is idempotent: if payment is already 'success', returns
--      the existing transaction_id.
--   f. Rejects cancelled/expired/already-paid orders.
--   g. Does NOT touch stock (stock was decremented at checkout).
--   h. Returns {ok, code, transaction_id, order_id}.
CREATE OR REPLACE FUNCTION confirm_cod_payment(
  p_order_id UUID,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller_id   UUID;
  v_payment     RECORD;
  v_order       RECORD;
  v_txn_id      TEXT;
BEGIN
  -- ─── Authentication ───────────────────────────────────────
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'authentication_required'
    );
  END IF;

  -- ─── Locate the COD payment for this order + user ─────────
  -- There should be at most one pending COD payment per order.
  SELECT id, order_id, user_id, status, transaction_id
    INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_caller_id
      AND method = 'cod'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_found'
    );
  END IF;

  -- ─── Ownership check ─────────────────────────────────────
  IF v_payment.user_id <> v_caller_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'not_owner'
    );
  END IF;

  -- ─── Idempotency: already confirmed ──────────────────────
  IF v_payment.status = 'success' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_confirmed',
      'transaction_id', v_payment.transaction_id,
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  END IF;

  -- ─── Reject if payment is in a non-pending terminal state ─
  IF v_payment.status NOT IN ('pending') THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'payment_not_pending',
      'payment_status', v_payment.status
    );
  END IF;

  -- ─── Lock the order row and check eligibility ────────────
  SELECT id, status, total
    INTO v_order
    FROM orders
    WHERE id = v_payment.order_id
    FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- Only 'pending' orders can be confirmed as paid.
  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_pending',
      'order_status', v_order.status
    );
  END IF;

  -- ─── Generate server-authoritative transaction ID ─────────
  -- Format: COD-<uuid4-no-hyphens> — unique, non-guessable,
  -- server-generated. This replaces the client-faked
  -- 'COD-<timestamp>' that previously leaked timing info.
  v_txn_id := 'COD-' || replace(uuid_generate_v4()::TEXT, '-', '');

  -- ─── Atomic transition: payment + order ───────────────────
  UPDATE payments
    SET status = 'success',
        transaction_id = v_txn_id,
        updated_at = now()
    WHERE id = v_payment.id;

  UPDATE orders
    SET status = 'paid'::order_status,
        updated_at = now()
    WHERE id = v_payment.order_id
      AND status = 'pending'::order_status;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'confirmed',
    'transaction_id', v_txn_id,
    'payment_id', v_payment.id,
    'order_id', v_payment.order_id
  );
END;
$$;

-- Grant to authenticated only (not PUBLIC, not anon).
-- The RPC checks auth.uid() internally; unauthenticated
-- callers are rejected on the denial path.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID, TEXT) TO authenticated;

-- ─── 2. Harden process_paymob_callback for late success ────
-- Replace the process_paymob_callback function so that a late
-- success callback for a cancelled/expired order returns
-- 'late_success_rejected' instead of silently returning
-- 'already_processed'. The order remains cancelled, stock
-- remains restored, and the payment stays as 'success'.
--
-- Invariant: once an order is cancelled/expired, only admin
-- action can change its state. A late provider callback does
-- NOT resurrect it.
CREATE OR REPLACE FUNCTION process_paymob_callback(
  p_paymob_order_id TEXT,
  p_paymob_txn_id   TEXT,
  p_amount_cents    INTEGER,
  p_currency        TEXT,
  p_success         BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment        RECORD;
  v_order          RECORD;
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Locate the internal payment by provider order id ─────
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  -- ─── Lock the order row and read canonical fields ─────────
  SELECT id, status, total
    INTO v_order
    FROM orders
    WHERE id = v_payment.order_id
    FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  v_order_total := v_order.total;

  -- ─── Validate amount/currency ─────────────────────────────
  IF p_amount_cents IS NULL OR p_amount_cents <> v_order_total THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'amount_mismatch',
      'expected', v_order_total,
      'received', p_amount_cents
    );
  END IF;

  IF p_currency IS NOT NULL AND p_currency <> v_order_currency THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'currency_mismatch',
      'expected', v_order_currency,
      'received', p_currency
    );
  END IF;

  -- ─── Idempotency: payment already terminal ────────────────
  IF v_payment.status = 'success' THEN
    -- Check if the ORDER is cancelled/expired despite the
    -- payment being 'success'. This is the late-callback
    -- scenario: payment was confirmed but order was later
    -- cancelled (e.g. by admin or expiry).
    IF v_order.status IN ('cancelled', 'expired', 'refunded') THEN
      -- LATE SUCCESS REJECTED: the order was cancelled after
      -- the payment succeeded. Do NOT resurrect it. Log for
      -- operational reconciliation.
      RAISE NOTICE 'late_success_rejected: paymob_order=% order=% order_status=%',
        p_paymob_order_id, v_order.id, v_order.status;

      RETURN jsonb_build_object(
        'ok', false,
        'code', 'late_success_rejected',
        'order_id', v_order.id,
        'order_status', v_order.status,
        'payment_id', v_payment.id
      );
    END IF;

    -- Payment success AND order not cancelled — genuinely
    -- already processed.
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  IF v_payment.status = 'failed' THEN
    -- Late failure: payment was already failed. Do not
    -- downgrade an order that has since moved on.
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  -- ─── Apply the terminal transition ────────────────────────
  IF p_success THEN
    -- ── LATE SUCCESS CHECK ──────────────────────────────────
    -- Before promoting, check if the order has already been
    -- cancelled/expired by admin or expiry worker.
    IF v_order.status IN ('cancelled', 'expired', 'refunded') THEN
      -- The payment was pending but the order was already
      -- cancelled. Mark payment as success (Paymob captured)
      -- but do NOT promote the order. Admin must reconcile.
      UPDATE payments
        SET status = 'success',
            transaction_id = p_paymob_txn_id,
            updated_at = now()
        WHERE id = v_payment.id;

      RAISE NOTICE 'late_success_rejected: paymob_order=% order=% order_status=% (payment marked success, order not promoted)',
        p_paymob_order_id, v_order.id, v_order.status;

      RETURN jsonb_build_object(
        'ok', false,
        'code', 'late_success_rejected',
        'order_id', v_order.id,
        'order_status', v_order.status,
        'payment_id', v_payment.id
      );
    END IF;

    -- Normal path: payment pending, order pending → promote.
    UPDATE payments
      SET status = 'success',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'paid'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'success',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  ELSE
    -- Failure: mark payment failed, cancel order if still
    -- pending, restore stock exactly once.
    UPDATE payments
      SET status = 'failed',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    UPDATE orders
      SET status = 'cancelled'::order_status,
          updated_at = now()
      WHERE id = v_payment.order_id
        AND status = 'pending'::order_status;

    UPDATE order_items
      SET restored = true
      WHERE order_id = v_payment.order_id
        AND restored = false;

    v_result := jsonb_build_object(
      'ok', true,
      'code', 'failed',
      'payment_id', v_payment.id,
      'order_id', v_payment.order_id
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Grant unchanged: service_role only (from migration 015).
-- REVOKE/GRANT not repeated here — migration 015 grant is
-- still in effect.
