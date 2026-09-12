-- 053_analytics_events.sql (feature-batch section 11 -- REVIEWED pre-apply 2026-09-13)
-- Applies to a database where an analytics_events table ALREADY EXISTS
-- (created by remote migrations 048-051 with columns: id, user_id, event,
-- properties, created_at -- verified via REST OpenAPI). This migration only:
--   1. aligns indexes/policies with the storefront funnel contract,
--   2. provides the admin aggregate RPC reading the existing event column.
-- The client (AnalyticsService) inserts {event, properties} to match.

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_time
  ON public.analytics_events (event, created_at DESC);

-- Idempotent policy add (no IF NOT EXISTS for policies before PG15).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'analytics_events'
      AND policyname = 'analytics_insert_own'
  ) THEN
    CREATE POLICY analytics_insert_own ON public.analytics_events
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid() OR user_id IS NULL);
  END IF;
END
$$;

-- Admin aggregates for the dashboard widget (counts per event, last
-- 30 days) reading the existing event column.
CREATE OR REPLACE FUNCTION public.assert_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_admin
  );
$$;

CREATE OR REPLACE FUNCTION public.analytics_event_counts_admin()
RETURNS TABLE (event_name text, count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.assert_is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY
    SELECT e.event AS event_name, count(*)::bigint AS count
    FROM public.analytics_events e
    WHERE e.created_at > now() - interval '30 days'
    GROUP BY e.event
    ORDER BY count DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytics_event_counts_admin() TO authenticated;
