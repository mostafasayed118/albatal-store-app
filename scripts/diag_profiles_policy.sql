-- profiles UPDATE policy: does WITH CHECK block is_admin self-escalation?
SELECT policyname, cmd, qual AS using_expr, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles'
ORDER BY policyname;
