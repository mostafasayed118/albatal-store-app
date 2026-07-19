-- ============================================================
-- Migration 011: Add idempotency_key and expires_at to orders
-- Run AFTER 010_notifications_analytics.sql
--
-- idempotency_key: prevents duplicate orders on network retry.
--   NULL = non-idempotent request (legacy). Non-NULL = client
--   supplied a key; CHECK constraint enforces uniqueness per user.
-- expires_at: orders that are still "pending" after this time
--   should be cancelled and stock restored by a scheduled function.
-- ============================================================

-- Add columns
ALTER TABLE orders
  ADD COLUMN idempotency_key TEXT,
  ADD COLUMN expires_at TIMESTAMPTZ;

-- Unique constraint: one idempotency_key per user (NULLs allowed)
-- This prevents duplicate orders while still allowing non-idempotent requests.
CREATE UNIQUE INDEX idx_orders_idempotency
  ON orders (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Index for the scheduled cleanup query (find expired pending orders)
CREATE INDEX idx_orders_expires
  ON orders (expires_at)
  WHERE status = 'pending' AND expires_at IS NOT NULL;
