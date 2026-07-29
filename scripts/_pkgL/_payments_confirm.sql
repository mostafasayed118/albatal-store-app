SELECT 'rls' AS kind, c.relname AS name, c.relrowsecurity::text AS detail
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'payments'
UNION ALL
SELECT 'policy' AS kind, p.policyname AS name, p.cmd AS detail
FROM pg_policies p
WHERE p.schemaname = 'public' AND p.tablename = 'payments'
ORDER BY kind, name;
