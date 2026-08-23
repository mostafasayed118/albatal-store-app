// ============================================================
// COD E2E matrix — STAGING-E2E-E9A6DEB-2026-07-28 (staging only)
// Disposable fixtures. Emits one JSON line per test + summary.
// ============================================================
import {
  signup, rpc, restGet, variantStock, ADDRESS, log,
} from "./_e2e_lib.mjs";

const FIX = {
  product_id: "bbbb0003-0001-0001-0001-000000000003",
  variant_id: "35f2e5e1-ce84-45de-9de5-cabd776a8118",
  size: "1m", color: "Cream", unit_price: 69000,
};
const item = (qty) => ([{ product_id: FIX.product_id, size: FIX.size, color: FIX.color, quantity: qty }]);
const results = [];
const rec = (o) => { results.push(o); log(o); };
const idk = () => "e2e-" + Math.random().toString(36).slice(2, 12);

async function orderState(orderId, jwt) {
  const o = await restGet(`orders?id=eq.${orderId}&select=id,status,total,payment_method`, jwt);
  const p = await restGet(`payments?order_id=eq.${orderId}&select=id,status,method,amount,transaction_id`, jwt);
  return { order: o.body?.[0] ?? null, payments: Array.isArray(p.body) ? p.body : p.body };
}

async function makeCodOrder(user, qty) {
  const r = await rpc("create_checkout_order",
    { p_payment_method: "Cash on Delivery", p_address: ADDRESS, p_items: item(qty), p_idempotency_key: idk() }, user.jwt);
  return r;
}

async function main() {
  // ── Test 1: COD happy path ───────────────────────────────
  const A = await signup();
  const stockBefore = await variantStock(FIX.variant_id);
  const co = await makeCodOrder(A, 2);
  const orderId = co.body?.order_id;
  const stockAfterOrder = await variantStock(FIX.variant_id);
  const st1 = await orderState(orderId, A.jwt);
  const conf = await rpc("confirm_cod_payment", { p_order_id: orderId }, A.jwt);
  const stockAfterConfirm = await variantStock(FIX.variant_id);
  const st2 = await orderState(orderId, A.jwt);
  rec({
    test: "COD-1 happy_path",
    orderId,
    create_status: co.status, create_total: co.body?.total,
    order_status_after_create: st1.order?.status,
    stock_before: stockBefore, stock_after_order: stockAfterOrder,
    stock_decremented_by: stockBefore - stockAfterOrder,
    confirm_code: conf.body?.code, confirm_ok: conf.body?.ok,
    order_status_after_confirm: st2.order?.status,
    payment_status: st2.payments?.[0]?.status,
    payment_method: st2.payments?.[0]?.method,
    stock_after_confirm: stockAfterConfirm,
    txn_present: Boolean(st2.payments?.[0]?.transaction_id),
    PASS: co.status === 200 && st1.order?.status === "pending" &&
      (stockBefore - stockAfterOrder) === 2 && conf.body?.ok === true &&
      conf.body?.code === "confirmed" && st2.order?.status === "paid" &&
      st2.payments?.[0]?.status === "success" && stockAfterConfirm === stockAfterOrder,
  });

  // ── Test 2: COD idempotency ──────────────────────────────
  const conf2 = await rpc("confirm_cod_payment", { p_order_id: orderId }, A.jwt);
  const stockIdem = await variantStock(FIX.variant_id);
  const st3 = await orderState(orderId, A.jwt);
  rec({
    test: "COD-2 idempotency",
    orderId,
    second_confirm_code: conf2.body?.code, second_confirm_ok: conf2.body?.ok,
    payment_row_count: st3.payments?.length,
    payment_status: st3.payments?.[0]?.status,
    stock_after_second_confirm: stockIdem,
    stock_unchanged: stockIdem === stockAfterConfirm,
    PASS: conf2.body?.ok === true && conf2.body?.code === "already_confirmed" &&
      st3.payments?.length === 1 && st3.payments?.[0]?.status === "success" &&
      stockIdem === stockAfterConfirm,
  });

  // ── Test 3: COD non-owner ────────────────────────────────
  const B = await signup();
  const nonOwner = await rpc("confirm_cod_payment", { p_order_id: orderId }, B.jwt);
  const st4 = await orderState(orderId, A.jwt);
  rec({
    test: "COD-3 non_owner",
    orderId, attacker: B.userId,
    code: nonOwner.body?.code, ok: nonOwner.body?.ok,
    order_status_unchanged: st4.order?.status,
    PASS: nonOwner.body?.ok === false && nonOwner.body?.code === "not_owner" &&
      st4.order?.status === "paid",
  });

  // ── Test 4: COD anonymous ────────────────────────────────
  const C = await signup();
  const coC = await makeCodOrder(C, 1);
  const orderC = coC.body?.order_id;
  const anon = await rpc("confirm_cod_payment", { p_order_id: orderC }, null);
  const stC = await orderState(orderC, C.jwt);
  rec({
    test: "COD-4 anonymous",
    orderId: orderC,
    http_status: anon.status,
    code: anon.body?.code || anon.body?.message,
    order_status_unchanged: stC.order?.status,
    denied: anon.status === 401 || anon.status === 403 || anon.body?.code === "authentication_required",
    PASS: (anon.status === 401 || anon.status === 403 || anon.body?.code === "authentication_required") &&
      stC.order?.status === "pending",
  });

  // ── Test 5: COD on non-COD (paymob) order ────────────────
  const D = await signup();
  const coD = await rpc("create_checkout_order",
    { p_payment_method: "paymob_card", p_address: ADDRESS, p_items: item(1), p_idempotency_key: idk() }, D.jwt);
  const orderD = coD.body?.order_id;
  const notCod = await rpc("confirm_cod_payment", { p_order_id: orderD }, D.jwt);
  const stD = await orderState(orderD, D.jwt);
  rec({
    test: "COD-5 non_cod_order",
    orderId: orderD, order_method: stD.order?.payment_method,
    code: notCod.body?.code, ok: notCod.body?.ok,
    order_status_unchanged: stD.order?.status,
    PASS: notCod.body?.ok === false && notCod.body?.code === "payment_not_cod" &&
      stD.order?.status === "pending",
  });

  // ── Test 6: COD terminal-state (order_not_pending) ───────
  // Constructibility check: no client-only cancel path for a
  // COD order exists (cancel requires service-role or the
  // 15-min expiry sweep). Recorded as N/A-by-design; the
  // pending guard is covered by the paid-idempotency branch
  // (Test 2) and code review.
  rec({
    test: "COD-6 terminal_state_not_pending",
    status: "N/A_BY_DESIGN",
    note: "No client-only path cancels a COD order; order_not_pending guard verified by review + paid-idempotency branch (Test 2).",
    PASS: null,
  });

  // ── Test 7: COD missing payment row ──────────────────────
  // confirm_cod_payment CREATES the COD payment row if absent
  // (migration 018 L147-154), so payment_not_found is
  // unreachable by design. Recorded as N/A-by-design.
  rec({
    test: "COD-7 missing_payment_row",
    status: "N/A_BY_DESIGN",
    note: "confirm_cod_payment creates the COD payment row when absent; payment_not_found unreachable by design.",
    PASS: null,
  });

  const scored = results.filter((r) => r.PASS === true || r.PASS === false);
  const passed = scored.filter((r) => r.PASS === true).length;
  log({ SUMMARY: "COD", scored: scored.length, passed, failed: scored.length - passed,
    na: results.length - scored.length });
}

main().catch((e) => { log({ FATAL: String(e && e.message || e) }); process.exit(1); });
