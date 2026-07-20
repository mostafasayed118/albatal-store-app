-- ============================================================
-- Combined Migration Script for Al Batal Elite
--
-- Runs ALL migrations (001-013) in order. Use this with the
-- Supabase SQL Editor or a PostgreSQL client to set up a
-- fresh database from scratch.
--
-- USAGE:
--   1. Open Supabase Dashboard → SQL Editor
--   2. Paste this entire script
--   3. Click "Run"
--
-- For an EXISTING database, skip migrations already applied.
-- Run only the NEW migrations (check supabase/migrations/ for
-- what's new).
--
-- After running, execute verify_schema.sql to confirm.
-- ============================================================

-- Suppress notices for cleaner output
SET client_min_messages = warning;

\echo '============================================================'
\echo 'Migration 001: Initial Schema'
\echo '============================================================'

-- (Inline the content of 001_initial_schema.sql here)
-- See supabase/migrations/001_initial_schema.sql

\echo '============================================================'
\echo 'Migration 002: RLS Policies'
\echo '============================================================'

-- (Inline the content of 002_rls_policies.sql here)

\echo '============================================================'
\echo 'Migration 003: Auth, Profiles & Admin Role'
\echo '============================================================'

-- (Inline the content of 003_auth_profiles_and_hardening.sql here)

\echo '============================================================'
\echo 'Migration 004: Stock Decrement Function'
\echo '============================================================'

-- (Inline the content of 004_stock_function.sql here)

\echo '============================================================'
\echo 'Migration 005: Storage Buckets'
\echo '============================================================'

-- (Inline the content of 005_storage_buckets.sql here)

\echo '============================================================'
\echo 'Migration 006: Payments Table'
\echo '============================================================'

-- (Inline the content of 006_payments_table.sql here)

\echo '============================================================'
\echo 'Migration 007: Stock Increment Function'
\echo '============================================================'

-- (Inline the content of 007_stock_increment_function.sql here)

\echo '============================================================'
\echo 'Migration 008: Order Fulfillment Functions'
\echo '============================================================'

-- (Inline the content of 008_order_fulfillment.sql here)

\echo '============================================================'
\echo 'Migration 009: Shipping Zones'
\echo '============================================================'

-- (Inline the content of 009_shipping_zones.sql here)

\echo '============================================================'
\echo 'Migration 010: Notifications & Analytics'
\echo '============================================================'

-- (Inline the content of 010_notifications_analytics.sql here)

\echo '============================================================'
\echo 'Migration 011: Idempotency, Expiry & Order Statuses'
\echo '============================================================'

-- (Inline the content of 011_orders_idempotency_and_expiry.sql here)

\echo '============================================================'
\echo 'Migration 012: Additional Order Statuses (idempotent)'
\echo '============================================================'

-- (Inline the content of 012_add_order_statuses.sql here)

\echo '============================================================'
\echo 'Migration 013: Atomic Checkout RPC'
\echo '============================================================'

-- (Inline the content of 013_atomic_checkout_rpc.sql here)

\echo '============================================================'
\echo 'All migrations complete!'
\echo '============================================================'
