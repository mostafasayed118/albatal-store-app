-- ═══════════════════════════════════════════════════════════
-- Migration 079: lock stock_restorations, rate_limits RLS,
--                handle_new_user search_path hardening
-- ═══════════════════════════════════════════════════════════
-- AUDIT-2026-10-05 (comprehensive code quality audit):
--   HIGH-1: stock_restorations (created in 014:195) had no RLS and
--     no grant lockdown. Under Supabase default grants any client
--     could read other customers' restoration history and pre-insert
--     a row, which makes the cancel path skip the stock restore (the
--     WHERE NOT EXISTS guard in 014's treat-cancel). Same exploit
--     class as state_transitions, fixed in 034.
--   LOW-1: rate_limits (060) relied on revoke-only. Enable RLS as
--     defense-in-depth so a future re-grant cannot expose per-caller
--     buckets. No policies: access stays via rate_limit_take()
--     SECURITY DEFINER (definer bypasses RLS; behavior unchanged).
--   LOW-2: handle_new_user() (003) is SECURITY DEFINER without a
--     pinned search_path. Re-created with SET search_path = '' and a
--     fully schema-qualified body (Supabase hardening pattern; body
--     semantics unchanged).
-- Idempotent: safe to re-run.

-- ── 1. stock_restorations ──────────────────────────────────

ALTER TABLE public.stock_restorations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.stock_restorations FROM anon;
REVOKE ALL ON public.stock_restorations FROM authenticated;
REVOKE ALL ON public.stock_restorations FROM PUBLIC;
-- service_role bypasses RLS and retains its default grants: untouched.
-- No policies: the only writer/reader is the SECURITY DEFINER order
-- state-machine function (014/025), which is unaffected by RLS.

COMMENT ON TABLE public.stock_restorations IS
  'Cancel-once ledger for stock restoration (014). RLS-locked in 079: '
  'no client policies — rows are written/read only via the SECURITY '
  'DEFINER order state-machine function; service_role bypasses RLS.';

-- ── 2. rate_limits (defense-in-depth) ──────────────────────

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
-- No policies: grants were already fully revoked in 060; RLS here only
-- guards against a future re-grant. rate_limit_take() is SECURITY
-- DEFINER (060) and bypasses RLS.

COMMENT ON TABLE public.rate_limits IS
  'Per-caller rate-limit counters for edge functions (060). RLS '
  'enabled in 079 as defense-in-depth; access stays via '
  'rate_limit_take().';

-- ── 3. handle_new_user() search_path hardening ─────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Profile auto-creation on auth.users insert (003). Re-created in 079 '
  'with SET search_path = '''' and a schema-qualified body (hardening '
  'only; semantics unchanged).';
