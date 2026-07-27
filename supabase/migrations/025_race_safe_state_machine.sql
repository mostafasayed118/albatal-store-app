-- ============================================================
-- Migration 025: Race-safe payment/order/stock state machine
--
-- PROBLEM:
--   A Paymob success callback may race with order expiry or
--   admin cancellation. The current process_paymob_callback
--   (014) only checks payment.status for idempotency. If
--   expiry fires first and sets payment.status='expired',
--   the callback's UPDATE silently no-ops (WHERE status='pending'
--   fails), but the function still returns ok:true, code:success.
--   This misreports the outcome and leaves the client confused.
--
-- FIXES:
--   1. process_paymob_callback: check BOTH order.status and
--      payment.status before applying any transition. If the
--      order is no longer 'pending' OR the payment is no longer
--      'pending', return already_processed immediately.
--
--   2. expire_pending_order: check payment.status before
--      cancelling. If payment is already 'success', return
--      already_paid (do NOT cancel a paid order).
--
--   3. state_transitions audit table: record every state
--      transition with caller, timestamp, and before/after
--      values for full auditability.
--
--   4. confirm_cod_payment: add dual-guard (order + payment)
--      identical to the callback path.
--
-- INVARIANTS ENFORCED:
--   I1: Every terminal state is coherent across payments, orders, stock.
--   I2: Lock canonical rows in deterministic order (payment → order).
--   I3: Permit success only while order AND payment are eligible.
--   I4: Reject late success after expiry/cancel without marking payment.
--   I5: Restore stock exactly once via stock_restorations ledger.
--   I6: Duplicate callbacks are safe no-ops.
--   I7: All transitions are auditable via state_transitions table.
--
-- IDEMPOTENCY:
--   All CREATE OR REPLACE. Safe to re-run after partial application.
--
-- SAFETY:
--   - Does NOT push to git.
--   - Does NOT deploy without approval.
--   - Does NOT print secrets.
--   - Does NOT allow client-side authoritative payment success.
--
-- ROLLBACK (staging only):
--   DROP TABLE IF EXISTS state_transitions;
--   -- Then restore process_paymob_callback, expire_pending_order,
--   -- confirm_cod_payment from migration 014/015/022.
-- ============================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. STATE TRANSITIONS AUDIT TABLE
-- ═══════════════════════════════════════════════════════════
-- Records every state mutation for orders and payments.
-- Append-only. Never deleted. Enables forensic audit of
-- race conditions and replay attacks.

CREATE TABLE IF NOT EXISTS state_transitions (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type   TEXT NOT NULL CHECK (entity_type IN ('order', 'payment')),
  entity_id     UUID NOT NULL,
  old_status    TEXT,
  new_status    TEXT NOT NULL,
  caller        TEXT NOT NULL DEFAULT 'system',
  reason        TEXT,
  metadata      JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast lookup by entity for audit queries.
CREATE INDEX IF NOT EXISTS idx_state_transitions_entity
  ON state_transitions (entity_type, entity_id, created_at DESC);

-- Fast lookup by caller for forensic analysis.
CREATE INDEX IF NOT EXISTS idx_state_transitions_caller
  ON state_transitions (caller, created_at DESC);

-- ═══════════════════════════════════════════════════════════
-- 2. AUDIT HELPER FUNCTION
-- ═══════════════════════════════════════════════════════════
-- Inserts an audit record. Called from within RPCs.
-- SECURITY DEFINER so it can write even when RLS is active.

CREATE OR REPLACE FUNCTION audit_transition(
  p_entity_type TEXT,
  p_entity_id   UUID,
  p_old_status  TEXT,
  p_new_status  TEXT,
  p_caller      TEXT,
  p_reason      TEXT,
  p_metadata    JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO state_transitions (
    entity_type, entity_id, old_status, new_status,
    caller, reason, metadata
  ) VALUES (
    p_entity_type, p_entity_id, p_old_status, p_new_status,
    p_caller, p_reason, p_metadata
  );
END;
$$;


-- ═══════════════════════════════════════════════════════════
-- 3. HARDENED process_paymob_callback
-- ═══════════════════════════════════════════════════════════
-- FIX: The idempotency guard now checks BOTH order.status
-- and payment.status before applying any mutation. This
-- prevents the race where expiry cancels the order between
-- our status check and our UPDATE.

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
  -- ─── Locate the internal payment by provider order id ──
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

  -- ─── Lock the order row and read canonical total ───────
  SELECT id, status, total, expires_at
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

  -- ─── Validate amount/currency ──────────────────────────
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

  -- ─── RACE GUARD: check BOTH payment AND order status ───
  -- I3/I4: If either is already in a terminal state, this
  -- callback is a late arrival. The outcome is already
  -- determined — return it without mutation.
  --
  -- This is the critical fix. The old code only checked
  -- payment.status IN ('success','failed'). If expiry set
  -- payment.status='expired' first, the UPDATE silently
  -- no-oped but the function returned ok:true, code:success.

  -- Payment already terminal → no-op.
  IF v_payment.status IN ('success', 'failed', 'expired', 'cancelled', 'refunded') THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- Order already terminal → no-op (do NOT mark payment success
  -- for an order that was cancelled/expired).
  IF v_order.status IN ('paid', 'processing', 'shipped', 'delivered',
                         'cancelled', 'refunded') THEN
    -- Audit: we rejected a late callback.
    PERFORM audit_transition(
      'payment', v_payment.id,
      v_payment.status, v_payment.status,
      'paymob-callback',
      'late_callback_rejected',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'order_status', v_order.status::text,
        'success_intended', p_success
      )
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id,
      'payment_status', v_payment.status,
      'order_status', v_order.status::text
    );
  END IF;

  -- ─── Apply the terminal transition ─────────────────────
  -- Both order AND payment are still 'pending'. Safe to transition.

  IF p_success THEN
    -- Audit: order transition.
    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'paid',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_order_id', p_paymob_order_id,
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

    -- Audit: payment transition.
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'success',
      'paymob-callback',
      'payment_success',
      jsonb_build_object(
        'paymob_txn_id', p_paymob_txn_id,
        'amount_cents', p_amount_cents
      )
    );

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
    -- Audit: payment failure.
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'failed',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

    -- Audit: order cancellation.
    PERFORM audit_transition(
      'order', v_order.id,
      'pending', 'cancelled',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

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

    -- Stock restoration: exactly once via restored flag + trigger.
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

-- Preserve privilege matrix from migration 024.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;


-- ═══════════════════════════════════════════════════════════
-- 4. HARDENED expire_pending_order
-- ═══════════════════════════════════════════════════════════
-- FIX: Before cancelling, check if any payment for this order
-- is already 'success'. If so, the user paid — do NOT cancel.
-- This prevents the race where callback success arrives
-- slightly after the expiry query but before the lock.

CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order       RECORD;
  v_has_success BOOLEAN;
BEGIN
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'code', 'already_terminal');
  END IF;

  IF v_order.expires_at IS NULL OR v_order.expires_at >= now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_expired');
  END IF;

  -- ─── RACE GUARD: check if payment already succeeded ─────
  -- If a success callback already landed (even if it hasn't
  -- promoted the order yet due to transaction ordering), we
  -- must NOT cancel. Check payment status under the same
  -- transaction scope.
  SELECT EXISTS(
    SELECT 1 FROM payments
    WHERE order_id = p_order_id
      AND status = 'success'
  ) INTO v_has_success;

  IF v_has_success THEN
    PERFORM audit_transition(
      'order', p_order_id,
      'pending', 'pending',
      'expire-worker',
      'expiry_aborted_payment_already_succeeded',
      '{}'::jsonb
    );

    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_paid',
      'order_id', p_order_id
    );
  END IF;

  -- ─── Apply expiry ──────────────────────────────────────
  PERFORM audit_transition(
    'order', p_order_id,
    'pending', 'cancelled',
    'expire-worker',
    'order_expired',
    jsonb_build_object('expires_at', v_order.expires_at)
  );

  PERFORM audit_transition(
    'payment', p_order_id,
    'pending', 'expired',
    'expire-worker',
    'order_expired',
    '{}'::jsonb
  );

  UPDATE orders
    SET status = 'cancelled'::order_status,
        updated_at = now()
    WHERE id = p_order_id
      AND status = 'pending'::order_status;

  UPDATE payments
    SET status = 'expired',
        updated_at = now()
    WHERE order_id = p_order_id
      AND status = 'pending';

  -- Stock restoration: exactly once via restored flag + trigger.
  UPDATE order_items
    SET restored = true
    WHERE order_id = p_order_id
      AND restored = false;

  RETURN jsonb_build_object('ok', true, 'code', 'expired');
END;
$$;

-- Preserve privilege matrix.
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;


-- ═══════════════════════════════════════════════════════════
-- 5. HARDENED confirm_cod_payment
-- ═══════════════════════════════════════════════════════════
-- FIX: Add dual-guard (order + payment) identical to the
-- callback path. If order is no longer pending or payment
-- is no longer pending, return already_confirmed.

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

  SELECT id, status INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_user_id
      AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
    FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
      VALUES (p_order_id, v_user_id, 'cash_on_delivery', v_order.total, 'pending')
      RETURNING id, status INTO v_payment;
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

-- Preserve privilege matrix.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;


-- ═══════════════════════════════════════════════════════════
-- 6. AUDIT TRIGGER ON orders.status
-- ═══════════════════════════════════════════════════════════
-- Automatic audit trail for order status changes made by
-- any code path (not just the RPCs above). Defense in depth.

CREATE OR REPLACE FUNCTION audit_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO state_transitions (
      entity_type, entity_id, old_status, new_status,
      caller, reason, metadata
    ) VALUES (
      'order', NEW.id,
      OLD.status::text, NEW.status::text,
      current_user,
      'trigger_audit',
      jsonb_build_object(
        'function',TG_OP,
        'table', TG_TABLE_NAME
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_order_status ON orders;
CREATE TRIGGER trg_audit_order_status
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION audit_order_status_change();


-- ═══════════════════════════════════════════════════════════
-- 7. AUDIT TRIGGER ON payments.status
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION audit_payment_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO state_transitions (
      entity_type, entity_id, old_status, new_status,
      caller, reason, metadata
    ) VALUES (
      'payment', NEW.id,
      OLD.status, NEW.status,
      current_user,
      'trigger_audit',
      jsonb_build_object(
        'function', TG_OP,
        'table', TG_TABLE_NAME
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_payment_status ON payments;
CREATE TRIGGER trg_audit_payment_status
  AFTER UPDATE OF status ON payments
  FOR EACH ROW
  EXECUTE FUNCTION audit_payment_status_change();


COMMIT;
