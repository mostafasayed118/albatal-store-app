// ============================================================
// Realtime diagnostic probe — STAGING ONLY.
// Subscribes to payments UPDATE (same pattern as the app's
// watchPaymentStatus), then mutates its OWN disposable payment
// row via the DB, logging every realtime socket message to see
// how far the event pipeline gets.
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

try {
  const A = await signup();
  const co = await rpc(
    "create_checkout_order",
    {
      p_payment_method: "instapay",
      p_address: ADDRESS,
      p_items: [{ product_id: "bbbb0003-0001-0001-0001-000000000003", size: "1m", color: "Cream", quantity: 1 }],
      p_idempotency_key: "probe-" + randomUUID(),
    },
    A.jwt,
  );
  const orderId = co.body?.order_id;
  const st = await restGet(`payments?order_id=eq.${orderId}&select=id,status`, A.jwt);
  const paymentId = st.body?.[0]?.id;
  log({ probe: "fixture", orderId, paymentId });

  const sb = createClient(c.url, c.anon, {
    auth: { persistSession: false },
    realtime: {
      params: { eventsPerSecond: 5 },
      logger: (level, msg, data) => {
        const line = `[rt:${level}] ${msg}` +
          (data ? " " + JSON.stringify(data).slice(0, 300) : "");
        console.log(line.slice(0, 400));
      },
    },
  });
  sb.realtime.setAuth(A.jwt);

  let got = 0;
  const channel = sb
    .channel(`payment-${orderId}`)
    .on("postgres_changes",
      { event: "UPDATE", schema: "public", table: "payments", filter: `order_id=eq.${orderId}` },
      (payload) => { got++; log({ probe: "PG_EVENT", new: payload.new }); })
    .subscribe((status, err) => {
      console.log(`[rt] subscribe status: ${status}${err ? " err=" + JSON.stringify(err).slice(0, 200) : ""}`);
    });

  // Give the handshake time, then inspect server-side registration.
  await new Promise((r) => setTimeout(r, 6000));
  const subsTables = await db.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema='realtime' ORDER BY 1",
  );
  console.log("realtime schema tables:", subsTables.rows.map((x) => x.table_name).join(", "));
  for (const t of ["subscriptions", "subscription"]) {
    try {
      const q = await db.query(`SELECT id, claim, entity FROM realtime.${t} LIMIT 5`);
      console.log(`realtime.${t} rows:`, JSON.stringify(q.rows).slice(0, 600));
    } catch (e) {
      console.log(`realtime.${t}: ${String(e.message).slice(0, 100)}`);
    }
  }

  // Mutate OUR OWN payment row directly (WAL event outside the API).
  console.log("--- issuing direct UPDATE on own payment row ---");
  await db.query("UPDATE public.payments SET updated_at = now() WHERE id = $1", [paymentId]);
  await new Promise((r) => setTimeout(r, 20000));
  log({ probe: "result", pg_events_received: got });

  // Also try an API-side update (UPDATE via PostgREST as owner) in
  // case direct-DB writes take a different replication path.
  console.log("--- issuing API-side UPDATE as owner ---");
  const r2 = await fetch(`${c.url}/rest/v1/payments?id=eq.${paymentId}`, {
    method: "PATCH",
    headers: {
      apikey: c.anon,
      Authorization: `Bearer ${A.jwt}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ reference: null }),
  });
  console.log("patch status:", r2.status);
  await new Promise((r) => setTimeout(r, 15000));
  log({ probe: "final", pg_events_received: got });

  await sb.channel(`payment-${orderId}`).unsubscribe();
  await sb.realtime.disconnect();

  // Cleanup disposable order
  await db.query("DELETE FROM public.payments WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.order_items WHERE order_id = $1", [orderId]);
  await db.query("DELETE FROM public.orders WHERE id = $1", [orderId]);
  log({ probe: "cleanup_done" });
} catch (e) {
  log({ FATAL: String(e?.message || e).slice(0, 300) });
  process.exitCode = 1;
} finally {
  await db.end().catch(() => {});
}
