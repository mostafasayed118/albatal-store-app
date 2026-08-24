-- ============================================================
-- Migration 031: realtime publication fix + pg_cron schedules (T0)
--
-- Fixes staging gap where payments (and support_messages when
-- present) were not in supabase_realtime publication, so
-- PaymobPaymentService.watchPaymentStatus realtime was dead.
-- Also schedules pg_cron jobs for expiry/rollups/retention.
--
-- Idempotent: safe to re-run. Extensions guarded with
-- IF NOT EXISTS. Publication ADD guarded via pg_publication_tables.
-- Cron jobs use unschedule-if-exists then schedule pattern.
-- ============================================================

-- Extensions (safe if already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Realtime publication fix: payments
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'payments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
  END IF;
END $$;
ALTER TABLE public.payments REPLICA IDENTITY FULL;

-- Realtime publication fix: support_messages (table may not exist yet — T4)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'support_messages'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = 'support_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
  END IF;
END $$;
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'support_messages'
  ) THEN
    -- Use dynamic SQL to avoid error if table absent at parse time
    EXECUTE 'ALTER TABLE public.support_messages REPLICA IDENTITY FULL';
  END IF;
END $$;

-- pg_cron schedules (idempotent: unschedule if exists then schedule)

-- cancel-expired-every-5m: every 5 minutes, expire pending orders
SELECT cron.unschedule('cancel-expired-every-5m')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cancel-expired-every-5m');
SELECT cron.schedule('cancel-expired-every-5m', '*/5 * * * *', $$SELECT public.expire_pending_order()$$);

-- analytics rollup daily at 03:00
SELECT cron.unschedule('analytics-rollup-daily')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-rollup-daily');
SELECT cron.schedule('analytics-rollup-daily', '0 3 * * *', $$REFRESH MATERIALIZED VIEW IF EXISTS analytics_daily$$);

-- audit retention 90d at 04:00
SELECT cron.unschedule('audit-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'audit-retention-90d');
SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $$DELETE FROM audit_logs WHERE created_at < now() - interval '90 days'$$);

-- analytics retention 90d at 04:00
SELECT cron.unschedule('analytics-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-retention-90d');
SELECT cron.schedule('analytics-retention-90d', '0 4 * * *', $$DELETE FROM analytics_events WHERE created_at < now() - interval '90 days'$$);
