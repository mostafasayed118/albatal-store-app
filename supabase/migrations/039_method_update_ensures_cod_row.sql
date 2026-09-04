-- ═══════════════════════════════════════════════════════════
-- Migration 039: set_pending_order_payment_method also ensures
-- the pending COD payment row
-- ═══════════════════════════════════════════════════════════
-- PROBLEM (found live 2026-09-03):
--   037 updates orders.payment_method, but confirm_cod_payment
--   (026 Decision 2) REJECTS with payment_not_found unless a
--   pending COD payment row already exists. At creation time 026
--   creates that row inside create_checkout_order — but only when
--   the creation-time method is COD. Orders created with another
--   method (e.g. the checkout default) and switched to COD later
--   via 037 had no payment row, so COD confirmation always failed
--   AFTER the method fix (038).
--
-- Fix: when switching TO 'cod', insert the pending COD payment row
-- exactly as 026 does at creation time
-- (method 'cash_on_delivery', amount = order total, status pending),
-- guarded by NOT EXISTS so repeats are idempotent no-ops.
-- Switching TO 'card' touches no payment rows (paymob-initiate
-- owns its own row lifecycle via the 035 claim protocol).
--
-- Grants: re-assert the 038 matrix (client-called RPC).
-- Idempotent: CREATE OR REPLACE + guarded INSERT + idempotent grants.
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
  v_inserted INTEGER := 0;
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

  -- Mirror 026's creation-time behavior: a pending COD payment row
  -- must exist for confirm_cod_payment to find. Idempotent guard:
  -- only insert when no pending COD-like row exists yet.
  IF p_method = 'cod' THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'cash_on_delivery', total, 'pending'
      FROM orders
     WHERE id = p_order_id
       AND NOT EXISTS (
             SELECT 1 FROM payments
              WHERE order_id = p_order_id
                AND status = 'pending'
                AND (method ILIKE '%cash%' OR method ILIKE '%cod%')
           );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method,
    'payment_row_ensured', (p_method <> 'cod' OR v_inserted > 0)
  );
END;
$$;

-- Re-assert the 038 client-called grant matrix (CREATE OR REPLACE
-- preserves grants, but be explicit — same convention as 022/026).
REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;
