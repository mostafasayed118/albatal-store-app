-- 053_analytics_events.sql (feature-batch §11 — REVIEW-GATED PROPOSAL)
-- Owner review required before applying (AGENTS.md migration gate).
--
-- First-party funnel analytics without Firebase: one append-only table,
-- insert-own RLS (clients never read their own or others' events), and
-- an admin-only aggregate RPC for the dashboard widget.

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id         bigserial PRIMARY KEY,
  user_id    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  name       text NOT NULL,
  props      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_time
  ON public.analytics_events (name, created_at DESC);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Insert-own: authenticated users append events for themselves.
-- user_id is forced to auth.uid() by the WITH CHECK so a client cannot
-- forge another user's funnel.
CREATE POLICY analytics_insert_own ON public.analytics_events
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

-- No SELECT/UPDATE/DELETE policies for clients: the table is
-- write-only from the app.

-- Admin aggregates for the dashboard widget (counts per event, last
-- 30 days). SECURITY DEFINER so it reads across all users.
CREATE OR REPLACE FUNCTION public.analytics_event_counts()
RETURNS TABLE (name text, count bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT e.name, count(*) AS count
  FROM public.analytics_events e
  WHERE e.created_at > now() - interval '30 days'
  GROUP BY e.name
  ORDER BY count DESC;
$$;

-- Admin-only execution gate (defense in depth on top of SECURITY DEFINER).
CREATE OR REPLACE FUNCTION public.assert_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_admin
  );
$$;

REVOKE EXECUTE ON FUNCTION public.analytics_event_counts() FROM PUBLIC, anon, authenticated;

-- Grant handled by the admin surface calling through an edge function,
-- or by the RLS-aware policy below when direct client calls are wanted:
-- (owner review: choose one of the two options)

-- Option A (chosen default): authenticated admins may execute.
CREATE OR REPLACE FUNCTION public.analytics_event_counts_admin()
RETURNS TABLE (name text, count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.assert_is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY SELECT * FROM public.analytics_event_counts();
END;
$$;
GRANT EXECUTE ON FUNCTION public.analytics_event_counts_admin() TO authenticated;
