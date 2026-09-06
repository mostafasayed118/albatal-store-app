// ============================================================
// Realtime bisect probe #2 — STAGING ONLY.
// 1. Broadcast self-test (validates websocket + channel path).
// 2. postgres_changes on payments WITH filter vs WITHOUT filter.
// 3. Live realtime.subscription row inspection mid-subscription.
// ============================================================
import { createClient } from "@supabase/supabase-js";
import { Client } from "pg";
import { signup, rpc, restGet, ADDRESS, log, cfg } from "./_e2e_lib.mjs";
import { randomUUID } from "node:crypto";

const REF = "zvpjngdgbpnkkqrorkul";
const DB_URL = (process.env.STAGING_DB_URL ?? "").replace(/aws-[0-9]+-eu-west-1/, "aws-1-eu-west-1");
if (!DB_URL || !DB_URL.includes(REF)) {
  log({ ABORT: "STAGING_DB_URL missing or wrong ref" });
  process.exit(1);
}
const c = cfg();
const db = new Client({ connectionString: DB_URL, ssl: { rejectUnauthorized: false } });
await db.connect();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  const A = await signup();
  const co = await rpc(
    "create_checkout_order",
    {
      p_payment_method: "instapay",
      p_address: ADDRESS,
      p_items: [{ product_id: "bbbb0003-0001-0001-0001-000000000003", size: "1m", color: "Cream", quantity: 1 }],
      p_idempotency_key: "probe2-" + randomUUID(),
    },
    A.jwt,
  );
  const orderId = co.body?.order_id;
  const st = await restGet(`payments?order_id=eq.${orderId}&select=id,status`, A.jwt);
  const paymentId = st.body?.[0]?.id;
  log({ probe2: "fixture", orderId, paymentId });

  const sb = createClient(c.url, c.anon, {
    auth: { persistSession: false },
    realtime: { params: { eventsPerSecond: 5 } },
  });
  sb.realtime.setAuth(A.jwt);

  let bcReceived = 0, filteredReceived = 0, unfilteredReceived = 0, orderEvents = 0;

  // 1. Broadcast self-test on its own channel
  const bcChan = sb.channel(`bc-test-${randomUUID()}`);
  bcChan.on("broadcast", { event: "ping" }, () => { bcReceived++; });
  await new Promise((res) => bcChan.subscribe(res));
  bcChan.send({ type: "broadcast", event: "ping", payload: { t: Date.now() } });
  await sleep(3000);
  log({ probe2: "broadcast_self_test", received: bcReceived, note: "self broadcast may not echo unless self:true" });

  // 2a. payments WITH order_id filter
  const chF = sb.channel(`p-f-${orderId}`)
    .on("postgres_changes",
      { event: "UPDATE", schema: "public", table: "payments", filter: `order_id=eq.${orderId}` },
      (p) => { filteredReceived++; log({ probe2: "filtered_event", status: p.new?.status }); })
    .on("postgres_changes",
      { event: "UPDATE", schema: "public", table: "payments" },
      (p) => { unfilteredReceived++; log({ probe2: "unfiltered_event", id: p.new?.id, status: p.new?.status }); })
    .on("postgres_changes",
      { event: "UPDATE", schema: "public", table: "orders", filter: `id=eq.${orderId}` },
      (p) => { orderEvents++; log({ probe2: "orders_event", status: p.new?.status }); });
  await new Promise((res) => chF.subscribe((s) => { if (s === "SUBSCRIBED") res(); }));

  // 3. Live subscription row inspection WHILE subscribed
  const rows = await db.query("SELECT subscription_id, entity, filters, claims_role, selected_columns FROM realtime.subscription");
  log({ probe2: "subscription_rows_while_live", count: rows.rowCount, rows: rows.rows.map(r => ({ entity: r.entity, filters: r.filters, role: r.claims_role, cols: r.selected_columns })) });

  // Mutations: payments UPDATE then orders UPDATE (direct DB)
  await db.query("UPDATE public.payments SET updated_at = now() WHERE id = $1", [paymentId]);
  await sleep(10000);
  log({ probe2: "after_payments_update", filteredReceived, unfilteredReceived, orderEvents });

  await db.query("UPDATE public.orders SET updated_at = now() WHERE id = $1", [orderId]);
  await sleep(10000);
  log({ probe2: "after_orders_update", filteredReceived, unfilteredReceived, orderEvents });

  await sb.channel(`p-f-${orderId}`).unsubscribe();
  await sb.realtime.disconnect();

  await db.query("DELETE FROM public.payments WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.order_items WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.orders WHERE id = $1", [orderId]);
  log({ probe2: "cleanup_done" });
} catch (e) {
  log({ FATAL: String(e?.message || e).slice(0, 300) });
  process.exitCode = 1;
} finally {
  await db.end().catch(() => {});
}
