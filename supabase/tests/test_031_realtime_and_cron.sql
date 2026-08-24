-- supabase/tests/test_031_realtime_and_cron.sql
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_031_realtime_and_cron.sql
-- Expected before migration: payments pub 0, replica identity != 'f', cron 0
-- Expected after migration: payments in publication = 1, replica identity = 'f', each cron = 1, batch wrapper exists = 1
-- Static checks: no DB required for syntax — the migration file itself is validated via grep for guarded cron bodies.

-- 1. payments in publication
SELECT 'payments in publication' AS check,
  (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='payments') AS cnt;
-- expect 1 after migration

-- 2. payments replica identity
SELECT 'payments replica identity' AS check,
  (SELECT relreplident FROM pg_class WHERE relname='payments') AS ri;
-- expect 'f' (FULL)

-- 3. cron: cancel-expired-every-5m
SELECT 'cron cancel-expired-every-5m' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='cancel-expired-every-5m') AS cnt;
-- expect 1

-- 4. cron: analytics-rollup-daily
SELECT 'cron analytics-rollup-daily' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='analytics-rollup-daily') AS cnt;
-- expect 1

-- 5. cron: audit-retention-90d
SELECT 'cron audit-retention-90d' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='audit-retention-90d') AS cnt;
-- expect 1

-- 6. cron: analytics-retention-90d
SELECT 'cron analytics-retention-90d' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='analytics-retention-90d') AS cnt;
-- expect 1

-- 7. batch wrapper exists and is SECURITY DEFINER (extra)
SELECT 'batch_expire_pending_orders exists' AS check,
  (SELECT count(*) FROM pg_proc WHERE proname='batch_expire_pending_orders') AS cnt;
-- expect 1
SELECT 'batch_expire_pending_orders secdef' AS check,
  (SELECT prosecdef FROM pg_proc WHERE proname='batch_expire_pending_orders') AS is_secdef;
-- expect true

-- 8. cron bodies are guarded (static sanity: job commands contain IF EXISTS / batch wrapper)
SELECT 'cron cancel body uses batch wrapper' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='cancel-expired-every-5m' AND command LIKE '%batch_expire_pending_orders%') AS cnt;
-- expect 1
SELECT 'cron analytics-rollup guarded' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='analytics-rollup-daily' AND command LIKE '%IF EXISTS%') AS cnt;
-- expect 1
SELECT 'cron audit-retention guarded' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='audit-retention-90d' AND command LIKE '%IF EXISTS%') AS cnt;
-- expect 1
SELECT 'cron analytics-retention guarded' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='analytics-retention-90d' AND command LIKE '%IF EXISTS%') AS cnt;
-- expect 1
