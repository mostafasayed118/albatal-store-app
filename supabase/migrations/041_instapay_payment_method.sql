-- ============================================================
-- Migration 041: InstaPay payment method (manual confirmation)
-- Part of the InstaPay implementation plan
-- (docs/InstaPay-implementation-plan.md, PR #36). Owner approved
-- recommendations: D1 manual review, D2 24h expiry, D3 screenshot
-- required + reference optional, D4 dashboard-first review.
--
-- Adds 'instapay' to the payment-method allowlists and creates the
-- proof-of-transfer review surface:
--   1. set_pending_order_payment_method allowlist ('cod','card') ->
--      ('cod','card','instapay')            [037/039 seam]
--      and ensures a single pending 'instapay' payments row
--      (mirror of the 039 COD-row guarantee).
--   2. instapay_proofs table: owner-uploaded transfer proofs
--      (screenshot required per D3, reference optional), reviewed
--      by an admin. No new payments.status values — approval
--      reuses the COD terminal write pattern.
--   3. Private storage bucket 'instapay-proofs' with RLS.
--   4. review_instapay_proof(UUID, boolean, TEXT): admin-only RPC;
--      approve => payments.success + orders.paid in ONE transaction
--      (server-generated transaction id), reject => failed.
--   5. expire_pending_order gains a 24h (D2) instapay expiry:
--      pending instapay payments older than 24h are cancelled.
--
-- Conventions: SECURITY DEFINER, locked search_path, REVOKE from
-- PUBLIC/anon (033/035/037 style). Forward-only, idempotent.
-- This migration does NOT touch Paymob flows, RLS policies on
-- existing tables, or order state machinery beyond the RPC.
-- ============================================================

BEGIN;

-- ─── 1. Allowlist: 'instapay' joins 'cod' and 'card' ─────────
-- 039 shape preserved verbatim; only the allowlist tuple and the
-- row-ensure branch change. The instapay row guarantee mirrors the
-- COD one: exactly one pending 'instapay' payments row per order.
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

  IF p_method IS NULL OR p_method NOT IN ('cod', 'card', 'instapay') THEN
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

  -- Pending COD row guarantee (039, unchanged).
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

  -- Pending InstaPay row guarantee: the review flow keys off this
  -- row; keep it single and pending, mirroring COD semantics.
  IF p_method = 'instapay' THEN
    INSERT INTO payments (order_id, user_id, method, amount, status)
    SELECT p_order_id, v_user_id, 'instapay', total, 'pending'
      FROM orders
     WHERE id = p_order_id
       AND NOT EXISTS (
             SELECT 1 FROM payments
              WHERE order_id = p_order_id
                AND status = 'pending'
                AND method = 'instapay'
           );
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'method_updated',
    'order_id', p_order_id,
    'payment_method', p_method,
    'payment_row_ensured', (p_method NOT IN ('cod', 'instapay') OR v_inserted > 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_pending_order_payment_method(UUID, TEXT)
  TO authenticated;

-- ─── 2. Proof-of-transfer review surface ─────────────────────
CREATE TABLE IF NOT EXISTS instapay_proofs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  reference TEXT,
  outcome TEXT CHECK (outcome IN ('approved','rejected')),
  reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_instapay_proofs_payment
  ON instapay_proofs(payment_id);
CREATE INDEX IF NOT EXISTS idx_instapay_proofs_outcome
  ON instapay_proofs(outcome);

ALTER TABLE instapay_proofs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "instapay_proofs_select_own" ON instapay_proofs;
CREATE POLICY "instapay_proofs_select_own"
  ON instapay_proofs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM payments p
       WHERE p.id = payment_id
         AND p.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles prof
       WHERE prof.id = auth.uid()
         AND prof.is_admin = true
    )
  );

DROP POLICY IF EXISTS "instapay_proofs_insert_own" ON instapay_proofs;
CREATE POLICY "instapay_proofs_insert_own"
  ON instapay_proofs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM payments p
       WHERE p.id = payment_id
         AND p.user_id = auth.uid()
         AND p.status = 'pending'
    )
  );

-- Admin review update path goes through the SECURITY DEFINER RPC
-- below; no direct UPDATE policy is granted to anyone.

-- ─── 3. Private storage bucket for proofs ────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('instapay-proofs', 'instapay-proofs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "instapay proofs owner read" ON storage.objects;
CREATE POLICY "instapay proofs owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'instapay-proofs'
    AND (
      (storage.foldername(name))[1] = auth.uid()::TEXT
      OR EXISTS (
        SELECT 1 FROM profiles prof
         WHERE prof.id = auth.uid()
           AND prof.is_admin = true
      )
    )
  );

DROP POLICY IF EXISTS "instapay proofs owner write" ON storage.objects;
CREATE POLICY "instapay proofs owner write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'instapay-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- ─── 4. Admin review RPC ─────────────────────────────────────
-- Approve: payment -> success (server-generated transaction id),
-- order -> paid, proof outcome recorded — all in one transaction.
-- Reject: payment -> failed, proof outcome recorded.
-- Fail-closed: non-admin callers get a generic refusal.
CREATE OR REPLACE FUNCTION review_instapay_proof(
  p_proof_id UUID,
  p_approve  BOOLEAN,
  p_note     TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin  UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_payment RECORD;
  v_order_id UUID;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'authentication_required');
  END IF;

  SELECT is_admin INTO v_is_admin
    FROM profiles
   WHERE id = v_admin;

  IF v_is_admin IS DISTINCT FROM TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'admin_required');
  END IF;

  SELECT payment_id, outcome INTO v_payment
    FROM instapay_proofs
   WHERE id = p_proof_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_not_found');
  END IF;

  IF v_payment.outcome IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'proof_already_reviewed');
  END IF;

  SELECT order_id INTO v_order_id
    FROM payments
   WHERE id = v_payment.payment_id
   FOR UPDATE;

  IF p_approve THEN
    UPDATE payments
       SET status = 'success',
           transaction_id = 'instapay_' || p_proof_id::TEXT,
           updated_at = now()
     WHERE id = v_payment.payment_id
       AND status = 'pending';

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'code', 'payment_not_pending');
    END IF;

    UPDATE orders
       SET status = 'paid',
           updated_at = now()
     WHERE id = v_order_id
       AND status = 'pending';

    UPDATE instapay_proofs
       SET outcome = 'approved',
           reviewed_by = v_admin,
           reviewed_at = now(),
           note = p_note
     WHERE id = p_proof_id;
  ELSE
    UPDATE payments
       SET status = 'failed',
           updated_at = now()
     WHERE id = v_payment.payment_id
       AND status = 'pending';

    UPDATE instapay_proofs
       SET outcome = 'rejected',
           reviewed_by = v_admin,
           reviewed_at = now(),
           note = p_note
     WHERE id = p_proof_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'payment_id', v_payment.payment_id,
    'order_id', v_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION review_instapay_proof(UUID, BOOLEAN, TEXT)
  FROM PUBLIC, anon, authenticated;

-- ─── 5. 24h expiry for pending instapay payments (D2) ────────
-- Mirrors the card/claim expiry machinery: stale pending instapay
-- claims self-heal via the cancel-expired-orders worker.
CREATE OR REPLACE FUNCTION expire_stale_instapay_payments()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cancelled INTEGER := 0;
BEGIN
  WITH stale AS (
    SELECT p.id, p.order_id
      FROM payments p
      JOIN orders o ON o.id = p.order_id
     WHERE p.method = 'instapay'
       AND p.status = 'pending'
       AND p.created_at < now() - INTERVAL '24 hours'
       AND o.status = 'pending'
     FOR UPDATE SKIP LOCKED
  )
  UPDATE payments pp
     SET status = 'expired',
         updated_at = now()
    FROM stale s
   WHERE pp.id = s.id;

  GET DIAGNOSTICS v_cancelled = ROW_COUNT;
  RETURN v_cancelled;
END;
$$;

REVOKE ALL ON FUNCTION expire_stale_instapay_payments()
  FROM PUBLIC, anon, authenticated;

COMMIT;
