-- ═══════════════════════════════════════════════════════════
-- Migration 036: fix audit retention cron target table
-- ═══════════════════════════════════════════════════════════
-- AUDIT follow-up (2026-09-03):
--   * 031 scheduled 'audit-retention-90d' to prune public.audit_logs,
--     a table that never exists — the real forensic trail is
--     public.state_transitions (025). The guard made the job a daily
--     no-op, leaving state_transitions growing unbounded (it holds
--     Paymob txn ids in metadata).
--
-- Fix: reschedule the job to prune state_transitions by created_at,
-- keeping the same table-existence guard style as 031 so the job
-- stays valid even in fresh environments before 025.
-- Idempotent: unschedules then reschedules.
-- ═══════════════════════════════════════════════════════════

SELECT cron.unschedule('audit-retention-90d')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'audit-retention-90d');

SELECT cron.schedule('audit-retention-90d', '0 4 * * *', $cron$DO $do$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='state_transitions') THEN DELETE FROM public.state_transitions WHERE created_at < now() - interval '90 days'; END IF; END $do$ $cron$);
