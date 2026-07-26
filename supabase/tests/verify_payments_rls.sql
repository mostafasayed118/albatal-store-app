-- Check payments RLS policies
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'payments'
ORDER BY policyname;
