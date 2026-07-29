// ============================================================
// Paymob + callback-security + race E2E matrix
// STAGING-E2E-E9A6DEB-2026-07-28 (staging only, sandbox)
//
// Uses paymob-initiate to create a mapped payment (real
// sandbox provider order id), then drives the callback state
// machine with locally-signed VALID HMAC callbacks. No real
// card entry; the HMAC secret is read from env and never
// printed. Emits one JSON line per test + summary.
// ============================================================
import {
  signup, rpc, restGet, variantStock, signCallback, postCallback,
  ADDRESS, cfg, log,
} from "./_e2e_lib.mjs";

const FIX = {
  product_id: "bbbb0003-0001-0001-0001-000000000003",
  variant_id: "35f2e5e1-ce84-45de-9de5-cabd776a8118",
  size: "1m", color: "Cream",
};
const item = (qty) => ([{ product_id: FIX.product_id, size: FIX.size, color: FIX.color, quantity: qty }]);
const results = [];
const rec = (o) => { results.push(o); log(o); };
const idk = () => "e2e-" + Math.random().toString(36).slice(2, 12);

async function initiate(orderId, jwt) {
  const c = cfg();
  const r = await fetch(`${c.url}/functions/v1/paymob-initiate`, {
    method: "POST",
    headers: { apikey: c.anon, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify({ order_id: orderId }),
  });
  let body; try { body = await r.json(); } catch { body = await r.text(); }
  return { status: r.status, hasCheckoutUrl: Boolean(body && body.checkout_url), message: body && body.message };
}

async function paymentRow(orderId, jwt) {
  const r = await restGet(`payments?order_id=eq.${orderId}&select=id,status,method,amount,paymob_order_id,transaction_id`, jwt);
  return Array.isArray(r.body) ? r.body[0] : null;
}
async function orderRow(orderId, jwt) {
  const r = await restGet(`orders?id=eq.${orderId}&select=id,status,total`, jwt);
  return Array.isArray(r.body) ? r.body[0] : null;
}

function callbackValues(paymobOrderId, txnId, amountCents, success) {
  return {
    amount_cents: String(amountCents), created_at: "2026-07-28T00:00:00",
    currency: "EGP", error_occured: "false", has_parent_transaction: "false",
    id: String(txnId), integration_id: "999999", is_3d_secure: "false",
    is_auth: "false", is_capture: "false", is_refunded: "false",
    is_standalone_payment: "true", is_voided: "false", order: String(paymobOrderId),
    owner: "1", pending: "false", source_data_pan: "0000",
    source_data_sub_type: "MASTERCARD", source_data_type: "card",
    success: success ? "true" : "false",
  };
}
async function sendValidCallback(paymobOrderId, txnId, amountCents, success) {
  const v = callbackValues(paymobOrderId, txnId, amountCents, success);
  return postCallback(v, signCallback(v));
}

async function newPaymobOrder(user) {
  const co = await rpc("create_checkout_order",
    { p_payment_method: "paymob_card", p_address: ADDRESS, p_items: item(1), p_idempotency_key: idk() }, user.jwt);
  const orderId = co.body?.order_id;
  const total = co.body?.total;
  const init = await initiate(orderId, user.jwt);
  const pay = await paymentRow(orderId, user.jwt);
  return { orderId, total, init, paymobOrderId: pay?.paymob_order_id, payment: pay };
}

async function main() {
  const txn = () => Math.floor(Math.random() * 1e9);

  // ── Paymob-1: initiation ─────────────────────────────────
  const P = await signup();
  const o1 = await newPaymobOrder(P);
  rec({
    test: "PAYMOB-1 initiation",
    orderId: o1.orderId, init_status: o1.init.status,
    checkout_url_present: o1.init.hasCheckoutUrl, init_message: o1.init.message,
    payment_status: o1.payment?.status, payment_method: o1.payment?.method,
    paymob_order_id_present: Boolean(o1.paymobOrderId),
    PASS: o1.init.status === 200 && o1.init.hasCheckoutUrl === true &&
      o1.payment?.status === "pending" && Boolean(o1.paymobOrderId),
  });

  // If initiation failed we cannot run the mapped-callback tests.
  if (!o1.paymobOrderId) {
    log({ SUMMARY: "PAYMOB", note: "initiation unavailable; mapped-callback tests skipped",
      scored: results.filter(r => typeof r.PASS === "boolean").length,
      passed: results.filter(r => r.PASS === true).length });
    return;
  }

  // ── Paymob-2: amount mismatch (valid HMAC, wrong amount) ─
  const stk2 = await variantStock(FIX.variant_id);
  const mism = await sendValidCallback(o1.paymobOrderId, txn(), o1.total + 100, true);
  const oAfter2 = await orderRow(o1.orderId, P.jwt);
  const pAfter2 = await paymentRow(o1.orderId, P.jwt);
  const stk2b = await variantStock(FIX.variant_id);
  rec({
    test: "PAYMOB-2 amount_mismatch",
    http_status: mism.status, code: mism.body?.code,
    order_status: oAfter2?.status, payment_status: pAfter2?.status,
    stock_unchanged: stk2 === stk2b,
    PASS: mism.status === 400 && mism.body?.code === "amount_mismatch" &&
      oAfter2?.status === "pending" && pAfter2?.status === "pending" && stk2 === stk2b,
  });

  // ── Paymob-3: valid success callback ─────────────────────
  const stk3 = await variantStock(FIX.variant_id);
  const succ = await sendValidCallback(o1.paymobOrderId, txn(), o1.total, true);
  const oAfter3 = await orderRow(o1.orderId, P.jwt);
  const pAfter3 = await paymentRow(o1.orderId, P.jwt);
  const stk3b = await variantStock(FIX.variant_id);
  rec({
    test: "PAYMOB-3 success",
    http_status: succ.status, code: succ.body?.code,
    order_status: oAfter3?.status, payment_status: pAfter3?.status,
    txn_present: Boolean(pAfter3?.transaction_id), stock_unchanged: stk3 === stk3b,
    PASS: succ.status === 200 && succ.body?.code === "success" &&
      oAfter3?.status === "paid" && pAfter3?.status === "success" &&
      Boolean(pAfter3?.transaction_id) && stk3 === stk3b,
  });

  // ── Paymob-4: duplicate success callback (idempotent) ────
  const dup = await sendValidCallback(o1.paymobOrderId, txn(), o1.total, true);
  const pAfter4 = await paymentRow(o1.orderId, P.jwt);
  const oAfter4 = await orderRow(o1.orderId, P.jwt);
  rec({
    test: "PAYMOB-4 duplicate_callback",
    http_status: dup.status, code: dup.body?.code,
    order_status: oAfter4?.status, payment_status: pAfter4?.status,
    PASS: dup.status === 200 && dup.body?.code === "already_processed" &&
      oAfter4?.status === "paid" && pAfter4?.status === "success",
  });

  // ── Paymob-5: decline (valid success=false) + stock restore
  const Q = await signup();
  const o2 = await newPaymobOrder(Q);
  const stk5 = await variantStock(FIX.variant_id);
  const decl = await sendValidCallback(o2.paymobOrderId, txn(), o2.total, false);
  const oAfter5 = await orderRow(o2.orderId, Q.jwt);
  const pAfter5 = await paymentRow(o2.orderId, Q.jwt);
  const stk5b = await variantStock(FIX.variant_id);
  rec({
    test: "PAYMOB-5 decline_stock_restore",
    http_status: decl.status, code: decl.body?.code,
    order_status: oAfter5?.status, payment_status: pAfter5?.status,
    stock_before: stk5, stock_after: stk5b, stock_restored_by: stk5b - stk5,
    PASS: decl.status === 200 && decl.body?.code === "failed" &&
      oAfter5?.status === "cancelled" && pAfter5?.status === "failed" &&
      (stk5b - stk5) === 1,
  });

  // ── Paymob-6: late success after terminal (no resurrection)
  const stk6 = await variantStock(FIX.variant_id);
  const late = await sendValidCallback(o2.paymobOrderId, txn(), o2.total, true);
  const oAfter6 = await orderRow(o2.orderId, Q.jwt);
  const pAfter6 = await paymentRow(o2.orderId, Q.jwt);
  const stk6b = await variantStock(FIX.variant_id);
  rec({
    test: "PAYMOB-6 late_callback_no_resurrection",
    http_status: late.status, code: late.body?.code,
    order_status: oAfter6?.status, payment_status: pAfter6?.status,
    stock_unchanged: stk6 === stk6b,
    PASS: late.status === 200 && late.body?.code === "already_processed" &&
      oAfter6?.status === "cancelled" && pAfter6?.status === "failed" && stk6 === stk6b,
  });

  // ── Race-1: two identical success callbacks concurrently ─
  const R = await signup();
  const o3 = await newPaymobOrder(R);
  const t = txn();
  const stkR = await variantStock(FIX.variant_id);
  const [ra, rb] = await Promise.all([
    sendValidCallback(o3.paymobOrderId, t, o3.total, true),
    sendValidCallback(o3.paymobOrderId, t, o3.total, true),
  ]);
  const oAfterR = await orderRow(o3.orderId, R.jwt);
  const paysR = await restGet(`payments?order_id=eq.${o3.orderId}&select=id,status`, R.jwt);
  const successCount = (paysR.body || []).filter((p) => p.status === "success").length;
  const stkRb = await variantStock(FIX.variant_id);
  const codes = [ra.body?.code, rb.body?.code].sort();
  rec({
    test: "RACE-1 concurrent_duplicate_callbacks",
    codes, order_status: oAfterR?.status, success_payment_count: successCount,
    stock_unchanged_post_callbacks: stkR === stkRb,
    PASS: oAfterR?.status === "paid" && successCount === 1 &&
      ra.status === 200 && rb.status === 200 && stkR === stkRb,
  });

  // ── Race-2: two concurrent COD confirmations ─────────────
  const S = await signup();
  const coS = await rpc("create_checkout_order",
    { p_payment_method: "Cash on Delivery", p_address: ADDRESS, p_items: item(1), p_idempotency_key: idk() }, S.jwt);
  const orderS = coS.body?.order_id;
  const [ca, cb] = await Promise.all([
    rpc("confirm_cod_payment", { p_order_id: orderS }, S.jwt),
    rpc("confirm_cod_payment", { p_order_id: orderS }, S.jwt),
  ]);
  const paysS = await restGet(`payments?order_id=eq.${orderS}&select=id,status`, S.jwt);
  const succS = (paysS.body || []).filter((p) => p.status === "success").length;
  const oAfterS = await orderRow(orderS, S.jwt);
  const okCodes = [ca.body?.code, cb.body?.code].sort();
  rec({
    test: "RACE-2 concurrent_cod_confirm",
    codes: okCodes, order_status: oAfterS?.status, success_payment_count: succS,
    PASS: oAfterS?.status === "paid" && succS === 1 &&
      ca.body?.ok === true && cb.body?.ok === true,
  });

  const scored = results.filter((r) => typeof r.PASS === "boolean");
  const passed = scored.filter((r) => r.PASS === true).length;
  log({ SUMMARY: "PAYMOB+CALLBACK+RACE", scored: scored.length, passed, failed: scored.length - passed });
}

main().catch((e) => { log({ FATAL: String(e && e.message || e) }); process.exit(1); });
