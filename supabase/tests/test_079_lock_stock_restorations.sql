-- supabase/tests/test_079_lock_stock_restorations.sql  (DRAFT for human review)
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_079_lock_stock_restorations.sql
-- Run AFTER applying 079, as the table owner (postgres) so information_schema
-- lists every grant. Static checks are read-only; the live role probes at the
-- bottom are commented out and ROLLBACK everything.
-- Expected BEFORE 079: stock_restorations relrowsecurity=false and holding
-- default Supabase client grants (the pre-insert exploit); rate_limits
-- relrowsecurity=false (grants already revoked in 060); handle_new_user
-- proconfig NULL. update_order_status (014) checks are a regression guard.

-- ─── 1. stock_restorations: RLS on, no policies, no client grants ─────
SELECT 'stock_restorations rls enabled' AS check,
  (SELECT relrowsecurity FROM pg_class
    WHERE oid='public.stock_restorations'::regclass) AS value;
-- expect true (42P01 here means the table itself is missing)
SELECT 'stock_restorations policies' AS check,
  (SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='stock_restorations') AS value;
-- expect 0 (no policies: RLS denies every role that does not bypass it)
SELECT 'stock_restorations client grants' AS check,
  (SELECT count(*) FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='stock_restorations'
      AND grantee IN ('anon','authenticated','PUBLIC')) AS value;
-- expect 0 (SELECT = history leak; INSERT = the cancel-path exploit)
SELECT 'stock_restorations service_role intact' AS check,
  (has_table_privilege('service_role', 'public.stock_restorations', 'SELECT')
   AND has_table_privilege('service_role', 'public.stock_restorations', 'INSERT')) AS value;
-- expect true (service_role bypasses RLS and keeps its default grants)

-- ─── 2. rate_limits: RLS on, no policies, still revoke-only for clients ─
SELECT 'rate_limits rls enabled' AS check,
  (SELECT relrowsecurity FROM pg_class
    WHERE oid='public.rate_limits'::regclass) AS value;
-- expect true
SELECT 'rate_limits policies' AS check,
  (SELECT count(*) FROM pg_policies
    WHERE schemaname='public' AND tablename='rate_limits') AS value;
-- expect 0
SELECT 'rate_limits client grants' AS check,
  (SELECT count(*) FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='rate_limits'
      AND grantee IN ('anon','authenticated','PUBLIC')) AS value;
-- expect 0 (access stays via rate_limit_take(), SECURITY DEFINER)

-- ─── 3. handle_new_user: definer + pinned empty search_path, trigger alive ─
SELECT 'handle_new_user secdef' AS check,
  (SELECT prosecdef FROM pg_proc
    WHERE oid='public.handle_new_user()'::regprocedure) AS value;
-- expect true
SELECT 'handle_new_user search_path pinned (empty)' AS check,
  COALESCE((SELECT bool_or(c ~ '^search_path=(""|)$') FROM pg_proc p,
      unnest(p.proconfig) c
    WHERE p.oid='public.handle_new_user()'::regprocedure), false) AS value;
-- expect true (079 re-creates with SET search_path = '')
SELECT 'on_auth_user_created wiring' AS check,
  (SELECT p.proname FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
    WHERE t.tgrelid='auth.users'::regclass AND t.tgname='on_auth_user_created'
      AND NOT t.tgisinternal) AS value;
-- expect handle_new_user (NULL = trigger missing or dropped by 079)

-- ─── 4. update_order_status: definer + pinned search_path (regression) ──
SELECT 'update_order_status secdef' AS check,
  (SELECT prosecdef FROM pg_proc
    WHERE oid='public.update_order_status(uuid,text,text)'::regprocedure) AS value;
-- expect true
SELECT 'update_order_status search_path pinned' AS check,
  (SELECT c FROM pg_proc p, unnest(p.proconfig) c
    WHERE p.oid='public.update_order_status(uuid,text,text)'::regprocedure
      AND c LIKE 'search_path=%') AS value;
-- expect 'search_path=public, auth' (014; unchanged by 079)

-- ─── 5. Live role checks — staging only; uncomment and run block by block ─
-- Needs a superuser/owner session (SET ROLE). Each block is standalone: an
-- expected error aborts only that block's transaction. No real IDs/data used.
-- (a) anon direct ledger read is denied (was readable before 079):
/*
BEGIN;
SET LOCAL ROLE anon;
SELECT count(*) FROM public.stock_restorations;
ROLLBACK;
-- expect: ERROR permission denied for table stock_restorations (SQLSTATE 42501)
*/
-- (b) authenticated pre-insert into the ledger — THE EXPLOIT — now denied:
--     42501 = fixed. 23503 (FK violation) instead would mean the privilege
--     is still open and only the fake order id was rejected.
/*
BEGIN;
SET LOCAL ROLE authenticated;
INSERT INTO public.stock_restorations (order_id)
  VALUES ('00000000-0000-0000-0000-000000000000'::uuid);
ROLLBACK;
-- expect: 42501 permission denied, NOT 23503
*/
-- (c) authenticated rate_limit_take() still works: 060 SECURITY DEFINER
--     bypasses RLS, and the probe row is rolled back. The bucket must match
--     070's allowlist ^(acct|init|proof|cb|validate_coupon):...
/*
BEGIN;
SET LOCAL ROLE authenticated;
SELECT public.rate_limit_take('proof:test079', 1, 60) AS allowed;
ROLLBACK;
-- expect: true
*/
-- (d) service_role keeps full ledger access (definer/service paths):
/*
BEGIN;
SET LOCAL ROLE service_role;
SELECT count(*) FROM public.stock_restorations;
ROLLBACK;
-- expect: a count, no error
*/
-- (e) update_order_status still reachable and still admin-gated; proves the
--     definer body resolves under its pinned search_path:
/*
BEGIN;
SET LOCAL ROLE authenticated;
SELECT public.update_order_status(
  '00000000-0000-0000-0000-000000000000'::uuid, 'cancelled');
ROLLBACK;
-- expect: P0001 Admin access required (not 42501 / 42883)
*/
-- (f) End-to-end restore-once proof (staging, admin JWT): with a pending order
--     that reserved stock, cancel via update_order_status and expect exactly
--     one stock_restorations row plus a one-time variant stock increment
--     (test_078 setup style). This is the path 079 must not break.
-- (g) handle_new_user: create a throwaway user through the Admin API, then
--     expect one auto-created public.profiles row; delete the user afterwards.
--     Trigger functions cannot be called directly (0A000).
