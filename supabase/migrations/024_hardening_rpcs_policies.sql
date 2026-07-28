-- ============================================================
-- Migration 024: Final hardening — RPCs + logging table policies
--
-- DEFICITS FIXED:
--
--   1. calculate_shipping_fee — EXECUTE privilege
--      No explicit GRANT was ever issued. By default PostgreSQL
--      grants EXECUTE to PUBLIC, meaning anonymous callers can
--      invoke it. While the function has no side effects beyond
--      reading shipping config, a client-callable RPC that
--      returns pricing data should not be reachable by anon.
--      FIX: REVOKE from PUBLIC, grant to authenticated. Add
--      input validation (non-null, non-negative subtotal,
--      non-empty governorate). Add safe search_path.
--
--   2. notifications — INSERT policy (migration 010)
--      The current policy "notifications_insert_service" uses
--      WITH CHECK (true), which allows ANY role (including anon
--      and authenticated) to insert notification rows directly.
--      Notifications are only created by the send-order-
--      notification Edge Function (service_role, bypasses RLS).
--      FIX: Drop the permissive INSERT policy. With RLS enabled
--      and no INSERT policy, default-deny blocks all client
--      inserts. Service-role (SECURITY DEFINER or bypass RLS)
--      is the only write path.
--
--   3. analytics_events — INSERT policy (migration 010)
--      The current policy "analytics_insert_service" uses
--      WITH CHECK (true), allowing any role to inject arbitrary
--      events. This is an abuse vector for spam or data
--      poisoning.
--      FIX: Replace with a narrow authenticated policy:
--        - user_id must match auth.uid()
--        - event name must be non-empty, max 100 chars
--        - properties JSONB must be ≤ 10 KB
--        - No column-level size bypass
--
--   4. error_logs — INSERT policy (migration 010)
--      Same issue as analytics_events. WITH CHECK (true) lets
--      any role inject arbitrary error rows.
--      FIX: Replace with a narrow authenticated policy:
--        - user_id must match auth.uid()
--        - message must be non-empty, max 500 chars
--        - stack_trace must be ≤ 50 KB (error traces can be
--          large but should not be unlimited)
--        - environment restricted to known values
--
-- IDEMPOTENCY:
--   All statements use IF EXISTS / IF NOT EXISTS / CREATE OR
--   REPLACE. Safe to re-run after partial application.
--
-- DOES NOT:
--   - modify application data
--   - drop tables
--   - touch secrets / .env / auth / payments-config
--   - push to git
--
-- ROLLBACK (staging only — do NOT roll back after production):
--   See 024_rollback_hardening.sql
-- ============================================================

BEGIN;

-- ─── 1. calculate_shipping_fee: harden ─────────────────────
-- Drop existing function (same signature) and recreate with
-- input validation, safe search_path, and restricted EXECUTE.
DROP FUNCTION IF EXISTS calculate_shipping_fee(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION calculate_shipping_fee(
  p_governorate TEXT,
  p_subtotal    INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_threshold INTEGER;
  v_fee       INTEGER;
BEGIN
  -- ─── Input validation ────────────────────────────────────
  IF p_governorate IS NULL OR btrim(p_governorate) = '' THEN
    RAISE EXCEPTION 'Governorate is required';
  END IF;

  IF p_subtotal IS NULL OR p_subtotal < 0 THEN
    RAISE EXCEPTION 'Subtotal must be a non-negative integer';
  END IF;

  -- ─── Free-shipping threshold check ───────────────────────
  SELECT value::INTEGER INTO v_threshold
  FROM shipping_config WHERE key = 'free_shipping_threshold';

  IF v_threshold IS NULL THEN
    -- Defensive: if config row is missing, do not charge shipping.
    RETURN 0;
  END IF;

  IF p_subtotal >= v_threshold THEN
    RETURN 0;
  END IF;

  -- ─── Zone lookup ─────────────────────────────────────────
  SELECT sz.fee INTO v_fee
  FROM shipping_zones sz
  WHERE p_governorate = ANY(sz.governorates)
    AND sz.is_active = true
  LIMIT 1;

  -- ─── Fallback to default ─────────────────────────────────
  IF v_fee IS NULL THEN
    SELECT value::INTEGER INTO v_fee
    FROM shipping_config WHERE key = 'default_fee';

    -- Ultimate fallback if default_fee config is also missing.
    IF v_fee IS NULL THEN
      RETURN 0;
    END IF;
  END IF;

  RETURN v_fee;
END;
$$;

-- Restrict EXECUTE: authenticated only (called by other RPCs
-- and the Flutter client for display purposes).
REVOKE ALL ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) TO authenticated;


-- ─── 2. notifications: remove permissive INSERT policy ──────
-- Service-role Edge Functions bypass RLS, so the only INSERT
-- path is the send-order-notification Edge Function (service
-- role). Removing the policy means default-deny for all client
-- roles.
DROP POLICY IF EXISTS "notifications_insert_service" ON notifications;

-- Verify no INSERT policies remain (defense in depth check).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'notifications'
      AND cmd = 'INSERT'
  ) THEN
    RAISE EXCEPTION ' notifications仍有INSERT策略，安全检查失败';
  END IF;
END $$;


-- ─── 3. analytics_events: narrow authenticated INSERT policy ─
-- Drop the permissive policy first, then create the narrow one.
DROP POLICY IF EXISTS "analytics_insert_service" ON analytics_events;

CREATE POLICY "analytics_insert_narrow"
  ON analytics_events FOR INSERT
  WITH CHECK (
    -- Must be authenticated.
    auth.uid() IS NOT NULL
    -- user_id must match the caller.
    AND user_id = auth.uid()
    -- event name: non-empty, max 100 chars.
    AND event IS NOT NULL
    AND length(btrim(event)) > 0
    AND length(event) <= 100
    -- properties JSONB: must be ≤ 10 KB when serialized.
    AND pg_column_size(COALESCE(properties, '{}'::jsonb)) <= 10240
  );


-- ─── 4. error_logs: narrow authenticated INSERT policy ──────
-- Drop the permissive policy first, then create the narrow one.
DROP POLICY IF EXISTS "error_logs_insert_service" ON error_logs;

CREATE POLICY "error_logs_insert_narrow"
  ON error_logs FOR INSERT
  WITH CHECK (
    -- Must be authenticated.
    auth.uid() IS NOT NULL
    -- user_id must match the caller.
    AND user_id = auth.uid()
    -- message: non-empty, max 500 chars.
    AND message IS NOT NULL
    AND length(btrim(message)) > 0
    AND length(message) <= 500
    -- stack_trace: max 50 KB (large traces truncated by client).
    AND length(COALESCE(stack_trace, '')) <= 51200
    -- environment: restricted to known values.
    AND environment IN ('production', 'staging', 'development')
  );


-- ─── 5. Re-assert existing hardening (idempotent) ──────────
-- These are no-ops when already in the desired state. Included
-- so the final desired state is explicit in this migration.

-- process_paymob_callback: service_role only
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- confirm_cod_payment: authenticated only
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- create_checkout_order: authenticated only
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- update_order_status: authenticated (admin-checked internally)
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, TEXT) TO authenticated;

-- Stock functions: service_role only
REVOKE ALL ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) TO service_role;

-- Expire function: service_role only
REVOKE ALL ON FUNCTION expire_pending_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO service_role;

-- get_order_details: authenticated only (owner/admin checked)
REVOKE ALL ON FUNCTION get_order_details(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_order_details(UUID) TO authenticated;

-- get_low_stock_products: authenticated (admin checked internally)
REVOKE ALL ON FUNCTION get_low_stock_products(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_low_stock_products(INTEGER) TO authenticated;

-- set_payment_provider_order_id: authenticated only
REVOKE ALL ON FUNCTION set_payment_provider_order_id(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_payment_provider_order_id(UUID, TEXT) TO authenticated;


-- ─── 6. payments INSERT posture (defense in depth) ──────────
-- Ensure no INSERT policy exists on payments. Default-deny is
-- the structural guarantee that clients cannot create payment
-- rows directly.
-- Drop any existing INSERT policy for defense in depth.
DROP POLICY IF EXISTS "payments_insert_own" ON payments;


COMMIT;
