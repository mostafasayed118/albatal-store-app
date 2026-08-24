-- supabase/tests/test_031_realtime_and_cron.sql
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_031_realtime_and_cron.sql
-- Expected before migration: 0 rows for payments in publication, cron 0
-- Expected after migration: payments in publication = 1, replica identity = 'f', cron = 1

SELECT 'payments in publication' AS check,
  (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='payments') AS cnt;
-- expect 1 after migration

SELECT 'payments replica identity' AS check,
  (SELECT relreplident FROM pg_class WHERE relname='payments') AS ri;
-- expect 'f' (FULL)

SELECT 'cron job exists' AS check,
  (SELECT count(*) FROM cron.job WHERE jobname='cancel-expired-every-5m') AS cnt;
-- expect 1
