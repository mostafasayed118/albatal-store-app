-- ============================================================
-- 035: Payment initiation + expiry hardening
-- ============================================================
-- Closes four audit findings in the payment path:
--
--   P0-1  Non-atomic initiation. The Edge Function used a
--         read-then-insert sequence, so two concurrent requests
--         could each create a pending payment row and each
--         register a distinct Paymob provider order.
--
--   P0-2  Provider-order duplication. A retry could create a
--         second provider order for the same internal payment.
--
--   P0-3  batch_expire_pending_orders() was executable by
--         `authenticated`, letting any signed-in caller expire
--         every pending order in the system.
--
--   P1    Inconsistent lock ordering. process_paymob_callback
--         locked the payment row before the order row while
--         expire_pending_order locked the order first. That
--         inversion can deadlock against a concurrent expiry.
--
-- Forward-only. Idempotent where PostgreSQL allows it.
-- NOT applied to any remote project by this change.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Provider-order claim lease
-- ────────────────────────────────────────────────────────────
-- Records the moment a caller took responsibility for creating
-- the Paymob provider order. A crashed request leaves a stale
-- claim that expires on a bounded lease, so initiation can never
-- remain permanently claimable after a crashed initiation. Because
-- provider submission may have succeeded before a timeout, claims are
-- intentionally retained until provider-order persistence or manual
-- reconciliation.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_claimed_at TIMESTAMPTZ;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_phase TEXT NOT NULL DEFAULT 'none';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_initiation_claim_token UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'payments_paymob_initiation_phase_check'
      AND conrelid = 'public.payments'::regclass
  ) THEN
    ALTER TABLE payments
      ADD CONSTRAINT payments_paymob_initiation_phase_check
      CHECK (paymob_initiation_phase IN (
        'none', 'pre_provider', 'provider_submitted', 'provider_persisted'
      ));
  END IF;
END $$;

-- Supports the pending-card lookup in the claim RPC.
CREATE INDEX IF NOT EXISTS idx_payments_paymob_initiation_claim_token
  ON payments (paymob_initiation_claim_token)
  WHERE method = 'paymob_card' AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_payments_paymob_initiation_claimed_at
  ON payments (paymob_initiation_claimed_at)
  WHERE method = 'paymob_card' AND status = 'pending';

CREATE INDEX IF NOT EXISTS idx_payments_pending_card_claim
  ON payments (order_id)
  WHERE method = 'paymob_card' AND status = 'pending';

-- ────────────────────────────────────────────────────────────
-- 2. Refuse to create an invalid unique index
-- ────────────────────────────────────────────────────────────
-- Pre-existing duplicates must be resolved deliberately, not
-- papered over. Failing here keeps the invariant honest.
DO $$
DECLARE
  v_duplicate_orders INTEGER;
BEGIN
  SELECT count(*) INTO v_duplicate_orders
  FROM (
    SELECT order_id
    FROM payments
    WHERE method = 'paymob_card'
      AND status = 'pending'
    GROUP BY order_id
    HAVING COUNT(*) > 1
  ) duplicated;

  IF v_duplicate_orders > 0 THEN
    RAISE EXCEPTION
      'Cannot create uq_payments_one_pending_card_per_order: % order(s) have more than one pending paymob_card payment',
      v_duplicate_orders
      USING ERRCODE = '23505';
  END IF;
END $$;

-- One pending card payment per order, enforced by the database.
-- This is the concurrency boundary the Edge Function relies on:
-- `ON CONFLICT DO NOTHING` now means "someone else already has
-- the pending payment", not "insert failed".
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_one_pending_card_per_order
  ON payments (order_id)
  WHERE method = 'paymob_card' AND status = 'pending';

-- ────────────────────────────────────────────────────────────
-- 3. Atomic get-or-create / claim RPC
-- ────────────────────────────────────────────────────────────
-- Replaces the read-then-insert sequence in paymob-initiate.
-- Single transaction, single lock scope, ownership enforced
-- server-side. Callable with the caller's own JWT — the Edge
-- Function no longer needs the service-role key.
CREATE OR REPLACE FUNCTION public.get_or_claim_paymob_payment(
  p_order_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid     UUID;
  v_order   RECORD;
  v_payment RECORD;
  v_new_id  UUID;
  v_lease   INTERVAL := INTERVAL '5 minutes';
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  -- ─── Lock the order FIRST ───────────────────────────────
  -- Global lock order is order -> payment. Every payment path
  -- (this RPC, process_paymob_callback, expire_pending_order,
  -- confirm_cod_payment) takes the order lock first, so the
  -- graph stays acyclic.
  SELECT id, user_id, status, payment_method, total
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_found');
  END IF;

  IF v_order.user_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_owner');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'order_not_pending');
  END IF;

  -- Card-only, enforced in the database BEFORE any provider call.
  IF v_order.payment_method <> 'paymob_card' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unsupported_payment_method');
  END IF;

  -- ─── Lock the pending card payment, if one exists ───────
  SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
      AND user_id = v_uid
      AND method = 'paymob_card'
      AND status = 'pending'
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Create exactly one pending card payment using the
    -- server-authoritative total. ON CONFLICT DO NOTHING turns a
    -- concurrent insert into a no-op instead of an error or a
    -- duplicate row.
    INSERT INTO payments (
      order_id, user_id, method, amount, status,
      paymob_initiation_claimed_at, paymob_initiation_phase,
      paymob_initiation_claim_token
    )
    VALUES (
      p_order_id, v_uid, 'paymob_card', v_order.total, 'pending',
      now(), 'pre_provider', gen_random_uuid()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_new_id;

    IF v_new_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'ok', true, 'code', 'claimed',
        'payment_id', v_new_id,
        'claim_token', (SELECT paymob_initiation_claim_token FROM payments WHERE id = v_new_id),
        'claimed', true,
        'amount', v_order.total,
        'action', 'create_provider_order'
      );
    END IF;

    -- Lost the race: re-read the winner under the same lock.
      SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
             paymob_initiation_phase, paymob_initiation_claim_token
      INTO v_payment
      FROM payments
      WHERE order_id = p_order_id
        AND user_id = v_uid
        AND method = 'paymob_card'
        AND status = 'pending'
      ORDER BY created_at
      LIMIT 1
      FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'payment_unavailable');
  END IF;

  -- ─── A provider order already exists ────────────────────
  -- Never create a second provider order. The caller reissues a
  -- payment key against the existing one.
  IF v_payment.paymob_order_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'existing_provider_order',
      'payment_id', v_payment.id,
      'paymob_order_id', v_payment.paymob_order_id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'reissue_payment_key'
    );
  END IF;

  -- ─── Another request is already creating the order ──────
  -- A claim is permanent until the provider order id is persisted.
  -- There is no client release or lease-based reclamation: a timeout
  -- after provider submission is indistinguishable from a timeout before
  -- submission, so clearing it could create a duplicate external order.
  IF v_payment.paymob_initiation_claimed_at IS NOT NULL
     AND v_payment.paymob_initiation_phase = 'provider_submitted' THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'initiation_in_progress',
      'payment_id', v_payment.id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'retry'
    );
  END IF;

  IF v_payment.paymob_initiation_claimed_at IS NOT NULL
     AND v_payment.paymob_initiation_phase = 'pre_provider'
     AND v_payment.paymob_initiation_claimed_at > now() - v_lease THEN
    RETURN jsonb_build_object(
      'ok', true, 'code', 'initiation_in_progress',
      'payment_id', v_payment.id,
      'claimed', false,
      'amount', v_order.total,
      'action', 'retry'
    );
  END IF;

  -- ─── Claim provider-order creation ──────────────────────
  UPDATE payments
    SET paymob_initiation_claimed_at = now(),
        paymob_initiation_phase = 'pre_provider',
        paymob_initiation_claim_token = gen_random_uuid(),
        updated_at = now()
    WHERE id = v_payment.id;

  SELECT id, paymob_order_id, status, paymob_initiation_claimed_at,
         paymob_initiation_phase, paymob_initiation_claim_token
    INTO v_payment
    FROM payments
    WHERE id = v_payment.id
    FOR UPDATE;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'claimed',
    'payment_id', v_payment.id,
    'claim_token', v_payment.paymob_initiation_claim_token,
    'claimed', true,
    'amount', v_order.total,
    'action', 'create_provider_order'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_or_claim_paymob_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_claim_paymob_payment(UUID) TO service_role;

-- Migration 015 grants this owner-bound persistence RPC to authenticated.
-- Redefine it here so phase advancement is atomic with provider-id persistence.
CREATE OR REPLACE FUNCTION public.set_payment_provider_order_id(
  p_payment_id UUID,
  p_paymob_order_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
        paymob_initiation_phase = 'provider_persisted',
        updated_at = now()
    WHERE id = p_payment_id;

  RETURN jsonb_build_object('ok', true, 'code', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_payment_provider_order_id(UUID, TEXT) TO authenticated;

-- The following internal service-only transitions are token-bound. A caller
-- cannot clear another attempt or reclaim a provider-submitted claim.
CREATE OR REPLACE FUNCTION public.mark_paymob_initiation_submitted(
  p_payment_id UUID,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE payments
    SET paymob_initiation_phase = 'provider_submitted',
        updated_at = now()
    WHERE id = p_payment_id
      AND paymob_initiation_claim_token = p_claim_token
      AND paymob_initiation_phase = 'pre_provider'
      AND status = 'pending'
      AND paymob_order_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pre_provider');
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'provider_submitted');
END;
$$;

CREATE OR REPLACE FUNCTION public.release_paymob_initiation_claim(
  p_payment_id UUID,
  p_claim_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE payments
    SET paymob_initiation_claimed_at = NULL,
        paymob_initiation_phase = 'none',
        paymob_initiation_claim_token = NULL,
        updated_at = now()
    WHERE id = p_payment_id
      AND paymob_initiation_claim_token = p_claim_token
      AND paymob_initiation_phase = 'pre_provider'
      AND status = 'pending'
      AND paymob_order_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'claim_not_pre_provider');
  END IF;

  RETURN jsonb_build_object('ok', true, 'code', 'released');
END;
$$;

REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.mark_paymob_initiation_submitted(UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.release_paymob_initiation_claim(UUID, UUID) TO service_role;

-- ────────────────────────────────────────────────────────────
-- 4. Expiry is service-only
-- ────────────────────────────────────────────────────────────
-- Migration 031 granted this to `authenticated`. Any signed-in
-- caller could therefore expire every pending order globally.
-- pg_cron runs as service_role, which retains execution.
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM anon;
REVOKE EXECUTE ON FUNCTION public.batch_expire_pending_orders() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO service_role;

-- ────────────────────────────────────────────────────────────
-- 5. process_paymob_callback: order-first locking
-- ────────────────────────────────────────────────────────────
-- Behaviour and result contract are unchanged. Only the lock
-- order and the read-after-lock discipline change.
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
  v_payment_id     UUID;
  v_order_id       UUID;
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Resolve payment -> order id (address resolution only) ──
  -- Deliberately unlocked. We cannot lock the payment first: the
  -- global lock order is order -> payment, and locking payment
  -- first is what produced the deadlock window against a
  -- concurrent expire_pending_order().
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  v_payment_id := v_payment.id;
  v_order_id := v_payment.order_id;

  -- ─── Lock the order FIRST and read the canonical total ──
  SELECT id, status, total, expires_at
    INTO v_order
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Acquire the payment lock second ─────────────────────
  PERFORM 1
    FROM payments
    WHERE id = v_payment_id
    FOR UPDATE;

  -- ─── Re-read both rows after both locks are held ─────────
  -- The first payment read only resolved the order id. These reads are
  -- authoritative and cannot be changed by callback/expiry peers now.
  SELECT id, status, total, expires_at
    INTO v_order
    FROM orders
    WHERE id = v_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE id = v_payment_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
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
  IF p_success THEN
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
    PERFORM audit_transition(
      'payment', v_payment.id,
      'pending', 'failed',
      'paymob-callback',
      'payment_failure',
      jsonb_build_object('paymob_txn_id', p_paymob_txn_id)
    );

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

-- Preserve the privilege matrix from migration 025.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- ────────────────────────────────────────────────────────────
-- 6. expire_pending_order: lock payment rows explicitly
-- ────────────────────────────────────────────────────────────
-- Previously the pending-payment UPDATE ran without an explicit
-- lock, leaving a window between the success check and the
-- expiry write.
CREATE OR REPLACE FUNCTION expire_pending_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order       RECORD;
  v_payment     RECORD;
  v_has_success BOOLEAN;
BEGIN
  -- Order lock first — consistent with the global lock order.
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

  -- Lock every payment row for this order BEFORE reading or
  -- writing payment state. Because we already hold the order
  -- lock and the callback takes the order lock first, this
  -- cannot deadlock.
  PERFORM 1
    FROM payments
    WHERE order_id = p_order_id
    FOR UPDATE;

  -- Explicitly reread the locked order and payment rows before any
  -- success check or mutation. This keeps the callback/expiry contract
  -- visibly order-first and read-after-lock.
  SELECT id, status, expires_at
    INTO v_order
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  SELECT id, order_id, status
    INTO v_payment
    FROM payments
    WHERE order_id = p_order_id
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE;

  -- ─── RACE GUARD: check if payment already succeeded ─────
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
