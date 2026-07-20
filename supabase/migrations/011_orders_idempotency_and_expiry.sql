-- ============================================================
-- Migration 011: Add idempotency_key, expires_at, and missing
-- order_status values used by the checkout and payment cycle.
--
-- idempotency_key: prevents duplicate orders on network retry.
--   NULL = non-idempotent request (legacy). Non-NULL = client
--   supplied a key; CHECK constraint enforces uniqueness per user.
-- expires_at: orders that are still "pending" after this time
--   should be cancelled and stock restored by a scheduled function.
--
-- Order statuses: 'pending', 'processing', 'paid' are added here
-- so the checkout RPC (013) can reference them.
--
-- NOTE: PostgreSQL forbids using a newly-added enum value in a
-- CREATE INDEX WHERE clause within the same transaction. The
-- idx_orders_expires index therefore filters only on
-- expires_at IS NOT NULL. The cancel-expired-orders query adds
-- status = 'pending' in its WHERE clause, which is efficient
-- because the index narrows the scan to rows with a non-null
-- expires_at (the common case is NULL for completed orders).
--
-- Run AFTER 010_notifications_analytics.sql.
-- ============================================================

-- ─── Add missing order_status enum values ─────────────────
-- The original enum (001) had: placed, shipped, delivered,
-- cancelled, refunded. The checkout cycle needs 'pending' and
-- 'paid'; the admin fulfillment cycle needs 'processing'.
-- ADD VALUE IF NOT EXISTS is safe on Postgres 15+ (Supabase).
-- Each statement must be its own statement (cannot be combined).
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'paid';

-- ─── Add columns ──────────────────────────────────────────
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- ─── Unique constraint: one idempotency_key per user ──────
-- NULLs allowed (non-idempotent requests). The unique index
-- prevents duplicate orders on network retry for the same key.
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency
  ON orders (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ─── Index for the scheduled cleanup query ────────────────
-- Finds rows with a non-null expires_at so the cancel-expired-
-- orders function can efficiently scan for expired pending
-- orders. The status = 'pending' filter is applied in the
-- query's WHERE clause, not in the index, because PostgreSQL
-- forbids referencing a newly-added enum value in CREATE INDEX
-- within the same transaction as the ALTER TYPE ADD VALUE.
CREATE INDEX IF NOT EXISTS idx_orders_expires
  ON orders (expires_at)
  WHERE expires_at IS NOT NULL;
