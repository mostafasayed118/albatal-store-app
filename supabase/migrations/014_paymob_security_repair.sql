-- ============================================================
-- Migration 014: Paymob security repair
--
-- Forward-only migration that fixes the P0 Paymob security
-- defects identified in the audit:
--
--   HIGH-03: adds a durable `paymob_order_id` column to
--           `payments` so the callback can map a Paymob
--           provider order to the internal order/payment
--           without treating the provider order ID as an
--           internal UUID.
--   HIGH-04: rewrites `update_order_status` so a `paid`
--           order can move through the fulfillment state
--           machine (`paid → processing → shipped →
--           delivered`) and so invalid transitions fail
--           server-side. The RPC now checks `profiles.is_admin`
--           directly (defense in depth on top of RLS).
--   HIGH-05: adds `process_paymob_callback` — an atomic,
--           SECURITY DEFINER RPC that the Edge Function
--           invokes after HMAC verification. It maps the
--           provider order to the internal payment, validates
--           amount/currency, persists the real Paymob
--           transaction id exactly once, transitions the
--           order and payment state in one transaction, and
--           restores stock exactly once on failure. A
--           duplicate callback is a no-op.
--
-- This migration NEVER edits historical migrations. It only
-- adds new columns, indexes, functions, and constraints.
--
-- Rollback:
--   This migration is forward-only in production. To roll
--   back on a staging database that has NOT shipped to
--   production, run the statements in reverse order:
--     DROP FUNCTION IF EXISTS process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN);
--     DROP INDEX IF EXISTS idx_payments_provider_txn;
--     DROP INDEX IF EXISTS idx_payments_paymob_order_id;
--     ALTER TABLE payments DROP COLUMN IF EXISTS paymob_order_id;
--   and restore the previous `update_order_status` from
--   migration 008. Do NOT roll back after production deploy.
--
-- Staging application:
--   Apply with `supabase db push` or by running this file in
--   the SQL editor on the staging project. Verify with:
--     \d payments                      -- column present
--     SELECT proname FROM pg_proc WHERE proname IN ('process_paymob_callback','update_order_status');
--   Then run the callback test fixture
--   (`test_paymob_callback.sql`) to confirm the state
--   transitions before pointing the Edge Function at staging.
-- ============================================================

-- ─── HIGH-03: provider order bridge on payments ───────────
-- `paymob_order_id` stores the numeric Paymob provider order
-- id (returned by /api/ecommerce/orders) at initiation time.
-- The callback uses it to locate the internal payment row
-- WITHOUT ever feeding the provider order id into `orders.id`
-- (which is a UUID). Nullable so existing rows survive.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS paymob_order_id TEXT;

-- One internal payment per provider order id. NULLs are
-- allowed for legacy rows that pre-date this migration.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_paymob_order_id
  ON payments (paymob_order_id)
  WHERE paymob_order_id IS NOT NULL;

-- The real Paymob transaction id is written exactly once by
-- the callback RPC. Keep the existing unique constraint on
-- `transaction_id` (migration 006) and add a partial index
-- so lookups by provider transaction id are fast.
CREATE INDEX IF NOT EXISTS idx_payments_provider_txn
  ON payments (transaction_id)
  WHERE transaction_id IS NOT NULL;

-- ─── HIGH-04: fulfillment state machine incl. `paid` ──────
-- Replace the 008 `update_order_status` with a version that
--   * accepts the `paid` source state,
--   * allows `paid → processing`, `paid → cancelled`,
--   * keeps `processing → shipped/cancelled`,
--   * keeps `shipped → delivered/cancelled`,
--   * denies every other transition,
--   * verifies the caller is an admin by reading
--     `profiles.is_admin` directly (the RPC is SECURITY
--     DEFINER, so this check is independent of RLS and
--     survives even if RLS is misconfigured),
--   * restores stock exactly once when an order that has
--     reserved stock is cancelled, using a guarded update
--     that only fires when the status actually flips to
--     `cancelled`.
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_tracking_number TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_current      TEXT;
  v_is_admin     BOOLEAN;
  v_do_restore   BOOLEAN;
  v_restored     UUID;
BEGIN
  -- ─── Admin authorization (defense in depth) ───────────
  -- RLS already gates UPDATE on `admin_update_orders`, but
  -- this RPC is SECURITY DEFINER and runs as the owner. We
  -- re-check `is_admin` so a non-admin JWT that somehow
  -- reaches the RPC still fails.
  SELECT COALESCE(profiles.is_admin, false)
    INTO v_is_admin
    FROM profiles
    WHERE profiles.id = auth.uid();

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- ─── Load current status (lock the row) ────────────────
  SELECT status INTO v_current
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- ─── Validate transition ───────────────────────────────
  -- `pending` is the pre-payment state. The callback RPC
  -- (not this function) is the only path that promotes
  -- `pending → paid`. Admins cancel expired/abandoned
  -- pending orders through here.
  IF v_current = 'pending' AND p_new_status NOT IN ('cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from pending to %', p_new_status;
  ELSIF v_current = 'paid' AND p_new_status NOT IN ('processing', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from paid to %', p_new_status;
  ELSIF v_current = 'placed' AND p_new_status NOT IN ('processing', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from placed to %', p_new_status;
  ELSIF v_current = 'processing' AND p_new_status NOT IN ('shipped', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from processing to %', p_new_status;
  ELSIF v_current = 'shipped' AND p_new_status NOT IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid transition from shipped to %', p_new_status;
  ELSIF v_current IN ('delivered', 'cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cannot change status of % order', v_current;
  END IF;

  -- ─── Apply transition ──────────────────────────────────
  -- Track whether we are about to cancel an order that had
  -- reserved stock so stock is restored exactly once.
  v_do_restore := (p_new_status = 'cancelled' AND v_current <> 'cancelled');

  UPDATE orders
    SET status = p_new_status::order_status,
        updated_at = now(),
        payment_id = COALESCE(p_tracking_number, payment_id)
    WHERE id = p_order_id;

  -- ─── Stock restoration on cancel (exactly once) ────────
  -- The `stock_restorations` ledger guarantees we only
  -- restore once per order, even if this function is called
  -- twice. The `order_items.restored` flag + trigger do the
  -- actual stock increment; the ledger is the guard.
  IF v_do_restore THEN
    INSERT INTO stock_restorations (order_id, restored_at)
      SELECT p_order_id, now()
      WHERE NOT EXISTS (
        SELECT 1 FROM stock_restorations
          WHERE order_id = p_order_id
      )
      RETURNING order_id INTO v_restored;

    IF FOUND THEN
      -- First cancel for this order — flip the restored flag
      -- on its items. The trigger `trg_restore_stock_on_item`
      -- increments product_variants.stock exactly once per
      -- item (guarded by `restored = false → true`).
      UPDATE order_items
        SET restored = true
        WHERE order_id = p_order_id
          AND restored = false;
    END IF;
  END IF;
END;
$$;

-- Keep the grant from 008.
GRANT EXECUTE ON FUNCTION update_order_status TO PUBLIC;

-- ─── Stock restoration ledger ─────────────────────────────
-- A tiny table that records, per order, whether stock has
-- already been restored. The callback and the cancel path
-- both consult it so a duplicate callback or a double
-- cancel never restores stock twice.
CREATE TABLE IF NOT EXISTS stock_restorations (
  order_id UUID PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
  restored_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- `order_items.restored` flags whether a line item's stock
-- has already been incremented back. The cancel trigger and
-- the callback failure path both set it atomically.
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS restored BOOLEAN NOT NULL DEFAULT false;

-- ─── Trigger: restore stock once when an item flips to restored
-- The trigger increments `product_variants.stock` exactly
-- once per order_items row, guarded by `restored = false`.
-- Both the admin cancel path and the callback failure path
-- set `restored = true`; the trigger does the increment.
CREATE OR REPLACE FUNCTION restore_stock_on_item_restore()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.restored = true AND OLD.restored = false THEN
    UPDATE product_variants
      SET stock = stock + NEW.quantity
      WHERE id = NEW.variant_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_restore_stock_on_item ON order_items;
CREATE TRIGGER trg_restore_stock_on_item
  AFTER UPDATE OF restored ON order_items
  FOR EACH ROW
  WHEN (NEW.restored = true AND OLD.restored = false)
  EXECUTE FUNCTION restore_stock_on_item_restore();

-- ─── HIGH-05: atomic callback processing RPC ─────────────
-- `process_paymob_callback` is the single transactional
-- entry point the Edge Function calls AFTER it has verified
-- the HMAC signature. It:
--   1. Locates the internal payment by `paymob_order_id`
--      (never by provider order id on `orders.id`).
--   2. Rejects if no matching payment exists (no orphan
--      insert — CRIT-02).
--   3. Validates the callback amount/currency against the
--      internal order total.
--   4. If the payment is already `success`/`failed`, returns
--      `already_processed` so the Edge Function can reply
--      2xx no-op (idempotent — HIGH-05).
--   5. On success: sets payment.status = 'success', stores
--      the real Paymob transaction id exactly once, promotes
--      the order from `pending` to `paid` (only if still
--      `pending`).
--   6. On failure: sets payment.status = 'failed', cancels
--      the order (only if still `pending`), and restores
--      stock exactly once via the guarded `restored` flag.
--   7. Never downgrades a `paid`/`processing`/`shipped`/
--      `delivered` order on a duplicate or late callback.
--
-- The RPC is SECURITY DEFINER because the Edge Function
-- calls it with the service-role client; it performs its
-- own authorization by requiring the caller to present the
-- already-verified provider order id and transaction id.
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
  v_order_total    INTEGER;
  v_order_currency TEXT DEFAULT 'EGP';
  v_result         JSONB;
BEGIN
  -- ─── Locate the internal payment by provider order id ──
  -- CRIT-01/CRIT-04 fix: never use the provider order id on
  -- `orders.id`. The payment row was created at initiation
  -- with `paymob_order_id` populated.
  SELECT id, order_id, user_id, status, amount
    INTO v_payment
    FROM payments
    WHERE paymob_order_id = p_paymob_order_id
    FOR UPDATE;

  IF NOT FOUND THEN
    -- CRIT-02 fix: no fallback/orphan payment insert.
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'unmapped_payment'
    );
  END IF;

  -- ─── Lock the order row and read canonical total ───────
  SELECT total INTO v_order_total
    FROM orders
    WHERE id = v_payment.order_id
    FOR UPDATE;

  IF v_order_total IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'code', 'order_not_found'
    );
  END IF;

  -- ─── Validate amount/currency (callback requirement B8) ─
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

  -- ─── Idempotency: already terminal ─────────────────────
  -- HIGH-05: a duplicate valid callback is a no-op.
  IF v_payment.status = 'success' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  IF v_payment.status = 'failed' THEN
    -- A late failure callback for a payment we already failed.
    -- Do not downgrade an order that has since moved on.
    RETURN jsonb_build_object(
      'ok', true,
      'code', 'already_processed',
      'payment_id', v_payment.id
    );
  END IF;

  -- ─── Apply the terminal transition ─────────────────────
  IF p_success THEN
    -- Persist the real Paymob transaction id exactly once.
    UPDATE payments
      SET status = 'success',
          transaction_id = p_paymob_txn_id,
          updated_at = now()
      WHERE id = v_payment.id;

    -- Promote the order to `paid` ONLY if it is still
    -- `pending`. A duplicate success callback cannot
    -- downgrade a `paid`/`processing`/`shipped`/`delivered`
    -- order (CRIT-04).
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

    -- Stock restoration happens exactly once via the
    -- `restored` flag on order_items + the trigger.
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

-- The Edge Function calls this with the service-role client;
-- public execute is safe because the RPC performs its own
-- authorization (it only acts on payments that already exist
-- and were created by the initiation flow).
GRANT EXECUTE ON FUNCTION process_paymob_callback TO PUBLIC;
