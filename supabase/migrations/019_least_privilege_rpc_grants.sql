-- ============================================================
-- Migration 019: Least-privilege RPC grants
--
-- PROBLEM:
--   Migrations 013 and 014 granted PUBLIC execute on
--   `create_checkout_order` and `update_order_status`. PUBLIC
--   includes the `anon` role, meaning unauthenticated callers
--   can invoke these RPCs. Both functions have internal auth
--   checks (auth.uid() / profiles.is_admin) that reject misuse,
--   but the PUBLIC grant violates the principle of least
--   privilege and allows unauthenticated callers to consume
--   server resources on the denial path.
--
-- FIX:
--   Revoke PUBLIC and anon, then grant EXECUTE to `authenticated`
--   only. In Supabase, `REVOKE FROM PUBLIC` alone does not remove
--   the `anon` role's inherited grant — an explicit `REVOKE FROM
--   anon` is required. Both RPCs are SECURITY DEFINER and verify
--   the caller's identity internally, so this change does not
--   alter the behavior for authorized users.
--
-- CALLERS (unchanged by this migration):
--   `create_checkout_order`:
--     - Flutter client via Supabase authenticated session
--       (checkout_service.dart:42)
--     - checkout Edge Function with user JWT
--       (checkout/index.ts:65)
--   `update_order_status`:
--     - Flutter admin client via Supabase authenticated session
--       (supabase_admin_repository.dart:60)
--
-- CONVENTION:
--   Follows the pattern established in migration 015 which
--   restricted `process_paymob_callback` to `service_role` and
--   `set_payment_provider_order_id` to `authenticated`.
--
-- SAFETY:
--   - Does not modify function definitions (no CREATE/ALTER FUNCTION)
--   - Does not weaken internal authorization checks
--   - Only changes GRANT/REVOKE on execution privilege
--   - Forward-only; idempotent (REVOKE IF EXISTS / GRANT are safe)
--
-- ROLLBACK:
--   GRANT EXECUTE ON FUNCTION create_checkout_order TO PUBLIC;
--   GRANT EXECUTE ON FUNCTION update_order_status TO PUBLIC;
-- ============================================================

-- ─── create_checkout_order: PUBLIC → authenticated ──────────
-- The RPC checks `auth.uid() IS NULL` at line 58 of migration
-- 013 and raises 'Authentication required'. Unauthenticated
-- callers are already rejected; this migration removes their
-- ability to invoke the function at all.
REVOKE EXECUTE ON FUNCTION create_checkout_order(
  TEXT, JSONB, JSONB, TEXT
) FROM PUBLIC;

-- Supabase's anon role inherits from PUBLIC; explicit revoke
-- is required to remove the inherited grant.
REVOKE EXECUTE ON FUNCTION create_checkout_order(
  TEXT, JSONB, JSONB, TEXT
) FROM anon;

GRANT EXECUTE ON FUNCTION create_checkout_order(
  TEXT, JSONB, JSONB, TEXT
) TO authenticated;

-- ─── update_order_status: PUBLIC → authenticated ────────────
-- The RPC checks `profiles.is_admin` at lines 110-117 of
-- migration 014 and raises 'Admin access required'. Both
-- authenticated admins and non-admins can reach the function;
-- non-admins are rejected internally. This migration removes
-- anon access.
REVOKE EXECUTE ON FUNCTION update_order_status(
  UUID, TEXT, TEXT
) FROM PUBLIC;

-- Supabase's anon role inherits from PUBLIC; explicit revoke
-- is required to remove the inherited grant.
REVOKE EXECUTE ON FUNCTION update_order_status(
  UUID, TEXT, TEXT
) FROM anon;

GRANT EXECUTE ON FUNCTION update_order_status(
  UUID, TEXT, TEXT
) TO authenticated;
