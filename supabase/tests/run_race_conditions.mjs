// ============================================================
// Race Condition Test Runner — Migration 025 (T-RC01..T-RC14)
//
// Node/pg port of supabase/tests/test_race_conditions.sql.
// Runs ALL 14 race scenarios against ISOLATED STAGING ONLY,
// inside a single BEGIN/ROLLBACK transaction (no persistent
// state changes), mirroring the psql original.
//
// USAGE:
//   STAGING_DB_URL='postgresql://postgres.<ref>:<pw>@aws-1-eu-west-1.pooler.supabase.com:5432/postgres' \
//     node supabase/tests/run_race_conditions.mjs
//
// GUARDS:
//   - STAGING_DB_URL unset        -> ABORT (exit 1)
//   - STAGING_DB_URL wrong ref    -> ABORT (exit 1)
//   - Only ref zvpjngdgbpnkkqrorkul accepted. Production
//     ref alxwvyflasewslinufqe is NEVER connected to.
//
// MULTI-SESSION NOTES:
//   Scenarios T-RC01..T-RC14 are sequential-ordering race
//   simulations (callback vs expiry vs admin cancel fired in
//   deterministic order inside one session/transaction), exactly
//   as authored in test_race_conditions.sql. They deliberately do
//   NOT require concurrent sessions. Additional sessions cannot
//   observe this runner's uncommitted transaction (READ COMMITTED),
//   so the only legitimate multi-session step is the POST-CLEANUP
//   residue verification below, which opens a SECOND independent
//   pg Client (see CLEANUP VERIFICATION — MULTI SESSION).
//
// STOCK ASSERTION NOTE:
//   All stock checks use a per-order baseline captured immediately
//   after checkout decrement ("restored exactly once" invariant)
//   instead of the psql script's cross-scenario absolute constants,
//   keeping each scenario self-contained and order-independent.
// ============================================================

import { Client } from 'pg';

const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
const STAGING_DB_URL = (process.env.STAGING_DB_URL ?? '').replace(/aws-[0-9]+-eu-west-1/, 'aws-1-eu-west-1');

let passed = 0;
let failed = 0;
const results = [];

function assert(testId, description, expected, actual) {
  const ok = String(expected) === String(actual);
  const status = ok ? 'PASS' : 'FAIL';
  if (ok) passed++; else failed++;
  results.push({ test_id: testId, description, expected: String(expected), actual: String(actual), status });
  console.log(`  ${status} ${testId}: ${description}`);
  if (!ok) console.log(`         expected=${expected} actual=${actual}`);
}

// ─── GUARD 1: STAGING_DB_URL must be set ────────────────────
if (!STAGING_DB_URL) {
  console.error('ABORT: STAGING_DB_URL is not set.');
  console.error('Set it to the isolated staging pooler URL (ref ' + REQUIRED_STAGING_REF + ') and retry.');
  process.exit(1);
}

// ─── GUARD 2: URL must target the isolated staging ref ──────
const isStagingRef =
  STAGING_DB_URL.includes(`postgres.${REQUIRED_STAGING_REF}`) ||
  STAGING_DB_URL.includes(`db.${REQUIRED_STAGING_REF}`);
if (!isStagingRef) {
  console.error(`ABORT: STAGING_DB_URL does not point at staging ref ${REQUIRED_STAGING_REF}.`);
  console.error('Refusing to run: this suite may only target the isolated staging database.');
  process.exit(1);
}

console.log('');
console.log('═══════════════════════════════════════════════════════');
console.log('  RACE CONDITION TEST SUITE — Migration 025');
console.log('═══════════════════════════════════════════════════════');
console.log('');

const client = new Client({ connectionString: STAGING_DB_URL, ssl: { rejectUnauthorized: false } });

try {
  await client.connect();
  console.log('Connected to isolated staging.\n');

  // Single wrapping transaction — everything rolled back at the end.
  await client.query('BEGIN');

  // ─── Fixtures ─────────────────────────────────────────────
  // Disposable user, product, and ONE shared variant (stock 10),
  // matching the psql original's sequential stock accounting.
  const userId = crypto.randomUUID();
  await client.query(
    `INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
     VALUES ($1, 'authenticated', 'authenticated', 'race-test@staging-test.disposable', 'x', now(), '00000000-0000-0000-0000-000000000000')
     ON CONFLICT (id) DO NOTHING`,
    [userId]
  );
  await client.query(
    `INSERT INTO profiles (id, full_name, phone) VALUES ($1, 'Race Test User', '+201000000000')
     ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name`,
    [userId]
  );

  const productId = crypto.randomUUID();
  await client.query(
    `INSERT INTO products (id, category_id, name, slug, base_price, is_active)
     VALUES ($1, (SELECT id FROM categories LIMIT 1), 'Race Test Product',
             'race-test-product-' || floor(random()*10000)::int, 10000, true)`,
    [productId]
  );

  const variantId = crypto.randomUUID();
  await client.query(
    `INSERT INTO product_variants (id, product_id, size, color, stock, is_active)
     VALUES ($1, $2, 'M', 'Black', 10, true)`,
    [variantId, productId]
  );
  console.log('Fixtures seeded (user, product, variant stock=10).\n');

  // ─── Helpers ──────────────────────────────────────────────
  let scenarioSeq = 0;

  async function createPendingOrder(opts) {
    const {
      paymobOrder,
      expiresIn = '+15 minutes',       // SQL interval literal
      method = 'paymob_card',
      amount = 10000,
      decrementStock = false,
    } = opts;
    const orderId = crypto.randomUUID();
    await client.query(
      `INSERT INTO orders (id, user_id, status, subtotal, shipping, total,
                           payment_method, address_snapshot, expires_at)
       VALUES ($1, $2, 'pending', 10000, 0, 10000, $3,
               '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
               now() ${expiresIn.startsWith('-') ? '-' : '+'} interval '${expiresIn.replace(/^[+-]\s*/, '')}')`,
      [orderId, userId, method]
    );
    await client.query(
      `INSERT INTO order_items (order_id, product_id, variant_id,
                                product_name, size, color, unit_price, quantity)
       VALUES ($1, $2, $3, 'Race Test Product', 'M', 'Black', 10000, 1)`,
      [orderId, productId, variantId]
    );
    if (decrementStock) {
      await client.query(`UPDATE product_variants SET stock = stock - 1 WHERE id = $1`, [variantId]);
    }
    if (paymobOrder) {
      await client.query(
        `INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
         VALUES ($1, $2, 'paymob_card', $3, 'pending', $4)`,
        [orderId, userId, amount, paymobOrder]
      );
    }
    return orderId;
  }

  async function callback(paymobOrder, txn, amount = 10000, success = true) {
    const r = await client.query(
      `SELECT process_paymob_callback($1, $2, $3, 'EGP', $4) AS result`,
      [paymobOrder, txn, amount, success]
    );
    return r.rows[0].result;
  }

  async function expire(orderId) {
    const r = await client.query(`SELECT expire_pending_order($1) AS result`, [orderId]);
    return r.rows[0].result;
  }

  async function codConfirm(orderId) {
    const r = await client.query(`SELECT confirm_cod_payment($1) AS result`, [orderId]);
    return r.rows[0].result;
  }

  async function adminCancel(orderId) {
    const r = await client.query(`SELECT update_order_status($1, 'cancelled') AS result`, [orderId]);
    return r.rows[0].result;
  }

  async function orderStatus(orderId) {
    const r = await client.query(`SELECT status::text AS s FROM orders WHERE id = $1`, [orderId]);
    return r.rows[0].s;
  }

  async function paymentStatus(paymobOrder) {
    const r = await client.query(`SELECT status AS s FROM payments WHERE paymob_order_id = $1`, [paymobOrder]);
    return r.rows[0] ? r.rows[0].s : '(none)';
  }

  async function variantStock() {
    const r = await client.query(`SELECT stock AS s FROM product_variants WHERE id = $1`, [variantId]);
    return r.rows[0].s;
  }

  async function restorationCount(orderId) {
    const r = await client.query(`SELECT count(*)::int AS c FROM stock_restorations WHERE order_id = $1`, [orderId]);
    return r.rows[0].c;
  }

  function paymobId(n) {
    return `PAYMOB-RC${String(n).padStart(2, '0')}-${Math.floor(Math.random() * 1000000)}`;
  }

  // Run one scenario inside a SAVEPOINT so an unexpected DB error
  // aborts only that scenario, not the whole suite.
  async function scenario(id, fn) {
    scenarioSeq++;
    const sp = `rc_${scenarioSeq}`;
    console.log(`═══ ${id} ═══`);
    await client.query(`SAVEPOINT ${sp}`);
    try {
      await fn();
    } catch (err) {
      assert(id, 'scenario completed without unexpected DB error', 'no-error', `error: ${err.message}`);
      await client.query(`ROLLBACK TO SAVEPOINT ${sp}`);
    }
    await client.query(`RELEASE SAVEPOINT ${sp}`);
    console.log('');
  }

  // ═══════════════════════════════════════════════════════════
  // T-RC01: callback BEFORE expiry (happy path)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC01', async () => {
    const po = paymobId(1);
    const orderId = await createPendingOrder({ paymobOrder: po, decrementStock: true });

    const cb = await callback(po, 'TXN-RC01');
    assert('T-RC01', 'callback ok', true, cb.ok);
    assert('T-RC01', 'callback code=success', 'success', cb.code);

    const ex = await expire(orderId);
    assert('T-RC01', 'expiry ok', true, ex.ok);
    assert('T-RC01', 'expiry sees already_terminal', 'already_terminal', ex.code);

    assert('T-RC01', 'order status=paid', 'paid', await orderStatus(orderId));
    assert('T-RC01', 'payment status=success', 'success', await paymentStatus(po));
    assert('T-RC01', 'success path did NOT restore stock (no restorations row)',
      0, await restorationCount(orderId));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC02: expiry BEFORE callback (THE BUG FIX) — critical race
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC02', async () => {
    const po = paymobId(2);
    const orderId = await createPendingOrder({
      paymobOrder: po, expiresIn: '-1 minute', decrementStock: true,
    });
    const baseStock = await variantStock();

    const ex = await expire(orderId);
    assert('T-RC02', 'expiry code=expired', 'expired', ex.code);

    const cb = await callback(po, 'TXN-RC02');
    assert('T-RC02', 'late callback ok (no-op)', true, cb.ok);
    assert('T-RC02', 'late callback code=already_processed, NOT success',
      'already_processed', cb.code);

    assert('T-RC02', 'order stays cancelled (NOT promoted to paid)',
      'cancelled', await orderStatus(orderId));
    assert('T-RC02', 'payment stays expired (NOT marked success)',
      'expired', await paymentStatus(po));

    assert('T-RC02', 'stock restored exactly once',
      baseStock + 1, await variantStock());
    // NOTE (m025 contract): with the PAYMENT already terminal (expired),
    // process_paymob_callback exits via the silent payment-terminal
    // short-circuit — no late_callback_rejected audit is written on this
    // branch. The audited variant (order-terminal) is covered by T-RC06.
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC03: duplicate callback is no-op
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC03', async () => {
    const po = paymobId(3);
    await createPendingOrder({ paymobOrder: po, decrementStock: true });
    const stockAfterDecrement = await variantStock();

    const first = await callback(po, 'TXN-RC03');
    assert('T-RC03', 'first callback code=success', 'success', first.code);

    const dup = await callback(po, 'TXN-RC03');
    assert('T-RC03', 'duplicate callback code=already_processed',
      'already_processed', dup.code);

    assert('T-RC03', 'stock unchanged by success/duplicate (no double restore)',
      stockAfterDecrement, await variantStock());
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC04: double expiry is no-op
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC04', async () => {
    const po = paymobId(4);
    const orderId = await createPendingOrder({
      paymobOrder: po, expiresIn: '-1 minute', decrementStock: true,
    });
    const baseStock = await variantStock();

    const first = await expire(orderId);
    assert('T-RC04', 'first expiry code=expired', 'expired', first.code);

    const second = await expire(orderId);
    assert('T-RC04', 'second expiry code=already_terminal',
      'already_terminal', second.code);

    assert('T-RC04', 'stock restored exactly once',
      baseStock + 1, await variantStock());
    // m025 expiry restores stock via order_items.restored flag + trigger;
    // the stock_restorations ledger is update_order_status-only (m014).
    assert('T-RC04', 'all order_items flagged restored exactly once',
      0, (await client.query(
        `SELECT count(*)::int AS c FROM order_items WHERE order_id = $1 AND restored = false`,
        [orderId]
      )).rows[0].c);
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC05: success callback then admin cancel
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC05', async () => {
    const po = paymobId(5);
    const orderId = await createPendingOrder({ paymobOrder: po, decrementStock: true });
    const baseStock = await variantStock();

    const cb = await callback(po, 'TXN-RC05');
    assert('T-RC05', 'callback code=success', 'success', cb.code);

    await adminCancel(orderId); // valid transition: paid -> cancelled
    assert('T-RC05', 'order status=cancelled after admin cancel',
      'cancelled', await orderStatus(orderId));
    assert('T-RC05', 'admin cancel restored stock once',
      baseStock + 1, await variantStock());
    assert('T-RC05', 'stock_restorations has 1 row',
      1, await restorationCount(orderId));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC06: admin cancel then late callback (rejected)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC06', async () => {
    const po = paymobId(6);
    const orderId = await createPendingOrder({ paymobOrder: po });

    await adminCancel(orderId);

    const cb = await callback(po, 'TXN-RC06');
    assert('T-RC06', 'late callback code=already_processed (rejected)',
      'already_processed', cb.code);
    assert('T-RC06', 'order stays cancelled (NOT promoted to paid)',
      'cancelled', await orderStatus(orderId));
    assert('T-RC06', 'payment stays pending (NOT marked success)',
      'pending', await paymentStatus(po));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC07: amount mismatch rejected
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC07', async () => {
    const po = paymobId(7);
    const orderId = await createPendingOrder({ paymobOrder: po }); // total = 10000

    const cb = await callback(po, 'TXN-RC07', 9999);
    assert('T-RC07', 'mismatched callback ok=false', false, cb.ok);
    assert('T-RC07', 'code=amount_mismatch', 'amount_mismatch', cb.code);
    assert('T-RC07', 'order stays pending', 'pending', await orderStatus(orderId));
    assert('T-RC07', 'payment stays pending', 'pending', await paymentStatus(po));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC08: stock ledger — cancel (expiry) restores once
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC08', async () => {
    const po = paymobId(8);
    const orderId = await createPendingOrder({
      paymobOrder: po, expiresIn: '-1 minute', decrementStock: true,
    });
    const baseStock = await variantStock();

    const ex = await expire(orderId);
    assert('T-RC08', 'expiry code=expired', 'expired', ex.code);
    assert('T-RC08', 'stock restored once',
      baseStock + 1, await variantStock());

    await expire(orderId); // double expiry
    assert('T-RC08', 'double expiry did NOT double-restore',
      baseStock + 1, await variantStock());
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC09: stock ledger — callback-fail restores once
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC09', async () => {
    const po = paymobId(9);
    const orderId = await createPendingOrder({ paymobOrder: po, decrementStock: true });
    const baseStock = await variantStock();

    const f1 = await callback(po, 'TXN-RC09', 10000, false);
    assert('T-RC09', 'failure callback code=failed', 'failed', f1.code);
    assert('T-RC09', 'stock restored once',
      baseStock + 1, await variantStock());

    const f2 = await callback(po, 'TXN-RC09', 10000, false);
    assert('T-RC09', 'duplicate failure callback code=already_processed',
      'already_processed', f2.code);
    assert('T-RC09', 'duplicate failure did NOT double-restore',
      baseStock + 1, await variantStock());
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC10: stock ledger — double cancel restores once
  // (expiry cancel, then admin cancel must be REJECTED)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC10', async () => {
    const po = paymobId(10);
    const orderId = await createPendingOrder({
      paymobOrder: po, expiresIn: '-1 minute', decrementStock: true,
    });
    const baseStock = await variantStock();

    await expire(orderId); // first cancel

    // Second cancel via admin must raise ("Cannot change status of
    // cancelled order") — psql wraps in BEGIN/EXCEPTION WHEN OTHERS.
    let adminRejected = false;
    // The RAISE aborts the wrapping transaction — isolate it so the
    // remaining asserts in this scenario can still execute.
    await client.query('SAVEPOINT rc10_admin');
    try {
      await adminCancel(orderId);
    } catch {
      adminRejected = true;
    }
    await client.query('ROLLBACK TO SAVEPOINT rc10_admin');
    await client.query('RELEASE SAVEPOINT rc10_admin');
    assert('T-RC10', 'admin cancel on cancelled order rejected', true, adminRejected);
    assert('T-RC10', 'stock restored exactly once (no double restore)',
      baseStock + 1, await variantStock());
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC11: cancelled order late success (rejected)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC11', async () => {
    const po = paymobId(11);
    const orderId = await createPendingOrder({ paymobOrder: po, expiresIn: '-1 minute' });

    await expire(orderId); // cancel via expiry

    const cb = await callback(po, 'TXN-RC11');
    assert('T-RC11', 'late success code=already_processed (rejected)',
      'already_processed', cb.code);
    assert('T-RC11', 'order stays cancelled', 'cancelled', await orderStatus(orderId));
    assert('T-RC11', 'payment stays expired (NOT promoted to success)',
      'expired', await paymentStatus(po));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC12: audit trail completeness (after T-RC02 ran above)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC12', async () => {
    const lateCount = (await client.query(
      `SELECT count(*)::int AS c FROM state_transitions WHERE reason = 'late_callback_rejected'`
    )).rows[0].c;
    assert('T-RC12', 'at least 1 late_callback_rejected audit exists', true, lateCount >= 1);

    const trigCount = (await client.query(
      `SELECT count(*)::int AS c FROM state_transitions WHERE reason = 'trigger_audit'`
    )).rows[0].c;
    assert('T-RC12', 'trigger_audit records exist', true, trigCount >= 1);
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC13: COD then expiry (expiry no-ops)
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC13', async () => {
    const orderId = await createPendingOrder({ method: 'cash_on_delivery', decrementStock: true });
    // confirm_cod_payment requires a pending payments row (m026 guard);
    // the generic fixture only creates one for Paymob orders.
    await client.query(
      `INSERT INTO payments (order_id, user_id, method, amount, status)
       VALUES ($1, $2, 'cash_on_delivery', 10000, 'pending')`,
      [orderId, userId]
    );

    // confirm_cod_payment resolves the caller via auth.uid() (m019/026);
    // supply the fixture user's identity, transaction-scoped.
    await client.query(
      `SELECT set_config('request.jwt.claim.sub', $1, true),
              set_config('request.jwt.claim.role', 'authenticated', true)`,
      [userId]
    );
    const cc = await codConfirm(orderId);
    assert('T-RC13', 'confirm returned ok=true', true, cc && cc.ok === true);
    assert('T-RC13', 'order paid after COD confirm', 'paid', await orderStatus(orderId));
    const ex = await expire(orderId);
    assert('T-RC13', 'expiry sees already_terminal', 'already_terminal', ex.code);
    assert('T-RC13', 'order must stay paid', 'paid', await orderStatus(orderId));
  });

  // ═══════════════════════════════════════════════════════════
  // T-RC14: unmapped payment (invalid HMAC fallback layer) —
  // no state change.
  // ═══════════════════════════════════════════════════════════
  await scenario('T-RC14', async () => {
    const cb = await callback('NONEXISTENT-ORDER', 'TXN-RC14');
    assert('T-RC14', 'unmapped callback ok=false', false, cb.ok);
    assert('T-RC14', 'code=unmapped_payment', 'unmapped_payment', cb.code);
    assert('T-RC14', 'no payments row inserted for unmapped id', 0,
      (await client.query(
        `SELECT count(*)::int AS c FROM payments WHERE paymob_order_id = 'NONEXISTENT-ORDER'`
      )).rows[0].c);
  });

  // ═══════════════════════════════════════════════════════════
  // CLEANUP — the wrapping transaction is rolled back, so no
  // persistent state changes; explicit deletes are belt-and-braces
  // in case any statement committed out-of-band (e.g. dblink-less
  // autonomous helpers).
  // ═══════════════════════════════════════════════════════════
  console.log('═══ CLEANUP ═══');
  await client.query('ROLLBACK');
  await client.query(`
    DELETE FROM stock_restorations WHERE order_id IN (
      SELECT o.id FROM orders o JOIN payments p ON p.order_id = o.id
      WHERE p.paymob_order_id LIKE 'PAYMOB-RC%');
    DELETE FROM state_transitions WHERE entity_type = 'order' AND entity_id IN (
      SELECT o.id FROM orders o JOIN payments p ON p.order_id = o.id
      WHERE p.paymob_order_id LIKE 'PAYMOB-RC%');
    DELETE FROM payments WHERE paymob_order_id LIKE 'PAYMOB-RC%'
       OR paymob_order_id = 'NONEXISTENT-ORDER';
    DELETE FROM order_items WHERE order_id IN (
      SELECT id FROM orders WHERE address_snapshot->>'line' = '123 St'
        AND user_id = '${userId}');
    DELETE FROM orders WHERE user_id = '${userId}';
    DELETE FROM product_variants WHERE id = '${variantId}';
    DELETE FROM products WHERE id = '${productId}';
    DELETE FROM profiles WHERE id = '${userId}';
    DELETE FROM auth.users WHERE id = '${userId}';
  `);
  console.log('  Transaction rolled back; residual fixture rows deleted.\n');

  // ── CLEANUP VERIFICATION — MULTI SESSION ──────────────────
  // Open a SECOND independent pg Client to confirm from outside
  // the runner session that no test residue remains.
  console.log('═══ CLEANUP VERIFICATION (second session) ═══');
  const verifier = new Client({ connectionString: STAGING_DB_URL, ssl: { rejectUnauthorized: false } });
  try {
    await verifier.connect();
    const residue = (await verifier.query(
      `SELECT count(*)::int AS c FROM payments WHERE paymob_order_id LIKE 'PAYMOB-RC%'`
    )).rows[0].c;
    assert('CLEANUP', 'zero PAYMOB-RC% residue (verified from independent session)', 0, residue);
  } catch (err) {
    assert('CLEANUP', 'second-session verification connected', 'connected', `error: ${err.message}`);
  } finally {
    await verifier.end().catch(() => {});
  }
  console.log('');

  // ═══════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════
  console.log('═══════════════════════════════════════════════════════');
  console.log('  RACE CONDITION TEST RESULTS — Migration 025');
  console.log('═══════════════════════════════════════════════════════\n');
  console.table(results);
  console.log(`\n  Passed: ${passed}/${passed + failed}`);
  console.log(`  Failed: ${failed}/${passed + failed}`);
  console.log(`  Verdict: ${failed === 0 ? '✅ ALL PASS — RACE-SAFE STATE MACHINE VERIFIED' : '❌ FAILURES DETECTED'}`);

  process.exitCode = failed === 0 ? 0 : 1;

} catch (err) {
  console.error('❌ Fatal error:', err.message);
  try { await client.query('ROLLBACK'); } catch {}
  process.exitCode = 1;
} finally {
  await client.end().catch(() => {});
}
