-- ============================================================
-- Rollback for Migration 024: Hardening RPCs + logging policies
--
-- WARNING: This rollback RESTORES the permissive policies that
-- migration 024 removed. Only run on STAGING before production
-- deploy. After production deploy, do NOT run this — it would
-- re-expose INSERT on notifications/analytics/error_logs.
--
-- SAFETY: Staging only. Re-run the privilege matrix after
-- rollback to confirm the pre-hardening state is restored.
--
-- Idempotent: all DROP/CREATE IF EXISTS.
-- ============================================================

BEGIN;

-- ─── 1. calculate_shipping_fee: restore pre-024 state ───────
-- The function body is functionally equivalent; the difference
-- is: no input validation, no safe search_path, PUBLIC execute.
DROP FUNCTION IF EXISTS calculate_shipping_fee(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION calculate_shipping_fee(
  p_governorate TEXT,
  p_subtotal    INTEGER
)
RETURNS INTEGER AS $$
DECLARE
  v_threshold INTEGER;
  v_fee INTEGER;
BEGIN
  SELECT value::INTEGER INTO v_threshold
  FROM shipping_config WHERE key = 'free_shipping_threshold';

  IF p_subtotal >= v_threshold THEN
    RETURN 0;
  END IF;

  SELECT sz.fee INTO v_fee
  FROM shipping_zones sz
  WHERE p_governorate = ANY(sz.governorates)
    AND sz.is_active = true
  LIMIT 1;

  IF v_fee IS NULL THEN
    SELECT value::INTEGER INTO v_fee
    FROM shipping_config WHERE key = 'default_fee';
  END IF;

  RETURN v_fee;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Restore PUBLIC execute (pre-024 state).
REVOKE ALL ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION calculate_shipping_fee(TEXT, INTEGER) TO PUBLIC;


-- ─── 2. notifications: restore permissive INSERT policy ─────
DROP POLICY IF EXISTS "notifications_insert_narrow" ON notifications;

CREATE POLICY "notifications_insert_service"
  ON notifications FOR INSERT
  WITH CHECK (true);


-- ─── 3. analytics_events: restore permissive INSERT policy ──
DROP POLICY IF EXISTS "analytics_insert_narrow" ON analytics_events;

CREATE POLICY "analytics_insert_service"
  ON analytics_events FOR INSERT
  WITH CHECK (true);


-- ─── 4. error_logs: restore permissive INSERT policy ────────
DROP POLICY IF EXISTS "error_logs_insert_narrow" ON error_logs;

CREATE POLICY "error_logs_insert_service"
  ON error_logs FOR INSERT
  WITH CHECK (true);


-- ─── 5. RPC grants: restore PUBLIC execute on all RPCs ──────
-- (Reverses the REVOKE statements in section 5 of migration 024.)
-- Note: process_paymob_callback remains service_role-only because
-- that was already hardened in migration 015/019 and must not be
-- rolled back (it would expose the callback to client callers).

GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO PUBLIC;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_order_details(UUID) TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_low_stock_products(INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION set_payment_provider_order_id(UUID, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION expire_pending_order(UUID) TO PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_stock(UUID, TEXT, TEXT, INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION increment_stock(UUID, TEXT, TEXT, INTEGER) TO PUBLIC;


COMMIT;
