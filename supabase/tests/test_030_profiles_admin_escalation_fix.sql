-- test_030_profiles_admin_escalation_fix.sql
-- Read-only verification for migration 030.

-- 1. Unsafe policy must be absent.
SELECT count(*) AS unsafe_policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
  AND policyname = 'profiles_update_own';

-- Expected: 0

-- 2. Safe policy must be present.
SELECT count(*) AS safe_policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
  AND policyname = 'profiles_update_own_safe';

-- Expected: 1

-- 3. Safe policy must have a non-null WITH CHECK.
SELECT
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
  AND policyname = 'profiles_update_own_safe';

-- Expected:
-- with_check is not null

-- 4. No remaining UPDATE policy on profiles with null WITH CHECK.
SELECT
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
  AND cmd = 'UPDATE'
  AND with_check IS NULL;

-- Expected: 0 rows
