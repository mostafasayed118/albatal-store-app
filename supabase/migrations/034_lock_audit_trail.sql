-- ═══════════════════════════════════════════════════════════
-- Migration 034: lock state transitions audit trail
-- ═══════════════════════════════════════════════════════════
-- AUDIT-2026-08-24 HIGH-1:
--   * state_transitions had no RLS and no policies. Under Supabase
--     default grants, any client could read the full forensic trail
--     (incl. Paymob txn ids in metadata) and insert/update/delete rows.
--   * audit_transition() was SECURITY DEFINER with default PUBLIC
--     execute, allowing forged audit rows via PostgREST.
--
-- Fix:
--   1. Enable RLS; single admin-only SELECT policy (pattern from 032).
--   2. Grant-tighten the table: authenticated gets SELECT (filtered by
--      the policy); anon gets nothing. Writes stay service_role-only.
--   3. Revoke EXECUTE on audit_transition from PUBLIC/anon/authenticated.
--      Internal callers are SECURITY DEFINER functions running as the
--      owner, so they are unaffected by EXECUTE revokes.
-- Idempotent: safe to re-run.

-- ── 1. Table hardening ─────────────────────────────────────

ALTER TABLE public.state_transitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS state_transitions_select_admin
  ON public.state_transitions;

CREATE POLICY state_transitions_select_admin
  ON public.state_transitions
  FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);

REVOKE ALL ON public.state_transitions FROM anon;
REVOKE ALL ON public.state_transitions FROM authenticated;
GRANT SELECT ON public.state_transitions TO authenticated;
-- service_role bypasses RLS and retains its default grants: untouched.

-- ── 2. Helper function hardening ───────────────────────────

REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM PUBLIC;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM anon;
REVOKE ALL ON FUNCTION public.audit_transition(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB)
FROM authenticated;
