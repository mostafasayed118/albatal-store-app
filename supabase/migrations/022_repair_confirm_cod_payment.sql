-- ============================================================
-- Migration 022: Repair confirm_cod_payment RPC
--
-- PROBLEM:
--   The Flutter client calls `confirm_cod_payment` when the
--   user selects Cash on Delivery. The on-disk migration 018
--   defined this RPC but was never applied to staging (staging
--   has a different file at slot 018: 018_low_stock_index_and_perf).
--   All COD checkout attempts fail with PostgREST "function not
--   found" error.
--
-- THIS MIGRATION:
--   Uses CREATE OR REPLACE to (re)define the function. Safe to
--   apply regardless of whether migration 018 was applied:
--     - If the function does not exist: creates it.
--     - If the function exists (from local 018): replaces it
--       with the identical logic.
--     - If staging has a different function at this signature:
--       replaces it.
--
--   Also re-asserts REVOKE/GRANT to guarantee the final
--   authorization state matches migrations 018 + 019, regardless
--   of which migrations were previously applied.
--
-- BEHAVIOR (matches approved migration 018):
--   1. Requires auth.uid() (authentication_required)
--   2. Finds and locks the order row (order_not_found)
--   3. Verifies order ownership (not_owner)
--   4. Verifies COD payment method via ILIKE (payment_not_cod)
--   5. Idempotent: if order already paid → already_confirmed
--   6. Order must be pending (order_not_pending)
--   7. Finds or auto-creates a COD payment row
--   8. Idempotent: if payment already success → already_confirmed
--   9. Payment must be pending (payment_not_pending / invalid_state)
--  10. Generates server-side transaction ID
--  11. Atomic: payment.status = 'success', order.status = 'paid'
--  12. Returns jsonb: { ok, code, transaction_id }
--
-- MISSING PAYMENT ROW:
--   The checkout RPC (migration 013) creates orders but does NOT
--   create payment rows for COD. This function auto-creates a
--   COD payment row when one does not exist. This is the approved
--   behavior (auto-create), not reject.
--
-- SECURITY:
--   SECURITY DEFINER with search_path = public, auth
--   REVOKE ALL FROM PUBLIC + anon; GRANT EXECUTE TO authenticated
--
-- IDEMPOTENCY:
--   Safe to re-run. REVOKE/GRANT are no-ops when already in the
--   desired state. CREATE OR REPLACE is idempotent.
--
-- DOES NOT:
--   * renumber or delete existing migrations
--   * rewrite applied migration history
--   * modify application data (aside from the target function)
--   * touch secrets / .env / auth / payments-config
--   * push to git
--   * apply to staging (human must run manually)
--
-- ROLLBACK:
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
  -- function owner. We re-check user_id so a forged JWT or
  -- misconfigured RLS cannot confirm another user's order.
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

-- ─── Authorization ─────────────────────────────────────────
-- REVOKE/GRANT are idempotent (no-op when already in desired
-- state). This guarantees the final authorization matches the
-- intended security model regardless of which migrations were
-- previously applied.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;
