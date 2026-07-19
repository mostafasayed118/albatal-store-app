-- Add missing order_status values used by edge functions and the fulfillment trigger.
--
-- The checkout Edge Function inserts orders as "pending" (pre-payment).
-- The paymob-callback promotes them to "paid" on success.
-- The update_order_status trigger (008) transitions "placed" -> "processing".
-- "refunded" was already in the original enum (001) but not used by the client.
--
-- ALTER TYPE ... ADD VALUE is non-transactional in Postgres < 12, but
-- Supabase runs Postgres 15+, so it is safe inside a migration block.
-- Each ADD VALUE must be its own statement (cannot be combined).

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'paid';
