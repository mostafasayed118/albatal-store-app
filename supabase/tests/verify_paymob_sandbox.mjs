import { Client } from 'pg';


// ── SAFETY GUARD ─────────────────────────────────────────────
// This script may ONLY run against the isolated STAGING project.
// The previous staging project ref is now PRODUCTION and must
// never be touched by test runners.
// Connection string comes from the STAGING_DB_URL env var only —
// never from a committed constant.
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
// ── END SAFETY GUARD ─────────────────────────────────────────

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
  console.log('Connected to Supabase staging.\n');

  // ═══════════════════════════════════════════════════════════
  // SEED DATA
  // ═══════════════════════════════════════════════════════════
  console.log('═══ SEED ═══');
  const userId = 'A1B2C3D4-0001-0001-0001-000000000001';
  await client.query(`
    INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
    VALUES ('${userId}', 'authenticated', 'authenticated', 'paymob-test@staging-test.disposable', 'x', now(), '00000000-0000-0000-0000-000000000000')
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO profiles (id, full_name, is_admin) VALUES ('${userId}', 'Paymob Tester', false) ON CONFLICT (id) DO UPDATE SET is_admin = false;
    INSERT INTO categories (id, name, slug, sort_order) VALUES ('AA000000-0000-0000-0000-000000000001', 'PaymobCat', 'paymob-cat', 99) ON CONFLICT (id) DO NOTHING;
    INSERT INTO products (id, category_id, name, slug, base_price) VALUES ('AA000000-0000-0000-0000-000000000002', 'AA000000-0000-0000-0000-000000000001', 'PaymobProd', 'paymob-prod', 5000) ON CONFLICT (id) DO NOTHING;
    INSERT INTO product_variants (id, product_id, size, color, stock, is_active) VALUES ('AA000000-0000-0000-0000-000000000003', 'AA000000-0000-0000-0000-000000000002', 'M', 'Black', 100, true) ON CONFLICT (id) DO NOTHING;
    DROP TABLE IF EXISTS _paymob_r;
    CREATE TABLE _paymob_r (test_id TEXT, expected TEXT, actual TEXT);
  `);
  console.log('  Seeded.\n');

  // ═══════════════════════════════════════════════════════════
  // FLOW 1: SUCCESS
  // ═══════════════════════════════════════════════════════════
  console.log('═══ FLOW 1: SUCCESS ═══');
  await client.query(`DO $f1$ DECLARE v_order JSONB; v_pay TEXT; v_cb JSONB; v_user UUID := '${userId}'; BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    SELECT create_checkout_order('paymob_card', '{"recipient":"Test","line":"123 St","city":"Cairo"}'::jsonb,
      '[{"product_id":"AA000000-0000-0000-0000-000000000002","variant_id":"AA000000-0000-0000-0000-000000000003","size":"M","color":"Black","quantity":1,"unit_price":5000}]'::jsonb, 'pf1') INTO v_order;
    RESET ROLE;
    INSERT INTO payments (order_id, user_id, method, amount, paymob_order_id, status) VALUES ((v_order->>'order_id')::uuid, v_user, 'paymob_card', 10000, 'ps-s1', 'pending') RETURNING id INTO v_pay;
    SET ROLE service_role;
    SELECT process_paymob_callback('ps-s1', 'TXN-S1', 10000, 'EGP', true) INTO v_cb;
    INSERT INTO _paymob_r SELECT 'F1.1', 'true', CASE WHEN v_order->>'order_id' IS NOT NULL THEN 'true' ELSE 'false' END;
    INSERT INTO _paymob_r SELECT 'F1.2', 'pending', v_order->>'status';
    INSERT INTO _paymob_r SELECT 'F1.3', '10000', v_order->>'total';
    INSERT INTO _paymob_r SELECT 'F1.4', 'true', (v_cb->>'ok')::text;
    INSERT INTO _paymob_r SELECT 'F1.5', 'success', v_cb->>'code';
    INSERT INTO _paymob_r SELECT 'F1.6', 'paid', (SELECT status::text FROM orders WHERE id = (v_order->>'order_id')::uuid);
    INSERT INTO _paymob_r SELECT 'F1.7', 'success', (SELECT status FROM payments WHERE id = v_pay::uuid);
    INSERT INTO _paymob_r SELECT 'F1.8', 'TXN-S1', (SELECT transaction_id::text FROM payments WHERE id = v_pay::uuid);
  END $f1$;`);
  let r = await client.query('SELECT * FROM _paymob_r ORDER BY test_id');
  for (const row of r.rows) assert(row.test_id, row.test_id, row.expected, row.actual);
  await client.query('DELETE FROM _paymob_r');
  console.log('');

  // ═══════════════════════════════════════════════════════════
  // FLOW 2: DECLINE
  // ═══════════════════════════════════════════════════════════
  console.log('═══ FLOW 2: DECLINE ═══');
  await client.query(`DO $f2$ DECLARE v_order JSONB; v_pay TEXT; v_cb JSONB; v_user UUID := '${userId}'; v_sb INT; BEGIN
    SELECT stock INTO v_sb FROM product_variants WHERE id = 'AA000000-0000-0000-0000-000000000003';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    SELECT create_checkout_order('paymob_card', '{"recipient":"T","line":"1 St","city":"Cairo"}'::jsonb,
      '[{"product_id":"AA000000-0000-0000-0000-000000000002","variant_id":"AA000000-0000-0000-0000-000000000003","size":"M","color":"Black","quantity":1,"unit_price":5000}]'::jsonb, 'pf2') INTO v_order;
    RESET ROLE;
    INSERT INTO payments (order_id, user_id, method, amount, paymob_order_id, status) VALUES ((v_order->>'order_id')::uuid, v_user, 'paymob_card', 10000, 'ps-d1', 'pending') RETURNING id INTO v_pay;
    SET ROLE service_role;
    SELECT process_paymob_callback('ps-d1', 'TXN-D1', 10000, 'EGP', false) INTO v_cb;
    INSERT INTO _paymob_r SELECT 'F2.1', 'true', (v_cb->>'ok')::text;
    INSERT INTO _paymob_r SELECT 'F2.2', 'failed', v_cb->>'code';
    INSERT INTO _paymob_r SELECT 'F2.3', 'cancelled', (SELECT status::text FROM orders WHERE id = (v_order->>'order_id')::uuid);
    INSERT INTO _paymob_r SELECT 'F2.4', 'failed', (SELECT status FROM payments WHERE id = v_pay::uuid);
    INSERT INTO _paymob_r SELECT 'F2.5', v_sb::text, (SELECT stock::text FROM product_variants WHERE id = 'AA000000-0000-0000-0000-000000000003');
  END $f2$;`);
  r = await client.query('SELECT * FROM _paymob_r ORDER BY test_id');
  for (const row of r.rows) assert(row.test_id, 'Decline: ' + row.test_id, row.expected, row.actual);
  await client.query('DELETE FROM _paymob_r');
  console.log('');

  // ═══════════════════════════════════════════════════════════
  // FLOW 3: CANCEL
  // ═══════════════════════════════════════════════════════════
  console.log('═══ FLOW 3: CANCEL ═══');
  await client.query(`DO $f3$ DECLARE v_order JSONB; v_pay TEXT; v_cb JSONB; v_user UUID := '${userId}'; v_sb INT; BEGIN
    SELECT stock INTO v_sb FROM product_variants WHERE id = 'AA000000-0000-0000-0000-000000000003';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    SELECT create_checkout_order('paymob_card', '{"recipient":"T","line":"1 St","city":"Cairo"}'::jsonb,
      '[{"product_id":"AA000000-0000-0000-0000-000000000002","variant_id":"AA000000-0000-0000-0000-000000000003","size":"M","color":"Black","quantity":1,"unit_price":5000}]'::jsonb, 'pf3') INTO v_order;
    RESET ROLE;
    INSERT INTO payments (order_id, user_id, method, amount, paymob_order_id, status) VALUES ((v_order->>'order_id')::uuid, v_user, 'paymob_card', 10000, 'ps-c1', 'pending') RETURNING id INTO v_pay;
    SET ROLE service_role;
    SELECT process_paymob_callback('ps-c1', 'TXN-C1', 10000, 'EGP', false) INTO v_cb;
    INSERT INTO _paymob_r SELECT 'F3.1', 'true', (v_cb->>'ok')::text;
    INSERT INTO _paymob_r SELECT 'F3.2', 'failed', v_cb->>'code';
    INSERT INTO _paymob_r SELECT 'F3.3', 'cancelled', (SELECT status::text FROM orders WHERE id = (v_order->>'order_id')::uuid);
    INSERT INTO _paymob_r SELECT 'F3.4', 'failed', (SELECT status FROM payments WHERE id = v_pay::uuid);
    INSERT INTO _paymob_r SELECT 'F3.5', v_sb::text, (SELECT stock::text FROM product_variants WHERE id = 'AA000000-0000-0000-0000-000000000003');
  END $f3$;`);
  r = await client.query('SELECT * FROM _paymob_r ORDER BY test_id');
  for (const row of r.rows) assert(row.test_id, 'Cancel: ' + row.test_id, row.expected, row.actual);
  await client.query('DELETE FROM _paymob_r');
  console.log('');

  // ═══════════════════════════════════════════════════════════
  // IDEMPOTENCY
  // ═══════════════════════════════════════════════════════════
  console.log('═══ IDEMPOTENCY ═══');
  await client.query(`DO $f4$ DECLARE v_cb JSONB; BEGIN
    SET ROLE service_role;
    SELECT process_paymob_callback('ps-s1', 'TXN-DUP', 10000, 'EGP', true) INTO v_cb;
    INSERT INTO _paymob_r SELECT 'F4.1', 'already_processed', v_cb->>'code';
    SELECT process_paymob_callback('UNKNOWN-999', 'TXN-UNK', 10000, 'EGP', true) INTO v_cb;
    INSERT INTO _paymob_r SELECT 'F4.2', 'unmapped_payment', v_cb->>'code';
    INSERT INTO _paymob_r SELECT 'F4.3', '0', (SELECT count(*)::text FROM payments WHERE paymob_order_id = 'UNKNOWN-999');
  END $f4$;`);
  r = await client.query('SELECT * FROM _paymob_r ORDER BY test_id');
  for (const row of r.rows) assert(row.test_id, 'Idemp: ' + row.test_id, row.expected, row.actual);
  await client.query('DELETE FROM _paymob_r');
  console.log('');

  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════
  console.log('═══ CLEANUP ═══');
  await client.query(`
    RESET ROLE;
    DELETE FROM state_transitions WHERE entity_id IN (
      SELECT id FROM payments WHERE user_id = '${userId}'
      UNION SELECT id FROM orders WHERE user_id = '${userId}');
    DELETE FROM order_items WHERE product_id = 'AA000000-0000-0000-0000-000000000002';
    DELETE FROM payments WHERE user_id = '${userId}';
    DELETE FROM orders WHERE user_id = '${userId}';
    DELETE FROM profiles WHERE id = '${userId}';
    DELETE FROM auth.users WHERE id = '${userId}';
    DELETE FROM product_variants WHERE id = 'AA000000-0000-0000-0000-000000000003';
    DELETE FROM products WHERE id = 'AA000000-0000-0000-0000-000000000002';
    DELETE FROM categories WHERE id = 'AA000000-0000-0000-0000-000000000001';
    DROP TABLE IF EXISTS _paymob_r;
  `);
  console.log('  Done.\n');

  // ═══════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════
  console.log('═══════════════════════════════════════════════════════');
  console.log('  PAYMOB SANDBOX VERIFICATION RESULTS');
  console.log('═══════════════════════════════════════════════════════\n');
  console.table(results);
  console.log(`\n  Passed: ${passed}/${passed + failed}`);
  console.log(`  Failed: ${failed}/${passed + failed}`);
  console.log(`  Verdict: ${failed === 0 ? '✅ ALL PASS — PAYMOB FLOWS VERIFIED' : '❌ FAILURES DETECTED'}`);

} catch (err) {
  console.error('❌ Fatal error:', err.message);
} finally {
  await client.end();
}
