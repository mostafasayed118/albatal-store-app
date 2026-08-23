SELECT relname, relrowsecurity, relforcerowsecurity,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='payments' AND cmd IN ('INSERT','ALL')) AS insert_policy_count,
  (SELECT string_agg(policyname || ':' || cmd, ', ') FROM pg_policies WHERE schemaname='public' AND tablename='payments') AS policies
FROM pg_class WHERE oid = 'public.payments'::regclass;
