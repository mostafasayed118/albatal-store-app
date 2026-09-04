CREATE OR REPLACE FUNCTION public.confirm_cod_payment(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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
$function$
