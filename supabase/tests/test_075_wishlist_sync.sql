-- supabase/tests/test_075_wishlist_sync.sql  (DRAFT for human review)
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_075_wishlist_sync.sql
-- Expected before migration 075: table public.wishlists does not exist,
--   function sync_wishlist does not exist.
-- Expected after migration:
--   * as anon: sync_wishlist raises 42501 (Authentication required);
--     direct SELECT on wishlists returns 0 rows (RLS, no anon policy).
--   * as authenticated non-owner: cannot read/insert another user's rows.
--   * as authenticated owner: insert/select/delete own rows; sync_wishlist
--     merges idempotently; bogus UUIDs ignored; cap enforced at 200.
--
-- NOTE: the authenticated sections below need a real JWT context (staging).
-- They are written as commented psql blocks: run with a user session, or
-- adapt into test_rls_adversarial.sql harness style.

-- 1. Objects exist with correct security attributes
SELECT 'wishlists table' AS check,
  (SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename='wishlists') AS cnt;
-- expect 1
SELECT 'wishlists rls' AS check,
  (SELECT relrowsecurity FROM pg_class WHERE relname='wishlists') AS enabled;
-- expect true
SELECT 'sync_wishlist secdef' AS check,
  (SELECT prosecdef FROM pg_proc WHERE proname='sync_wishlist') AS is_secdef;
-- expect true
SELECT 'sync_wishlist volatile' AS check,
  (SELECT provolatile FROM pg_proc WHERE proname='sync_wishlist') AS volatility;
-- expect 'v' (VOLATILE — it writes)
SELECT 'sync_wishlist anon revoked' AS check,
  (SELECT count(*) FROM information_schema.routine_privileges
    WHERE routine_name='sync_wishlist' AND grantee='anon') AS cnt;
-- expect 0
SELECT 'sync_wishlist authenticated granted' AS check,
  (SELECT count(*) FROM information_schema.routine_privileges
    WHERE routine_name='sync_wishlist' AND grantee='authenticated') AS cnt;
-- expect 1
SELECT 'cap check exists' AS check,
  (SELECT count(*) FROM pg_constraint WHERE conname='wishlists_per_user_cap_check') AS cnt;
-- expect 1

-- 2. Anon: function raises, table invisible
SELECT public.sync_wishlist('{}');
-- expect: ERROR Authentication required (SQLSTATE 42501)
SELECT count(*) AS anon_visible_rows FROM public.wishlists;
-- expect: 0 (RLS owner-only, anon sees nothing — NOT an error)

-- 3. Authenticated owner (run in a user session on staging):
--   a) sync empty → returns current server set, wipes nothing:
--      SELECT public.sync_wishlist(NULL);
--      -- expect: current UUID[] (possibly '{}'), no rows deleted.
--   b) sync two real product ids twice → second call changes nothing:
--      SELECT public.sync_wishlist(ARRAY[(SELECT id FROM products LIMIT 1)]);
--      SELECT public.sync_wishlist(ARRAY[(SELECT id FROM products LIMIT 1)]);
--      -- expect: same 1-element array both times (idempotent).
--   c) bogus UUID ignored, no error:
--      SELECT public.sync_wishlist(ARRAY['00000000-0000-0000-0000-000000000000'::UUID]);
--      -- expect: unchanged array.
--   d) direct INSERT of a 201st row fails on the cap CHECK (needs 200 rows
--      staged first — loop in psql or the adversarial harness).
--   e) cross-user: as user B, SELECT/INSERT with user_id of user A → 0 rows
--      visible / 42501-or-RLS-violation on write (policy WITH CHECK fails).
