-- RLS state + policies + triggers on payments (read-only)
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class WHERE oid = 'public.payments'::regclass;

SELECT policyname, cmd, roles::text, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'payments'
ORDER BY policyname;

SELECT tgname, tgenabled, pg_get_triggerdef(oid) AS def
FROM pg_trigger
WHERE tgrelid = 'public.payments'::regclass AND NOT tgisinternal
ORDER BY tgname;
