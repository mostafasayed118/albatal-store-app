-- ============================================================
-- Migration 015: payment update authorization and stock hardening
--
-- This forward-only migration repairs the remaining P0 gaps:
--   1. `paymob-initiate` cannot update payments.paymob_order_id through
--      RLS. The restricted RPC below is the only authenticated path.
--   2. `process_paymob_callback` was executable by PUBLIC even though
--      it trusts the Edge Function's already-verified HMAC. A customer
--      could otherwise call it directly and forge success.
--   3. Legacy stock mutation functions were SECURITY DEFINER with a
--      mutable search_path and PUBLIC execution.
--   4. Expired pending orders need one transactional server-side path
--      that changes payment/order state and restores stock exactly once.
--
-- SECURITY MODEL
--   * Flutter never directly updates `payments`.
--   * A signed-in owner can set a provider order id exactly once while
--     their payment is still pending, through the restricted RPC.
--   * Only the service-role Edge Functions can process provider callbacks,
--     mutate legacy stock functions, or expire pending orders.
--   * Authenticated admins continue to call update_order_status; that
--     RPC verifies profiles.is_admin internally (migration 014).
-- ============================================================

-- Add explicit server-side terminal states used by the expiry worker.
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE payments
  ADD CONSTRAINT payments_status_check
  CHECK (status IN ('pending', 'success', 'failed', 'cancelled', 'expired', 'refunded'));

-- Persist the provider order bridge exactly once. The calling Edge Function
-- uses the authenticated user's JWT, so this RPC verifies ownership itself.
CREATE OR REPLACE FUNCTION set_payment_provider_order_id(
  p_payment_id UUID,
  p_paymob_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_payment RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_payment_id IS NULL OR COALESCE(btrim(p_paymob_order_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_input');
  END IF;

  SELECT id, user_id, status, paymob_order_id
    INTO v_payment
    FROM payments
    WHERE id = p_payment_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_not_found');
  END IF;

  IF v_payment.user_id <> auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_payment.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_pending');
  END IF;

  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_set');
  END IF;

  UPDATE payments
    SET paymob_order_id = btrim(p_paymob_order_id),
        updated_at = now()
    WHERE id = p_payment_id;

  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_payment_provider_order_id(UUID, TEXT) TO authenticated;

-- Restrict sensitive callback execution to the service-role Edge Function.
-- HMAC verification happens in paymob-callback before this RPC is called;
-- therefore authenticated/anonymous clients must never execute it directly.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- Legacy stock functions are used only by trusted service-side jobs. Keep
-- their signatures for compatibility, but lock both function execution and
-- SECURITY DEFINER name resolution down.
CREATE OR REPLACE FUNCTION decrement_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive';
  END IF;

  UPDATE product_variants
    SET stock = stock - p_quantity
    WHERE product_id = p_product_id
      AND size = p_size
      AND color = p_color
      AND stock >= p_quantity;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient stock for variant %/%', p_size, p_color;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION increment_stock(
  p_product_id UUID,
  p_size TEXT,
  p_color TEXT,
  p_quantity INTEGER
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive';
  END IF;

  UPDATE product_variants
    SET stock = stock + p_quantity
    WHERE product_id = p_product_id
      AND size = p_size
      AND color = p_color;
END;
$$;

REVOKE ALL ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;

-- Atomic expiry used by cancel-expired-orders. It locks the order, updates
-- only still-pending rows, marks a pending payment expired, and flips the
-- restored flag so the migration-014 trigger restores inventory once.
CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
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

  UPDATE order_items
    SET restored = true
    WHERE order_id = p_order_id
      AND restored = false;

  RETURN jsonb_build_object('ok', true, 'code', 'expired');
END;
$$;

REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- `update_order_status` deliberately remains executable by authenticated
-- callers because the admin Flutter app uses the authenticated client. The
-- SECURITY DEFINER implementation in migration 014 checks profiles.is_admin
-- independently of RLS before any state transition is applied.
