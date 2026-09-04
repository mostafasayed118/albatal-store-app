-- ═══════════════════════════════════════════════════════════
-- Migration 037: allow updating payment method on pending orders
-- ═══════════════════════════════════════════════════════════
-- PROBLEM (found live 2026-09-03):
--   * `create_checkout_order` (013) stores whatever payment method
--     the client passes (checkout defaults to 'Credit Card').
--   * The customer picks the REAL method later, on the payment
--     screen — AFTER the order already exists.
--   * `confirm_cod_payment` (018) requires the stored method to be
--     COD-like, so confirming COD on a 'Credit Card'-tagged order
--     always fails with `payment_not_cod` and the pay button
--     appears dead.
--
-- Fix: `set_pending_order_payment_method` lets the order OWNER move
-- their own PENDING order to a canonical method before confirming.
-- Allowlist keeps the domain tight ('cod' satisfies the 018
-- ILIKE '%cash%/%cod%' guard; 'card' keeps the Paymob path
-- explicit). Only pending orders may change method — paid /
-- cancelled / expired orders are immutable.
--
-- Conventions: SECURITY DEFINER, locked search_path, REVOKE from
-- PUBLIC/anon/authenticated (same as 033/035). Idempotent.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION set_pending_order_payment_method(
  p_order_id UUID,
  p_method   TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_owner   UUID;
  v_status  TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_method');
  END IF;

  SELECT user_id, status::TEXT INTO v_owner, v_status
    FROM orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_owner IS DISTINCT FROM v_user_id THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_status IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  UPDATE orders
     SET payment_method = p_method,
         updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method
  );
END;
$$;

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
