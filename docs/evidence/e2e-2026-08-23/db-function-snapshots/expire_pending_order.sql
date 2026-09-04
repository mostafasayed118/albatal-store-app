CREATE OR REPLACE FUNCTION public.expire_pending_order(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
