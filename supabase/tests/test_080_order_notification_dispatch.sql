-- supabase/tests/test_080_order_notification_dispatch.sql  (proof)
-- Run via: psql $STAGING_DB_URL -f supabase/tests/test_080_order_notification_dispatch.sql
-- Run AFTER applying 080. Static checks are read-only. The live block at the
-- bottom is commented out because it intentionally queues real pg_net calls.

-- ─── 1. Dispatcher function: definer + pinned search_path ────────────
SELECT 'dispatch fn exists' AS check,
  (SELECT count(*) FROM pg_proc
    WHERE oid='public.dispatch_order_notification()'::regprocedure) AS value;
-- expect 1

SELECT 'dispatch fn secdef' AS check,
  (SELECT prosecdef FROM pg_proc
    WHERE oid='public.dispatch_order_notification()'::regprocedure) AS value;
-- expect true

SELECT 'dispatch fn search_path pinned' AS check,
  COALESCE((SELECT bool_or(c ~ '^search_path=(""|)$') FROM pg_proc p,
      unnest(p.proconfig) c
    WHERE p.oid='public.dispatch_order_notification()'::regprocedure), false) AS value;
-- expect true

SELECT 'dispatch fn client grants' AS check,
  (SELECT count(*) FROM information_schema.routine_privileges
    WHERE routine_name='dispatch_order_notification'
      AND grantee IN ('anon','authenticated','PUBLIC')) AS value;
-- expect 0 (trigger functions are invoked by the system, not EXECUTE)

-- ─── 2. Triggers on orders ───────────────────────────────────────────
SELECT 'insert trigger' AS check,
  (SELECT count(*) FROM pg_trigger
    WHERE tgrelid='public.orders'::regclass
      AND tgname='trg_dispatch_order_notification_insert'
      AND NOT tgisinternal) AS value;
-- expect 1

SELECT 'status trigger' AS check,
  (SELECT count(*) FROM pg_trigger
    WHERE tgrelid='public.orders'::regclass
      AND tgname='trg_dispatch_order_notification_status'
      AND NOT tgisinternal) AS value;
-- expect 1

-- ─── 3. Required extensions / schemas ────────────────────────────────
SELECT 'pg_net installed' AS check,
  (SELECT count(*) FROM pg_extension WHERE extname='pg_net') AS value;
-- expect 1

SELECT 'vault schema' AS check,
  (SELECT count(*) FROM information_schema.schemata
    WHERE schema_name='vault') AS value;
-- expect 1

SELECT 'net.http_post signature' AS check,
  (SELECT bool_or(pg_get_function_arguments(p.oid)
                  LIKE '%timeout_milliseconds%')
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='net' AND p.proname='http_post') AS value;
-- expect true (migration passes timeout_milliseconds)

-- ─── 4. Vault configuration (names only; values never selected) ──────
SELECT 'vault config names' AS check,
  (SELECT string_agg(name, ',' ORDER BY name) FROM vault.secrets
    WHERE name IN ('PROJECT_URL',
                   'NOTIFICATIONS_INTERNAL_KEY',
                   'PUSH_ORDER_STATUS_INTERNAL_KEY')) AS value;
-- expect NOTIFICATIONS_INTERNAL_KEY,PROJECT_URL,PUSH_ORDER_STATUS_INTERNAL_KEY
-- (string_agg ORDER BY name; missing names = that channel is silently
--  skipped by design)

-- ─── 5. Status mapping regression guard ─────────────────────────────
SELECT 'order_status labels' AS check,
  (SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
     FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid
    WHERE t.typname='order_status') AS value;
-- expect placed,shipped,delivered,cancelled,refunded,pending,processing,paid

-- ─── 6. Live end-to-end (staging only; opt-in) ──────────────────────
-- This queues REAL email/push calls and therefore is commented out.
-- Use a dedicated staging test order, then inspect pg_net's async log:
--
-- BEGIN;
--   -- pick an order whose status can legally move (e.g. paid -> processing)
--   UPDATE public.orders SET status='processing'
--    WHERE id='<STAGING_TEST_ORDER_ID>'::uuid;
-- COMMIT;
-- SELECT id, status_code, content
--   FROM net._http_response
--  ORDER BY id DESC LIMIT 2;
-- -- expect ONE row for processing (push only; no email event is mapped).
-- -- Use paid -> processing -> shipped to exercise BOTH channels (email + push).
-- -- Bodies are { skipped: true } until ONESIGNAL_*/RESEND_API_KEY are set.
--
-- Negative probe (must NOT block the transition): temporarily delete the
-- PROJECT_URL Vault secret, update an order, and confirm the order update
-- still commits with a warning in the Postgres log. Restore the secret.
