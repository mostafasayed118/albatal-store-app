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
-- profiles_update_own_safe remains as the guard.
--
-- Forward-only, idempotent: DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
-- This file is repository evidence only until a separately approved staging
-- migration run is performed. Human review required before supabase db push.
-- ============================================================

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
