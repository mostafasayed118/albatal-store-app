-- ═══════════════════════════════════════════════════════════════════
-- 067: lock the external-lineage tables (notifications, analytics_events)
--
-- Closes OWNER_ACTIONS.md Issue 6 (RLS parity) from the 2026-09-21
-- security audit, section "external-lineage tables".
--
-- Background: `analytics_events` and `notifications` were created on the
-- linked database by migrations 048–051 whose SQL files were never
-- committed to this repo (048–051 stubs document them). Objects created
-- through the SQL editor default to GRANT ALL ... TO anon, authenticated
-- and — as the audit proved for the policy half — RLS state is unknown.
--
-- Live evidence on staging (2026-09-23, pre-deploy probes, anon key):
--   analytics_events:
--     - GET  -> 200 [] (rows filtered or empty)
--     - INSERT -> 42501 "new row violates row-level security policy"
--       => RLS is ENABLED and the 053 insert-own posture is effective.
--   notifications:
--     - GET  -> 200 [] (rows filtered or empty)
--     - INSERT -> PGRST204 "Could not find the 'probe' column" — the
--       insert reached the table's column resolution, i.e. NO RLS
--       violation was raised => RLS is OFF with permissive default
--       grants. Any authenticated (and possibly anon) client can read
--       the notification log — a silent PII exposure per the audit.
--
-- No client feature reads `notifications` (grep 2026-09-23: zero
-- `from('notifications')` call sites in lib/ — push is handled natively
-- by OneSignal and order-status notifications are client-local §12), so
-- an admin-read-only policy breaks nothing.
--
-- Rollback:
--   DROP POLICY IF EXISTS notifications_admin_read ON public.notifications;
--   ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
--   GRANT ALL ON public.notifications TO anon, authenticated;
--   (analytics_events rollback: DISABLE ROW LEVEL SECURITY — not
--   recommended; it reopens world-writable analytics.)
-- ═══════════════════════════════════════════════════════════════════

-- ─── notifications: enable RLS + admin-read-only ───────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_admin_read ON public.notifications;
CREATE POLICY notifications_admin_read ON public.notifications
  FOR SELECT
  USING (public.is_current_user_admin());

-- Lockdown: nobody reads or writes through PostgREST except
-- authenticated, and the policy above filters SELECT to admins only.
-- The service role (edge functions / server jobs) bypasses RLS and
-- keeps its own grants, so server-side writers are unaffected.
REVOKE ALL ON public.notifications FROM anon;
REVOKE ALL ON public.notifications FROM authenticated;
GRANT SELECT ON public.notifications TO authenticated;

-- ─── analytics_events: idempotent parity ───────────────────────────
-- Already ENABLED on staging (proven live above). Stated explicitly so
-- prod — whose RLS state was never proven — converges to the same
-- posture. The 053 policies (analytics_insert_own + admin aggregate)
-- remain the operative policy set.
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
