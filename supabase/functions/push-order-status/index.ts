// ============================================================
// Supabase Edge Function: push-order-status
//
// Sends an OneSignal push notification when an order status
// changes. The DB trigger (migration 080) calls this function via
// pg_net with the order id and new status; the function resolves
// the customer's user id from orders and posts the notification
// using OneSignal external user ids (no player-id storage).
//
// SECURITY HARDENING (audit 2026-10-05, MEDIUM):
//   This endpoint must not accept arbitrary public POSTs — otherwise
//   anyone could trigger spoofed "shipped/delivered" pushes for known
//   order ids. It now requires the same internal authorization model
//   as send-order-notification:
//
//     The caller MUST send `x-internal-key` matching the
//     `PUSH_ORDER_STATUS_INTERNAL_KEY` server secret. This secret
//     lives ONLY in Edge Function environment variables and is never
//     shipped to Flutter. Public callers without the key receive 401.
//
//   In addition:
//     * status is validated against the STATUS_COPY allowlist,
//     * order_id must be a non-empty string,
//     * error responses are generic; details go to server logs only.
//
// Contract:
//   POST body: { "order_id": "<uuid>",
//                "status": "processing|shipped|delivered|cancelled" }
//   Header:    x-internal-key == PUSH_ORDER_STATUS_INTERNAL_KEY
//
// Deploy: supabase functions deploy push-order-status
// Secrets: ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY,
//          PUSH_ORDER_STATUS_INTERNAL_KEY
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeadersFor, jsonHeadersFor, requireCors } from '../_shared/cors.ts';
import { constantTimeEquals, requireSecret } from '../_shared/secrets.ts';

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';

const STATUS_COPY: Record<string, { en: string; ar: string }> = {
  processing: { en: 'Your order is being prepared', ar: 'طلبك قيد التجهيز' },
  shipped: { en: 'Your order has shipped', ar: 'تم شحن طلبك' },
  delivered: { en: 'Your order was delivered', ar: 'تم توصيل طلبك' },
  cancelled: { en: 'Your order was cancelled', ar: 'تم إلغاء طلبك' },
};

Deno.serve(async (req) => {
  // Fail closed on CORS misconfiguration.
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeadersFor(req) });
  }

  try {
    // ─── Internal authorization (audit 2026-10-05) ──────────
    // Only callers that present the server-side internal key may
    // trigger push notifications. The key is never shipped to Flutter.
    const keyFail = requireSecret(req, 'PUSH_ORDER_STATUS_INTERNAL_KEY');
    if (keyFail) return keyFail;
    const expectedKey = Deno.env.get(
      'PUSH_ORDER_STATUS_INTERNAL_KEY',
    ) as string;

    const providedKey = req.headers.get('x-internal-key') ?? '';
    // Constant-time compare so the key cannot be timed.
    if (!constantTimeEquals(providedKey, expectedKey)) {
      return new Response(JSON.stringify({ message: 'Unauthorized' }), {
        status: 401,
        headers: jsonHeadersFor(req),
      });
    }

    // ─── Parse + validate request ───────────────────────────
    const { order_id, status } = await req.json();
    if (typeof order_id !== 'string' || order_id.trim() === '') {
      return new Response(JSON.stringify({ message: 'Invalid order_id' }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }
    if (typeof status !== 'string' || !Object.hasOwn(STATUS_COPY, status)) {
      return new Response(JSON.stringify({ message: 'Unknown status' }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }
    const copy = STATUS_COPY[status];

    const serviceRoleFail = requireSecret(req, 'SUPABASE_SERVICE_ROLE_KEY');
    if (serviceRoleFail) return serviceRoleFail;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Resolve the order owner. OneSignal external user ids are set to
    // the Supabase user id, so no player-id storage is needed.
    const { data: order } = await supabase
      .from('orders')
      .select('user_id')
      .eq('id', order_id)
      .single();
    if (!order?.user_id) {
      return new Response(JSON.stringify({ skipped: true }), {
        status: 200,
        headers: jsonHeadersFor(req),
      });
    }

    // No provider configured: skip cleanly without calling OneSignal.
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      return new Response(
        JSON.stringify({ skipped: true, reason: 'push_not_configured' }),
        { status: 200, headers: jsonHeadersFor(req) },
      );
    }

    let res: Response;
    try {
      res = await fetch('https://onesignal.com/api/v1/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify({
          app_id: ONESIGNAL_APP_ID,
          include_external_user_ids: [order.user_id],
          target_channel: 'push',
          headings: { en: 'Al Batal Elite', ar: 'البطل إيليت' },
          contents: { en: copy.en, ar: copy.ar },
          data: { order_id, status },
        }),
      });
    } catch (_error) {
      console.error('push-order-status: provider request failed');
      return new Response(
        JSON.stringify({ message: 'Push notification failed.' }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }

    if (!res.ok) {
      // Never log provider payloads or credentials.
      console.error(
        `push-order-status: provider rejected notification (status ${res.status})`,
      );
      return new Response(
        JSON.stringify({ message: 'Push notification failed.' }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }

    const providerBody = await res.json().catch(() => null);
    return new Response(
      JSON.stringify({ ok: true, id: providerBody?.id ?? null }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (_error) {
    // Never echo internal error details to the caller; log server-side.
    console.error('push-order-status: unhandled error');
    return new Response(
      JSON.stringify({ message: 'Push notification failed.' }),
      { status: 500, headers: jsonHeadersFor(req) },
    );
  }
});
