-- ═══════════════════════════════════════════════════════════
-- Migration 080: dispatch order notifications (email + push)
-- ═══════════════════════════════════════════════════════════
-- The Edge Functions send-order-notification (Resend email) and
-- push-order-status (OneSignal) require an internal key and are never
-- called by the Flutter client. This migration wires the order
-- lifecycle to them through pg_net:
--
--   orders INSERT                -> order_placed email
--   orders UPDATE status = paid  -> payment_confirmed email
--   orders UPDATE status = processing -> push only
--   orders UPDATE status = shipped/delivered/cancelled -> email + push
--
-- Configuration lives in Vault (set per environment AFTER applying):
--   PROJECT_URL                    e.g. https://<ref>.supabase.co
--   NOTIFICATIONS_INTERNAL_KEY     must equal the Edge Function secret
--   PUSH_ORDER_STATUS_INTERNAL_KEY must equal the Edge Function secret
--
-- Missing configuration = notifications are silently skipped; an order
-- transition must never fail because a notification provider is down.
-- pg_net is asynchronous, so the order transaction never waits on HTTP.
--
-- Idempotent: CREATE OR REPLACE + DROP TRIGGER IF EXISTS.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.dispatch_order_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
  v_project_url text;
  v_notif_key   text;
  v_push_key    text;
  v_email       text;
  v_name        text;
  v_locale      text;
  v_event       text;
  v_push_status text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event := 'order_placed';
    v_push_status := NULL;
  ELSE
    CASE NEW.status::text
      WHEN 'paid' THEN
        v_event := 'payment_confirmed';
      WHEN 'processing' THEN
        v_push_status := 'processing';
      WHEN 'shipped' THEN
        v_event := 'order_shipped';
        v_push_status := 'shipped';
      WHEN 'delivered' THEN
        v_event := 'order_delivered';
        v_push_status := 'delivered';
      WHEN 'cancelled' THEN
        v_event := 'order_cancelled';
        v_push_status := 'cancelled';
      ELSE
        NULL;
    END CASE;
  END IF;

  IF v_event IS NULL AND v_push_status IS NULL THEN
    RETURN NEW;
  END IF;

  -- Configuration is read from Vault; absent = feature disabled.
  SELECT decrypted_secret INTO v_project_url
    FROM vault.decrypted_secrets
   WHERE name = 'PROJECT_URL'
   LIMIT 1;
  SELECT decrypted_secret INTO v_notif_key
    FROM vault.decrypted_secrets
   WHERE name = 'NOTIFICATIONS_INTERNAL_KEY'
   LIMIT 1;
  SELECT decrypted_secret INTO v_push_key
    FROM vault.decrypted_secrets
   WHERE name = 'PUSH_ORDER_STATUS_INTERNAL_KEY'
   LIMIT 1;

  IF v_project_url IS NULL OR btrim(v_project_url) = '' THEN
    RETURN NEW;
  END IF;

  IF v_event IS NOT NULL
     AND v_notif_key IS NOT NULL
     AND btrim(v_notif_key) <> '' THEN
    SELECT u.email,
           COALESCE(NULLIF(u.raw_user_meta_data->>'locale', ''), 'en')
      INTO v_email, v_locale
      FROM auth.users u
     WHERE u.id = NEW.user_id;

    IF v_locale IS NULL OR v_locale NOT IN ('en', 'ar') THEN
      v_locale := 'en';
    END IF;

    IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
      SELECT p.full_name INTO v_name
        FROM public.profiles p
       WHERE p.id = NEW.user_id;

      BEGIN
        PERFORM net.http_post(
          url := rtrim(v_project_url, '/')
                 || '/functions/v1/send-order-notification',
          body := jsonb_build_object(
            'order_id', NEW.id,
            'event', v_event,
            'recipient_email', v_email,
            'recipient_name', v_name,
            'total', to_char(NEW.total::numeric / 100.0, 'FM999999990.00'),
            'tracking', NEW.payment_id,
            'locale', v_locale
          ),
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-internal-key', v_notif_key
          ),
          timeout_milliseconds := 5000
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'order email dispatch failed: %', SQLERRM;
      END;
    END IF;
  END IF;

  IF v_push_status IS NOT NULL
     AND v_push_key IS NOT NULL
     AND btrim(v_push_key) <> '' THEN
    BEGIN
      PERFORM net.http_post(
        url := rtrim(v_project_url, '/')
               || '/functions/v1/push-order-status',
        body := jsonb_build_object(
          'order_id', NEW.id,
          'status', v_push_status
        ),
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-internal-key', v_push_key
        ),
        timeout_milliseconds := 5000
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'order push dispatch failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Configuration reads (Vault) or any unexpected failure must never
    -- block the order transition that fired this trigger.
    RAISE WARNING 'order notification dispatch failed: %', SQLERRM;
    RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.dispatch_order_notification() IS
  'Order lifecycle dispatcher (080): queues Resend email + OneSignal push '
  'via pg_net using Vault-held internal keys. Missing config is a no-op; '
  'notification failures never block an order transition.';

REVOKE ALL ON FUNCTION public.dispatch_order_notification() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dispatch_order_notification() FROM anon;
REVOKE ALL ON FUNCTION public.dispatch_order_notification() FROM authenticated;

DROP TRIGGER IF EXISTS trg_dispatch_order_notification_insert
  ON public.orders;
CREATE TRIGGER trg_dispatch_order_notification_insert
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.dispatch_order_notification();

DROP TRIGGER IF EXISTS trg_dispatch_order_notification_status
  ON public.orders;
CREATE TRIGGER trg_dispatch_order_notification_status
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.dispatch_order_notification();
