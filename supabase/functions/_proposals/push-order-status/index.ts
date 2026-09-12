// push-order-status — edge function PROPOSAL (feature-batch §12)
// Owner review required. Not registered in config.toml; deploy only
// after review.
//
// Sends an OneSignal push when an order status changes. The admin
// `update_order_status` RPC/flow calls this function with the order id
// and new status; the function resolves the customer's OneSignal
// subscription from profiles and posts the notification.
//
// Deploy: supabase functions deploy push-order-status
// Secrets: ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') ?? '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? '';

const STATUS_COPY: Record<string, { en: string; ar: string }> = {
  processing: { en: 'Your order is being prepared', ar: 'طلبك قيد التجهيز' },
  shipped: { en: 'Your order has shipped', ar: 'تم شحن طلبك' },
  delivered: { en: 'Your order was delivered', ar: 'تم توصيل طلبك' },
  cancelled: { en: 'Your order was cancelled', ar: 'تم إلغاء طلبك' },
};

Deno.serve(async (req) => {
  try {
    const { order_id, status } = await req.json();
    const copy = STATUS_COPY[status];
    if (!copy || !order_id) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Resolve the order owner's push subscription id. Storage of the
    // OneSignal player id on profiles is part of the owner review for
    // this proposal (schema delta: profiles.onesignal_player_id).
    const { data: order } = await supabase
      .from('orders')
      .select('user_id')
      .eq('id', order_id)
      .single();
    if (!order?.user_id) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }
    const { data: profile } = await supabase
      .from('profiles')
      .select('onesignal_player_id')
      .eq('id', order.user_id)
      .single();
    const playerId = profile?.onesignal_player_id;
    if (!playerId || !ONESIGNAL_APP_ID) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const res = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_player_ids: [playerId],
        headings: { en: 'Al Batal Elite', ar: 'البطل إيليت' },
        contents: { en: copy.en, ar: copy.ar },
        data: { order_id, status },
      }),
    });

    return new Response(JSON.stringify({ ok: res.ok }), {
      status: res.ok ? 200 : 502,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
