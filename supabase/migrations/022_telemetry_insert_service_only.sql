-- ============================================================
-- Migration 022: Telemetry tables — service-role writes only
--
-- PROBLEM:
--   Migration 010 created INSERT policies named
--   `notifications_insert_service`, `analytics_insert_service`, and
--   `error_logs_insert_service` with `WITH CHECK (true)`. Despite the
--   names, those policies allow any role that can reach the table as
--   an INSERT subject (typically anon/authenticated via PostgREST)
--   to insert arbitrary rows — spam / cost / fake notification history.
--
-- FIX:
--   DROP the open INSERT policies. Do not replace them with client
--   INSERT policies. Supabase `service_role` bypasses RLS and remains
--   the write path for Edge Functions (e.g. send-order-notification
--   inserts into `notifications` with the service-role key).
--
-- PRESERVED:
--   - notifications_select_own (owner via order)
--   - admin_select_analytics
--   - admin_select_errors
--
-- WRITE MODEL (documented):
--   - notifications: Edge `send-order-notification` + service_role
--   - analytics_events / error_logs: service_role only (no Flutter
--     client inserts found in lib/ at authoring time)
--
-- SAFETY:
--   - Forward-only; DROP POLICY IF EXISTS
--   - Does not grant service_role (bypass already applies)
--
-- ROLLBACK (staging only — reopens client spam surface):
--   Recreate the three WITH CHECK (true) INSERT policies from 010.
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.notifications') IS NULL
     OR to_regclass('public.analytics_events') IS NULL
     OR to_regclass('public.error_logs') IS NULL THEN
    RAISE EXCEPTION
      '022_telemetry_insert_service_only: expected notifications/analytics_events/error_logs tables';
  END IF;
END $$;

DROP POLICY IF EXISTS "notifications_insert_service" ON public.notifications;
DROP POLICY IF EXISTS "analytics_insert_service" ON public.analytics_events;
DROP POLICY IF EXISTS "error_logs_insert_service" ON public.error_logs;

-- Optional documentation comment for operators (no behavioral change).
COMMENT ON TABLE public.notifications IS
  'Order notification audit log. INSERT only via service_role (Edge). Clients: SELECT own via RLS.';
COMMENT ON TABLE public.analytics_events IS
  'Product analytics events. INSERT only via service_role. Clients: admin SELECT only.';
COMMENT ON TABLE public.error_logs IS
  'Server/error telemetry. INSERT only via service_role. Clients: admin SELECT only.';
