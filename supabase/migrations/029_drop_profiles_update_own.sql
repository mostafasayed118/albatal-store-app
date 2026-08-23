-- ============================================================
-- Migration 029: drop redundant profiles_update_own that defeats is_admin guard (RLS-ESC-001)
-- See STATE.md:27-38 and audit report for context
--
-- Two permissive UPDATE policies on profiles existed:
--   - profiles_update_own (002_rls_policies.sql:32, USING auth.uid()=id, no WITH CHECK)
--   - profiles_update_own_safe (003_auth_profiles_and_hardening.sql:88, WITH CHECK is_admin guard)
-- Permissive OR + null WITH CHECK falls back to USING, so any auth user could
-- UPDATE is_admin=true. This migration drops the old policy.
--
-- Local docker variant `users can update own profile` (with_check auth.uid()=id)
-- is also permissive and must be replaced. This migration is idempotent
-- and handles all known names, then recreates the single safe policy.
--
-- Forward-only, idempotent. Human review required before supabase db push.
-- ============================================================

-- Drop all known variants of the permissive UPDATE policy
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_safe" ON public.profiles;

-- Recreate the single safe policy: only allow is_admin to stay as it was
CREATE POLICY "profiles_update_own_safe"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
  );
