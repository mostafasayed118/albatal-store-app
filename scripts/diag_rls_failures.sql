-- Read-only diagnosis of the 3 RLS adversarial failures (3.7, 3.8, 3.9).
-- No mutations.

-- 3.7 profiles UPDATE policy: does WITH CHECK block is_admin self-escalation?
SELECT policyname, cmd, qual AS using_expr, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles'
ORDER BY policyname;

-- 3.8 / 3.9 admin-only function bodies: do they RAISE for non-admin, or return empty?
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef AS security_definer,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec,
       pg_get_functiondef(p.oid) AS body
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_low_stock_products', 'get_order_details')
ORDER BY p.proname;
