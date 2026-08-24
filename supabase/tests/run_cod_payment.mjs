// ============================================================
// COD Confirm Runner — migration 018/026 RPC contract
//
// Node/pg port of supabase/tests/test_cod_payment.sql.
// Same fixtures and expected codes; runs against ISOLATED
// STAGING ONLY inside a single BEGIN/ROLLBACK transaction.
//
// Deviation from the .sql original: identity is supplied via
// request.jwt.claim.sub (what auth.uid() reads on this project),
// not the legacy request.jwt.claims JSON GUC.
//
// GUARDS:
//   - STAGING_DB_URL unset        -> ABORT (exit 1)
//   - STAGING_DB_URL wrong ref    -> ABORT (exit 1)
//   - Only zvpjngdgbpnkkqrorkul accepted.
// ============================================================

import { Client } from 'pg';

const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
const STAGING_URL = process.env.STAGING_DB_URL ?? '';

if (!STAGING_URL) {
  console.error('ABORT: STAGING_DB_URL is not set. Export the isolated staging connection string first.');
  process.exit(1);
}
if (!STAGING_URL.includes(REQUIRED_STAGING_REF)) {
  console.error(`ABORT: STAGING_DB_URL does not reference the isolated staging project ${REQUIRED_STAGING_REF}. Refusing to run.`);
  process.exit(1);
}

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

const client = new Client({ connectionString: STAGING_URL, ssl: { rejectUnauthorized: false } });

try {
  await client.connect();
  console.log('Connected to isolated staging.\n');

  const OWNER = '44444444-4444-4444-4444-444444444444';
  const OTHER = '55555555-5555-5555-5555-555555555555';
  const O1 = '66666666-6666-6666-6666-666666666666'; // pending COD
  const O2 = '66666666-6666-6666-6666-666666667777'; // paymob (non-COD)
  const O3 = '66666666-6666-6666-6666-666666668888'; // cancelled COD
  const O4 = '66666666-6666-6666-6666-666666669999'; // COD w/ failed payment

  async function asUser(id) {
    await client.query(
      `SELECT set_config('request.jwt.claim.sub', $1, true),
              set_config('request.jwt.claim.role', 'authenticated', true)`,
      [id ?? '']
    );
  }
  async function confirm(orderId) {
    return (await client.query(`SELECT confirm_cod_payment($1) AS r`, [orderId])).rows[0].r;
  }

  await client.query('BEGIN');

  // ─── Fixtures (identical to test_cod_payment.sql) ─────────
  await client.query(`
    INSERT INTO categories (id, name, slug, sort_order)
      VALUES ('11111111-1111-1111-1111-111111111111', 'TestCat', 'test-cat', 0)
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO products (id, category_id, name, slug, base_price)
      VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111',
              'TestProduct', 'test-product', 1000)
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO product_variants (id, product_id, size, color, stock)
      VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222',
              'M', 'Black', 10)
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
      VALUES ('${OWNER}', 'authenticated', 'authenticated', 'owner-test@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000')
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
      VALUES ('${OTHER}', 'authenticated', 'authenticated', 'other-test@example.com', 'x', now(), '00000000-0000-0000-0000-000000000000')
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO profiles (id, full_name, is_admin)
      VALUES ('${OWNER}', 'Owner', false) ON CONFLICT (id) DO UPDATE SET is_admin = false;
    INSERT INTO profiles (id, full_name, is_admin)
      VALUES ('${OTHER}', 'Other', false) ON CONFLICT (id) DO UPDATE SET is_admin = false;
    INSERT INTO orders (id, user_id, status, subtotal, shipping, total, payment_method, address_snapshot, placed_at)
      VALUES ('${O1}', '${OWNER}', 'pending', 1000, 0, 1000, 'Cash on Delivery',
              '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now())
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO order_items (id, order_id, product_id, variant_id, product_name, size, color, unit_price, quantity)
      VALUES ('77777777-7777-7777-7777-777777777777', '${O1}', '22222222-2222-2222-2222-222222222222',
              '33333333-3333-3333-3333-333333333333', 'TestProduct', 'M', 'Black', 1000, 1)
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO payments (id, order_id, user_id, method, amount, status)
      VALUES ('88888888-8888-8888-8888-888888888888', '${O1}', '${OWNER}', 'cash_on_delivery', 1000, 'pending')
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO orders (id, user_id, status, subtotal, shipping, total, payment_method, address_snapshot, placed_at)
      VALUES ('${O2}', '${OWNER}', 'pending', 2000, 0, 2000, 'paymob_card',
              '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now())
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO payments (id, order_id, user_id, method, amount, status)
      VALUES ('88888888-8888-8888-8888-888888889999', '${O2}', '${OWNER}', 'paymob_card', 2000, 'pending')
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO orders (id, user_id, status, subtotal, shipping, total, payment_method, address_snapshot, placed_at)
      VALUES ('${O3}', '${OWNER}', 'cancelled', 500, 0, 500, 'Cash on Delivery',
              '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now())
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO orders (id, user_id, status, subtotal, shipping, total, payment_method, address_snapshot, placed_at)
      VALUES ('${O4}', '${OWNER}', 'pending', 750, 0, 750, 'Cash on Delivery',
              '{"recipient":"T","line":"L","city":"Cairo"}'::jsonb, now())
      ON CONFLICT (id) DO NOTHING;
    INSERT INTO payments (id, order_id, user_id, method, amount, status)
      VALUES ('88888888-8888-8888-8888-888888880001', '${O4}', '${OWNER}', 'cash_on_delivery', 750, 'failed')
      ON CONFLICT (id) DO NOTHING;
  `);

  // ─── T1: owner confirms pending COD ──────────────────────
  await asUser(OWNER);
  const t1 = await confirm(O1);
  assert('T1', 'confirm returned ok=true', true, t1.ok === true);
  assert('T1', "code='confirmed'", 'confirmed', t1.code);
  assert('T1', 'transaction_id starts with COD-', true,
    typeof t1.transaction_id === 'string' && t1.transaction_id.startsWith('COD-'));
  const st1 = (await client.query(
    `SELECT p.status AS pay_status, p.transaction_id, o.status AS order_status
       FROM payments p JOIN orders o ON o.id = p.order_id WHERE p.order_id = $1`, [O1])).rows[0];
  assert('T1/T8', "payment.status='success'", 'success', st1.pay_status);
  assert('T1/T9', "order.status='paid'", 'paid', st1.order_status);
  assert('T1/T10', 'stored transaction_id matches returned', t1.transaction_id, st1.transaction_id);

  // ─── T2: idempotent second call ──────────────────────────
  const t2 = await confirm(O1);
  assert('T2', "code='already_confirmed'", 'already_confirmed', t2.code);
  assert('T2', 'transaction_id unchanged', t1.transaction_id, t2.transaction_id);

  // ─── T3: non-owner rejected ──────────────────────────────
  await asUser(OTHER);
  const t3 = await confirm(O4);
  assert('T3', "code='not_owner'", 'not_owner', t3.code);

  // ─── T4: anonymous rejected ──────────────────────────────
  await asUser(null);
  const t4 = await confirm(O1);
  assert('T4', "code='authentication_required'", 'authentication_required', t4.code);

  // ─── T5–T7, T11 back under owner ─────────────────────────
  await asUser(OWNER);
  const t5 = await confirm(O2);
  assert('T5', "code='payment_not_cod'", 'payment_not_cod', t5.code);
  const t6 = await confirm(O3);
  assert('T6', "code='order_not_pending'", 'order_not_pending', t6.code);
  const t7 = await confirm(O1);
  assert('T7', "code='already_confirmed' (paid-state path)", 'already_confirmed', t7.code);
  const t11 = await confirm(O4);
  assert('T11', "code='payment_not_pending'", 'payment_not_pending', t11.code);

  await client.query('ROLLBACK');

  console.log('\n═══════════════════════════════════════════════════════');
  console.table(results);
  console.log(`\n  Passed: ${passed}/${passed + failed}`);
  console.log(`  Verdict: ${failed === 0 ? '✅ ALL PASS — COD CONFIRM CONTRACT VERIFIED' : '❌ FAILURES DETECTED'}`);
  process.exitCode = failed === 0 ? 0 : 1;

} catch (err) {
  console.error('❌ Fatal error:', err.message);
  try { await client.query('ROLLBACK'); } catch {}
  process.exitCode = 1;
} finally {
  await client.end().catch(() => {});
}
