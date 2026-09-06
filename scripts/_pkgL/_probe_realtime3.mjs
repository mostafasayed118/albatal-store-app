// ============================================================
// Realtime bisect probe #3 — STAGING ONLY.
// Two independent sockets: A listens, B sends.
//   1. Cross-client broadcast (validates websocket delivery path).
//   2. postgres_changes INSERT on instapay_proofs (via API upload).
//   3. postgres_changes UPDATE on payments (direct DB).
//   4. subscription row presence at t+2s and t+30s.
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

// Hard watchdog: never hang the harness.
setTimeout(() => { console.log(JSON.stringify({ probe3: "WATCHDOG_TIMEOUT" })); process.exit(3); }, 110000);

function mkClient() {
  return createClient(c.url, c.anon, {
    auth: { persistSession: false },
    realtime: { params: { eventsPerSecond: 10 } },
  });
}

try {
  const A = await signup();
  const co = await rpc(
    "create_checkout_order",
    {
      p_payment_method: "instapay",
      p_address: ADDRESS,
      p_items: [{ product_id: "bbbb0003-0001-0001-0001-000000000003", size: "1m", color: "Cream", quantity: 1 }],
      p_idempotency_key: "probe3-" + randomUUID(),
    },
    A.jwt,
  );
  const orderId = co.body?.order_id;
  const st = await restGet(`payments?order_id=eq.${orderId}&select=id,status`, A.jwt);
  const paymentId = st.body?.[0]?.id;
  log({ probe3: "fixture", orderId, paymentId });

  const listener = mkClient();
  listener.realtime.setAuth(A.jwt);

  let bc = 0, proofIns = 0, payUpd = 0;
  const chan = listener.channel(`probe3-${orderId}`);
  chan.on("broadcast", { event: "hello" }, (m) => { bc++; log({ probe3: "broadcast_received", payload: m }); });
  chan.on("postgres_changes",
    { event: "INSERT", schema: "public", table: "instapay_proofs" },
    (p) => { proofIns++; log({ probe3: "proofs_insert_event", id: p.new?.id }); });
  chan.on("postgres_changes",
    { event: "UPDATE", schema: "public", table: "payments" },
    (p) => { payUpd++; log({ probe3: "payments_update_event", id: p.new?.id, status: p.new?.status }); });
  await new Promise((res) =>
    chan.subscribe((s) => { if (s === "SUBSCRIBED") res(); }));
  await sleep(15000).then(() => {}); // give subscription persistence a window

  const subAt = async (tag) => {
    const r = await db.query("SELECT count(*)::int AS n FROM realtime.subscription");
    log({ probe3: "subscription_count", when: tag, n: r.rows[0].n });
  };
  await subAt("t+2s");
  await sleep(30000);
  await subAt("t+30s");

  // 1. cross-client broadcast
  const sender = mkClient();
  sender.realtime.setAuth(A.jwt);
  const schan = sender.channel(`probe3-${orderId}`);
  await new Promise((res) => schan.subscribe(res));
  schan.send({ type: "broadcast", event: "hello", payload: { from: "B" } });
  await sleep(8000);
  log({ probe3: "broadcast_result", received: bc });
  await sb_disconnect(sender);

  // 2. proofs INSERT via API-side function (edge: instapay-submit-proof)
  //    Use direct DB insert instead to isolate realtime (RLS definer path):
  await db.query(
    "INSERT INTO public.instapay_proofs (payment_id, storage_path, reference) VALUES ($1, $2, $3)",
    [paymentId, `${A.userId}/${paymentId}/probe.png`, "probe3"],
  );
  await sleep(10000);
  log({ probe3: "after_proofs_insert", proofIns, payUpd, bc });

  // 3. payments UPDATE via direct DB
  await db.query("UPDATE public.payments SET updated_at = now() WHERE id = $1", [paymentId]);
  await sleep(10000);
  log({ probe3: "after_payments_update", proofIns, payUpd, bc });

  await sb_disconnect(listener);

  // cleanup
  await db.query("DELETE FROM public.instapay_proofs WHERE payment_id = $1", [paymentId]);
  await db.query("DELETE FROM public.payments WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.order_items WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.orders WHERE id = $1", [orderId]);
  log({ probe3: "cleanup_done" });
  process.exit(0);
} catch (e) {
  log({ FATAL: String(e?.message || e).slice(0, 300) });
  process.exitCode = 1;
} finally {
  await db.end().catch(() => {});
}

async function sb_disconnect(sb) {
  try { await sb.realtime.disconnect(); } catch {}
}
