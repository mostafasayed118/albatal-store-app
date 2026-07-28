-- 030_fix_profiles_admin_escalation.sql
--
-- Remediation for RLS-ESC-001.
--
-- Root cause:
-- profiles_update_own was created in migration 002 with no WITH CHECK.
-- profiles_update_own_safe was created in migration 003 to guard is_admin.
-- Postgres OR-combines permissive policies.
-- The older unsafe policy defeats the newer safe policy, allowing:
--   UPDATE profiles SET is_admin = true WHERE id = auth.uid();
--
-- Fix:
-- Drop the redundant unsafe policy profiles_update_own.
-- Keep profiles_update_own_safe.
--
-- This migration does not modify data.
-- This migration does not renumber migrations.
-- This migration does not modify Edge Functions.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'profiles_update_own_safe'
  ) THEN
    RAISE EXCEPTION 'profiles_update_own_safe is missing; refusing to drop profiles_update_own';
  END IF;
END
$$;

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

COMMIT;
