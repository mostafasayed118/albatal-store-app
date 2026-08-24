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
CREATE EXTENSION IF NOT EXISTS pg_net; -- retained for send-order-notification via pg_net.http_post; remove if trigger migrates to external scheduler
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

-- ── Batch expiry wrapper (fixes zero-arg expire_pending_order call) ──
-- expire_pending_order(UUID) requires an order id; pg_cron must call
-- a zero-arg wrapper that scans for expired pending orders.
CREATE OR REPLACE FUNCTION public.batch_expire_pending_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.expire_pending_order(id)
  FROM public.orders
  WHERE status = 'pending'
    AND expires_at < now();
END;
$$;

REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.batch_expire_pending_orders() FROM anon;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION public.batch_expire_pending_orders() TO service_role;

-- pg_cron schedules (idempotent: unschedule if exists then schedule)

-- cancel-expired-every-5m: every 5 minutes, expire pending orders via batch wrapper
SELECT cron.unschedule('cancel-expired-every-5m')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cancel-expired-every-5m');
SELECT cron.schedule('cancel-expired-every-5m', '*/5 * * * *', $$SELECT public.batch_expire_pending_orders()$$);

-- analytics rollup daily at 03:00 (guarded: matview may not exist yet — T2)
SELECT cron.unschedule('analytics-rollup-daily')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-rollup-daily');
SELECT cron.schedule('analytics-rollup-daily', '0 3 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname='analytics_daily') THEN EXECUTE 'REFRESH MATERIALIZED VIEW analytics_daily'; END IF; END $do$ $cron$);

-- audit retention 90d at 04:00 (guarded: audit_logs does not exist — audit is state_transitions; guard keeps cron valid)
SELECT cron.unschedule('audit-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'audit-retention-90d');
SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='audit_logs') THEN DELETE FROM public.audit_logs WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);

-- analytics retention 90d at 04:00 (guarded for idempotency; analytics_events exists per 010)
SELECT cron.unschedule('analytics-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'analytics-retention-90d');
SELECT cron.schedule('analytics-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='analytics_events') THEN DELETE FROM public.analytics_events WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);
