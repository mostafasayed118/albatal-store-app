-- ============================================================
-- Migration 027: Add payments INSERT policy for Edge Functions
--
-- PROBLEM:
--   Migration 019 removed payments_insert_own policy for defense
--   in depth. However, the paymob-initiate Edge Function uses the
--   user's JWT (not service_role) and needs to INSERT payment rows.
--   Without an INSERT policy, the Edge Function fails with:
--   "failed to create payment record"
--
-- FIX:
--   Add a narrow INSERT policy that allows authenticated users
--   to insert payment rows for their own orders only.
--
-- SECURITY:
--   - Only authenticated users can insert
--   - user_id must match auth.uid()
--   - order_id must reference an order owned by the user
--   - method must be non-empty
--   - amount must be positive
--
-- IDEMPOTENCY:
--   DROP POLICY IF EXISTS + CREATE POLICY IF NOT EXISTS
--
-- ROLLBACK (staging only):
--   DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON payments;
-- ============================================================

BEGIN;

-- Drop any existing INSERT policy to ensure clean state
DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON payments;

-- Create narrow INSERT policy for authenticated users
CREATE POLICY "payments_insert_authenticated_own"
  ON payments FOR INSERT
  TO authenticated
  WITH CHECK (
    -- user_id must match the authenticated user
    user_id = auth.uid()
    -- order_id must reference an order owned by this user
    AND order_id IN (
      SELECT id FROM orders
      WHERE user_id = auth.uid()
    )
    -- method must be non-empty
    AND method IS NOT NULL
    AND length(method) > 0
    -- amount must be positive
    AND amount > 0
  );

COMMIT;
