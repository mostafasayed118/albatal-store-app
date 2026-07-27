-- ============================================================
-- Migration 019: Harden RPC and payments authorization
--
-- SECURITY DEFICIT (authz hardening):
--   Three user-facing RPCs were executable by PUBLIC, allowing
--   anonymous (anon role) callers to invoke them. While each
--   function verifies auth.uid() internally, relying on
--   in-function checks alone is a defense-in-depth failure: a
--   future refactor or a PostgREST misconfiguration could
--   expose them. The least-privilege posture is to REVOKE from
--   PUBLIC and grant only to `authenticated`.
--
--   1. create_checkout_order (TEXT, JSONB, JSONB, TEXT)
--        Granted TO PUBLIC in migration 013 (line 249).
--   2. update_order_status (UUID, TEXT, TEXT)
--        Granted TO PUBLIC in migration 014 (line 188).
--        Migration 015's comment claims it "remains executable
--        by authenticated callers" but the live grant is TO
--        PUBLIC — this migration makes the grant match the
--        intended security model.
--   3. confirm_cod_payment (UUID)
--        Already restricted in migration 018 (lines 239-240);
--        re-asserted here for a single source of truth and
--        idempotency under re-run.
--
--   4. process_paymob_callback (TEXT, TEXT, INTEGER, TEXT, BOOLEAN)
--        Granted TO PUBLIC in migration 014 (line 410).
--        Restricted to service_role in migration 015; re-asserted
--        here so the final desired state is explicit and survives
--        any future re-grant to PUBLIC. Anonymous and authenticated
--        clients must never execute the callback directly — HMAC
--        verification happens in the Edge Function before this RPC.
--
--   5. payments_insert_own policy (migration 006, lines 35-38)
--        Allowed any authenticated user to INSERT a payment row
--        directly. Payments must only be created by:
--          * create_checkout_order / confirm_cod_payment RPCs
--            (SECURITY DEFINER, bypass RLS)
--          * the Paymob initiation Edge Function (service_role,
--            bypass RLS)
--          * service_role server-side logic (bypass RLS)
--        Direct client INSERT is removed. RLS is enabled on
--        payments (migration 006 line 28), so with no INSERT
--        policy the default-deny posture blocks client inserts.
--
-- IDEMPOTENCY:
--   REVOKE is a no-op when the privilege is absent.
--   GRANT EXECUTE is a no-op when the privilege is already held.
--   DROP POLICY IF EXISTS is a no-op when the policy is absent.
--   Safe to apply after migrations 001-018 and safe to re-run.
--
-- DOES NOT:
--   * modify application data
--   * drop tables
--   * delete existing migrations
--   * touch secrets / .env / auth / payments-config
--
-- ROLLBACK (staging only — do NOT roll back after production deploy):
--   GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT,JSONB,JSONB,TEXT) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION update_order_status(UUID,TEXT,TEXT) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT,TEXT,INTEGER,TEXT,BOOLEAN) TO PUBLIC;
--   CREATE POLICY "payments_insert_own" ON payments
--     FOR INSERT WITH CHECK (auth.uid() = user_id);
-- ============================================================

-- ─── 1. create_checkout_order: authenticated only ──────────
REVOKE ALL ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_checkout_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- ─── 2. update_order_status: authenticated (admin-checked internally) ─
-- The RPC verifies profiles.is_admin inside (migration 014), so
-- authenticated execute is safe; non-admins are rejected at the
-- function body even though they can reach the entry point.
REVOKE ALL ON FUNCTION update_order_status(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, TEXT) TO authenticated;

-- ─── 3. confirm_cod_payment: authenticated only ─────────────
-- Already restricted in migration 018; re-asserted here so the
-- final desired state lives in one migration and survives re-runs.
REVOKE ALL ON FUNCTION confirm_cod_payment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION confirm_cod_payment(UUID) TO authenticated;

-- ─── 4. process_paymob_callback: service_role only ──────────
-- Revoke from every client-facing role, then grant only to the
-- service_role that the Edge Function uses after HMAC verification.
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM authenticated;
REVOKE ALL ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION process_paymob_callback(TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO service_role;

-- ─── 5. Remove direct client INSERT on payments ─────────────
-- After this drop, an authenticated client has no INSERT policy
-- on payments. Because RLS is enabled on the table (migration
-- 006), the absence of an INSERT policy means default-deny: no
-- client row can be inserted. The only paths that create payment
-- rows are SECURITY DEFINER RPCs and the service_role Edge
-- Function, both of which bypass RLS.
DROP POLICY IF EXISTS "payments_insert_own" ON public.payments;
