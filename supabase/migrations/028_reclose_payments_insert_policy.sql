-- ============================================================
-- Migration 028: Re-close direct payment INSERT after migration 027
--
-- Migration 027 accidentally reopened authenticated direct INSERT on
-- payments so paymob-initiate could persist a row through the caller JWT.
-- That contradicts the approved payment boundary: payment rows are created
-- only by SECURITY DEFINER RPCs or trusted service-role Edge Functions.
--
-- The paymob-initiate function is repaired in the same candidate to use a
-- service-role client only for its server-generated payment INSERT. Its
-- caller-scoped client remains responsible for authentication, ownership
-- reads, and the ownership-checked provider-order RPC.
--
-- Forward-only and idempotent. This file is repository evidence only until
-- a separately approved staging migration run is performed.
-- ============================================================

BEGIN;

DROP POLICY IF EXISTS "payments_insert_authenticated_own" ON public.payments;
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;

COMMIT;
