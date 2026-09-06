// ============================================================
// InstaPay E2E — STAGING ONLY (disposable fixtures).
// Mirrors the client flow (migration 041):
//   signup → create_checkout_order('instapay') → instapay-initiate
//   → Realtime watch (channel payment-<orderId>, payments UPDATE)
//   → instapay-submit-proof (PNG proof) → admin review via the
//   instapay-review Edge Function → the Realtime watch must flip
//   the payment to success (order paid) WITHOUT polling.
//
// GUARDS (same policy as run_cod_payment.mjs):
//   - STAGING_DB_URL unset / wrong project ref → ABORT.
//   - Secrets are never printed.
//   - The e2e user's is_admin elevation is restored afterwards.
// ============================================================
import { createClient } from "@supabase/supabase-js";
import { Client } from "pg";
import zlib from "node:zlib";
import { createHash, randomUUID } from "node:crypto";
import { signup, rpc, restGet, ADDRESS, log, cfg } from "./_e2e_lib.mjs";

const REQUIRED_STAGING_REF = "zvpjngdgbpnkkqrorkul";
const STAGING_DB_URL = (process.env.STAGING_DB_URL ?? "").replace(
  /aws-[0-9]+-eu-west-1/,
  "aws-1-eu-west-1",
);
if (!STAGING_DB_URL) {
  log({ ABORT: "STAGING_DB_URL is not set — refusing to run." });
  process.exit(1);
}
if (!STAGING_DB_URL.includes(REQUIRED_STAGING_REF)) {
  log({ ABORT: `STAGING_DB_URL does not reference ${REQUIRED_STAGING_REF}.` });
  process.exit(1);
}

const c = cfg();

// ── Minimal valid 1x1 red PNG (D3: screenshot required) ─────
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let a = n;
  for (let k = 0; k < 8; k++) a = a & 1 ? 0xedb88320 ^ (a >>> 1) : a >>> 1;
  return a >>> 0;
});
function crc32(buf) {
  let a = 0xffffffff;
  for (const b of buf) a = CRC_TABLE[(a ^ b) & 0xff] ^ (a >>> 8);
  return (a ^ 0xffffffff) >>> 0;
}
function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const t = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
function makeProofPng() {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.from([0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0]);
  const raw = Buffer.from([0, 255, 0, 0]); // filter 0 + RGB red
  return Buffer.concat([
    sig,
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", zlib.deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}
const PROOF_PNG = makeProofPng();

// ── HTTP helpers ─────────────────────────────────────────────
async function callFn(name, body, jwt) {
  const r = await fetch(`${c.url}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      apikey: c.anon,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  let b;
  try {
    b = await r.json();
  } catch {
    b = await r.text();
  }
  return { status: r.status, body: b };
}

async function orderState(orderId, jwt) {
  const o = await restGet(
    `orders?id=eq.${orderId}&select=id,status,total,payment_method`,
    jwt,
  );
  const p = await restGet(
    `payments?order_id=eq.${orderId}&select=id,status,method,amount,transaction_id`,
    jwt,
  );
  return {
    order: o.body?.[0] ?? null,
    payments: Array.isArray(p.body) ? p.body : [],
  };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const idk = () => "e2e-" + randomUUID();

// ── Realtime watch (app-parity: payment-<orderId> channel) ──
// Returns { subscribedPromise, terminalPromise, unsubscribe }.
// subscribedPromise resolves once the channel is SUBSCRIBED (or
// errors); terminalPromise resolves on a terminal payments UPDATE
// or after deadlineMs with terminal=null.
function startWatch(orderId, jwt, deadlineMs) {
  const sb = createClient(c.url, c.anon, {
    auth: { persistSession: false },
    realtime: { params: { eventsPerSecond: 5 } },
  });
  sb.realtime.setAuth(jwt);
  const events = [];
  let subscribedResolve, subscribedReject;
  let terminalResolve;
  const subscribedPromise = new Promise((res, rej) => {
    subscribedResolve = res;
    subscribedReject = rej;
  });
  const terminalPromise = new Promise((res) => (terminalResolve = res));
  const timeout = setTimeout(
    () => terminalResolve({ events, terminal: null }),
    deadlineMs,
  );
  const channel = sb
    .channel(`payment-${orderId}`)
    .on(
      "postgres_changes",
      {
        event: "UPDATE",
        schema: "public",
        table: "payments",
        filter: `order_id=eq.${orderId}`,
      },
      (payload) => {
        const status = payload.new?.status ?? null;
        events.push({ status, at: Date.now() });
        if (status === "success") {
          clearTimeout(timeout);
          terminalResolve({
            events,
            terminal: {
              status: "success",
              transactionId: payload.new?.transaction_id ?? null,
            },
          });
        } else if (status === "failed") {
          clearTimeout(timeout);
          terminalResolve({ events, terminal: { status: "failed" } });
        }
      },
    )
    .subscribe((status) => {
      if (status === "SUBSCRIBED") subscribedResolve(true);
      if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
        clearTimeout(timeout);
        terminalResolve({ events, terminal: null });
        subscribedReject(new Error(`realtime subscribe failed: ${status}`));
      }
    });
  const unsubscribe = async () => {
    clearTimeout(timeout);
    await sb.channel(`payment-${orderId}`).unsubscribe();
    await sb.realtime.disconnect();
  };
  return { subscribedPromise, terminalPromise, unsubscribe, events };
}

// ── Main ─────────────────────────────────────────────────────
const db = new Client({
  connectionString: STAGING_DB_URL,
  ssl: { rejectUnauthorized: false },
});
await db.connect();

const results = [];
const rec = (o) => {
  results.push(o);
  log(o);
};

try {
  // ── Step 1: user + instapay order (checkout creates it first,
  //    exactly like the app before the method page) ──────────
  const A = await signup();
  log({ step: "signup", userId: A.userId });

  const co = await rpc(
    "create_checkout_order",
    {
      p_payment_method: "instapay",
      p_address: ADDRESS,
      p_items: [
        {
          product_id: "bbbb0003-0001-0001-0001-000000000003",
          size: "1m",
          color: "Cream",
          quantity: 1,
        },
      ],
      p_idempotency_key: idk(),
    },
    A.jwt,
  );
  const orderId = co.body?.order_id;
  const st0 = await orderState(orderId, A.jwt);
  rec({
    step: "create_instapay_order",
    orderId,
    http: co.status,
    total: co.body?.total,
    status: st0.order?.status,
    payment_method: st0.order?.payment_method,
    PASS: co.status === 200 && st0.order?.status === "pending" &&
      st0.order?.payment_method === "instapay",
  });
  if (!orderId) throw new Error("order creation failed: " + JSON.stringify(co.body));

  // ── Step 2: instapay-initiate (server returns address+amount,
  //    guarantees the single pending payments row) ────────────
  const init = await callFn("instapay-initiate", { order_id: orderId }, A.jwt);
  const paymentId = init.body?.payment_id ?? null;
  rec({
    step: "instapay_initiate",
    http: init.status,
    payment_id: paymentId,
    address: init.body?.instapay_address ?? null,
    amount: init.body?.amount ?? null,
    amount_formatted: init.body?.amount_formatted ?? null,
    PASS: init.status === 200 && Boolean(paymentId) &&
      Boolean(init.body?.instapay_address) && init.body?.amount === co.body?.total,
  });
  if (init.status !== 200) throw new Error("initiate failed: " + JSON.stringify(init.body));

  // ── Step 3: Realtime watch, app-parity (started in awaitingProof)
  // Watch #1: prove the channel subscribes and observes rows for
  // this order before any mutation happens.
  const w0 = startWatch(orderId, A.jwt, 30000);
  w0.subscribedPromise.catch(() => {}); // avoid unhandled rejection
  const subOk = await Promise.race([
    w0.subscribedPromise,
    sleep(15000).then(() => false),
  ]);
  rec({
    step: "realtime_subscribed",
    channel: `payment-${orderId}`,
    PASS: subOk === true,
  });
  await w0.unsubscribe();

  // Watch #2: live through proof submission + admin approval; the
  // terminal success event must arrive WITHOUT any polling.
  const w2 = startWatch(orderId, A.jwt, 120000);
  w2.subscribedPromise.catch(() => {}); // avoid unhandled rejection
  await Promise.race([w2.subscribedPromise, sleep(15000)]);

  // ── Step 4: submit proof (D3 screenshot required) ───────────
  const pf = await callFn(
    "instapay-submit-proof",
    {
      order_id: orderId,
      proof_base64: PROOF_PNG.toString("base64"),
      reference: "E2E-" + randomUUID().slice(0, 8),
      file_ext: "png",
    },
    A.jwt,
  );
  const proofId = pf.body?.proof_id ?? null;
  const st1 = await orderState(orderId, A.jwt);
  rec({
    step: "submit_proof",
    http: pf.status,
    proof_id: proofId,
    png_bytes: PROOF_PNG.length,
    png_sha256: createHash("sha256").update(PROOF_PNG).digest("hex"),
    payment_status_after: st1.payments?.[0]?.status,
    PASS: pf.status === 201 && Boolean(proofId) &&
      st1.payments?.[0]?.status === "pending",
  });
  if (pf.status !== 201) throw new Error("proof submit failed: " + JSON.stringify(pf.body));

  // ── Step 5: admin approval via the instapay-review function ─
  //     (D4 dashboard-first: same RPC the dashboard would call).
  //     Elevation is via DB, scoped to this disposable e2e user.
  const prior = await db.query(
    "SELECT is_admin FROM public.profiles WHERE id = $1",
    [A.userId],
  );
  const existedBefore = prior.rowCount > 0;
  const wasAdmin = existedBefore ? prior.rows[0].is_admin : null;
  if (existedBefore) {
    await db.query("UPDATE public.profiles SET is_admin = true WHERE id = $1", [A.userId]);
  } else {
    await db.query(
      "INSERT INTO public.profiles (id, full_name, is_admin) VALUES ($1, 'E2E InstaPay Admin', true)",
      [A.userId],
    );
  }
  log({ step: "admin_elevated", userId: A.userId, created_profile: !existedBefore });

  const rev = await callFn(
    "instapay-review",
    { proof_id: proofId, approve: true, note: "E2E staged approval" },
    A.jwt,
  );
  rec({
    step: "instapay_review",
    http: rev.status,
    ok: rev.body?.ok ?? null,
    code: rev.body?.code ?? rev.body?.message ?? null,
    order_id: rev.body?.order_id ?? null,
  });

  // restore admin state IMMEDIATELY after the review call
  if (existedBefore) {
    await db.query("UPDATE public.profiles SET is_admin = $2 WHERE id = $1", [A.userId, wasAdmin]);
  } else {
    await db.query("DELETE FROM public.profiles WHERE id = $1", [A.userId]);
  }
  const after = await db.query("SELECT is_admin FROM public.profiles WHERE id = $1", [A.userId]);
  rec({
    step: "admin_restored",
    profile_exists: after.rowCount > 0,
    is_admin_now: after.rows[0]?.is_admin ?? null,
  });

  // ── Step 6: the Realtime watch must observe the flip ────────
  const wres = await Promise.race([
    w2.terminalPromise,
    sleep(45000).then(() => ({ events: w2.events, terminal: null })),
  ]);
  await w2.unsubscribe();

  const st2 = await orderState(orderId, A.jwt);
  const expectedTx = `instapay_${proofId}`;
  rec({
    step: "realtime_terminal_event",
    channel_events: wres?.events ?? [],
    terminal_status: wres?.terminal?.status ?? null,
    transaction_id_seen: wres?.terminal?.transactionId ?? null,
    expected_transaction_id: expectedTx,
    tx_matches: wres?.terminal?.transactionId === expectedTx,
    realtime_event_arrived: wres?.terminal?.status === "success",
    PASS: wres?.terminal?.status === "success" &&
      wres?.terminal?.transactionId === expectedTx,
  });

  rec({
    step: "server_state_after_review",
    order_status: st2.order?.status,
    payment_status: st2.payments?.[0]?.status,
    payment_method: st2.payments?.[0]?.method,
    payment_count: st2.payments?.length,
    stored_tx: st2.payments?.[0]?.transaction_id,
    PASS: st2.order?.status === "paid" &&
      st2.payments?.[0]?.status === "success" &&
      st2.payments?.[0]?.transaction_id === expectedTx &&
      st2.payments?.length === 1,
  });

  // ── Cleanup: remove disposable order artifacts (keep auth user,
  //    matching prior E2E practice) ─────────────────────────────
  try {
    await db.query(
      `DELETE FROM public.instapay_proofs WHERE payment_id IN (SELECT id FROM public.payments WHERE order_id = $1)`,
      [orderId],
    );
    await db.query("DELETE FROM public.payments WHERE order_id = $1", [orderId]);
    await db.query("DELETE FROM public.order_items WHERE order_id = $1", [orderId]);
    await db.query("DELETE FROM public.orders WHERE id = $1", [orderId]);
    rec({ step: "cleanup", order_deleted: true });
  } catch (e) {
    rec({ step: "cleanup", order_deleted: false, error: String(e?.message || e).slice(0, 120) });
  }

  const scored = results.filter((r) => r.PASS === true || r.PASS === false);
  const passed = scored.filter((r) => r.PASS === true).length;
  log({
    SUMMARY: "INSTAPAY_E2E",
    scored: scored.length,
    passed,
    failed: scored.length - passed,
    verdict: passed === scored.length ? "✅ PASS" : "❌ FAIL",
  });
  process.exitCode = passed === scored.length ? 0 : 1;
} catch (e) {
  log({ FATAL: String(e?.message || e).slice(0, 300) });
  process.exitCode = 1;
} finally {
  await db.end().catch(() => {});
}
