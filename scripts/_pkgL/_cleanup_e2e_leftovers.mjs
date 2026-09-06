// Deletes leftover disposable e2e instapay fixtures from staging.
// GUARD: only touches orders owned by *@albatal-e2e.test users.
import { Client } from "pg";

const REF = "zvpjngdgbpnkkqrorkul";
const DB_URL = (process.env.STAGING_DB_URL ?? "").replace(/aws-[0-9]+-eu-west-1/, "aws-1-eu-west-1");
if (!DB_URL || !DB_URL.includes(REF)) {
  console.log(JSON.stringify({ ABORT: "STAGING_DB_URL missing or wrong ref" }));
  process.exit(1);
}
const db = new Client({ connectionString: DB_URL, ssl: { rejectUnauthorized: false } });
await db.connect();

const pend = await db.query(
  `SELECT o.id, u.email FROM public.orders o
   JOIN public.profiles p ON p.id = o.user_id
   JOIN auth.users u ON u.id = o.user_id
   WHERE o.payment_method = 'instapay' AND o.status = 'pending'`,
);
for (const row of pend.rows) {
  if (String(row.email).endsWith("@albatal-e2e.test")) {
    await db.query("DELETE FROM public.instapay_proofs WHERE payment_id IN (SELECT id FROM public.payments WHERE order_id = $1)", [row.id]);
    await db.query("DELETE FROM public.payments WHERE order_id = $1", [row.id]);
    await db.query("DELETE FROM public.order_items WHERE order_id = $1", [row.id]);
    await db.query("DELETE FROM public.orders WHERE id = $1", [row.id]);
    console.log(JSON.stringify({ deleted: row.id, owner: row.email }));
  } else {
    console.log(JSON.stringify({ kept: row.id, owner: row.email }));
  }
}
const left = await db.query("SELECT count(*)::int AS n FROM public.orders WHERE payment_method='instapay' AND status='pending'");
console.log(JSON.stringify({ remaining_pending_instapay_orders: left.rows[0].n }));
await db.end();
