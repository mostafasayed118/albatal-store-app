// ============================================================
// Paymob Callback HTTP Probe — live edge-function verification
//
// Scenarios:
//   A  forged hmac            -> expect HTTP 401 "Invalid signature"
//   B  valid hmac, wrong amt  -> expect ok=false code=amount_mismatch
//   C  valid hmac on expired  -> expect already_processed; order stays cancelled
//
// GUARDS:
//   - STAGING_DB_URL required, must contain zvpjngdgbpnkkqrorkul
//   - Endpoint URL must contain zvpjngdgbpnkkqrorkul
//   - PAYMOB_HMAC_SECRET read from env or .env.staging (NEVER printed)
// Usage: node supabase/tests/paymob_http_probe.mjs A|B|C
// ============================================================

import { Client } from 'pg';
import { readFileSync } from 'node:fs';

const REQUIRED_STAGING_REF = 'zvpjngdgbpnkkqrorkul';
const STAGING_URL = (process.env.STAGING_DB_URL ?? '').replace(/aws-[0-9]+-eu-west-1/, 'aws-1-eu-west-1');
const ENDPOINT = `https://${REQUIRED_STAGING_REF}.supabase.co/functions/v1/paymob-callback`;

if (!STAGING_URL || !STAGING_URL.includes(REQUIRED_STAGING_REF)) {
  console.error('ABORT: STAGING_DB_URL missing or not the isolated staging project.');
  process.exit(1);
}

function loadSecret() {
  if (process.env.PAYMOB_HMAC_SECRET) return process.env.PAYMOB_HMAC_SECRET;
  try {
    const env = readFileSync(new URL('../../.env.staging', import.meta.url), 'utf8');
    const m = env.match(/^PAYMOB_HMAC_SECRET=(.+)$/m);
    return m ? m[1].trim() : '';
  } catch {
    return '';
  }
}
const SECRET = loadSecret();
if (!SECRET) {
  console.error('ABORT: PAYMOB_HMAC_SECRET not found (env or .env.staging).');
  process.exit(1);
}

const FIELDS = [
  'amount_cents', 'created_at', 'currency', 'error_occured', 'has_parent_transaction',
  'id', 'integration_id', 'is_3d_secure', 'is_auth', 'is_capture', 'is_refunded',
  'is_standalone_payment', 'is_voided', 'order', 'owner', 'pending',
  'source_data_pan', 'source_data_sub_type', 'source_data_type', 'success',
];

async function sign(values) {
  const payload = FIELDS.map((f) => values[f] ?? '').join('');
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(SECRET), { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function postCallback(values, hmac) {
  const params = new URLSearchParams({ ...values, hmac });
  const res = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.PROBE_ANON_KEY ?? ''}`,
      apikey: process.env.PROBE_ANON_KEY ?? '',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: res.status, json, text: text.slice(0, 200) };
}

const client = new Client({ connectionString: STAGING_URL, ssl: { rejectUnauthorized: false } });
const scenario = process.argv[2]?.toUpperCase() ?? '';

try {
  await client.connect();

  // Anon key for platform JWT gate (public-by-design), read from committed config.
  const cfgPath = new URL('../../config/env.staging.json', import.meta.url);
  const anonKey = JSON.parse(readFileSync(cfgPath, 'utf8')).SUPABASE_ANON_KEY;
  process.env.PROBE_ANON_KEY = anonKey;

  const USER = 'B7C9D1E5-0000-4000-8000-00000000ABC1';
  const baseValues = {
    created_at: '2026-08-23T18:00:00.000000Z',
    currency: 'EGP',
    error_occured: 'false',
    has_parent_transaction: 'false',
    integration_id: '4507000000',
    is_3d_secure: 'false',
    is_auth: 'false',
    is_capture: 'false',
    is_refunded: 'false',
    is_standalone_payment: 'true',
    is_voided: 'false',
    owner: '987654',
    pending: 'false',
    source_data_pan: '2346********2346',
    source_data_sub_type: 'NotProvided',
    source_data_type: 'Settlement Account',
    success: 'true',
  };

  async function seedPending(paymobId, amountCents, expiresIn) {
    const orderId = crypto.randomUUID();
    await client.query(
      `INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, instance_id)
       VALUES ($1,'authenticated','authenticated',$2,'x',now(),'00000000-0000-0000-0000-000000000000')
       ON CONFLICT (id) DO NOTHING`,
      [USER, `probe-${paymobId}@staging-test.disposable`]);
    await client.query(
      `INSERT INTO profiles (id, full_name) VALUES ($1,'HTTP Probe') ON CONFLICT (id) DO NOTHING`, [USER]);
    await client.query(
      `INSERT INTO orders (id, user_id, status, subtotal, shipping, total, payment_method, address_snapshot, expires_at)
       VALUES ($1,$2,'pending',$3,0,$3,'paymob_card','{"recipient":"P","line":"L","city":"Cairo"}'::jsonb, now()::timestamp ${expiresIn})`,
      [orderId, USER, amountCents]);
    await client.query(
      `INSERT INTO payments (order_id, user_id, method, amount, status, paymob_order_id)
       VALUES ($1,$2,'paymob_card',$3,'pending',$4)`,
      [orderId, USER, amountCents, paymobId]);
    return orderId;
  }

  async function cleanupUser() {
    for (const sql of [
      `DELETE FROM state_transitions WHERE entity_id IN (SELECT id FROM payments WHERE user_id=$1::uuid) OR entity_id IN (SELECT id FROM orders WHERE user_id=$1::uuid)`,
      `DELETE FROM payments WHERE user_id=$1::uuid`,
      `DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE user_id=$1::uuid)`,
      `DELETE FROM orders WHERE user_id=$1::uuid`,
      `DELETE FROM profiles WHERE id=$1::uuid`,
      `DELETE FROM auth.users WHERE id=$1::uuid`,
    ]) {
      await client.query(sql, [USER]).catch(() => {});
    }
  }

  if (scenario === 'A') {
    console.log('── PROBE A: forged hmac ──');
    await postCallback({ ...baseValues, amount_cents: '100', order: 'PROBE-A-0001', id: 'TXN-A-1' }, 'deadbeef').then((r) => {
      console.log('HTTP', r.status, r.text);
      console.log(r.status === 401 ? 'RESULT: PASS (rejected at signature wall)' : 'RESULT: UNEXPECTED');
    });
  } else if (scenario === 'B') {
    console.log('── PROBE B: valid signature, amount mismatch ──');
    const orderId = await seedPending('PROBE-B-0001', 12345, '+ interval \'15 minutes\'');
    const values = { ...baseValues, amount_cents: '99999', order: 'PROBE-B-0001', id: 'TXN-B-1' };
    const hmac = await sign(values);
    const res = await postCallback(values, hmac);
    console.log('HTTP', res.status, res.text);
    const st = (await client.query(
      `SELECT o.status AS order_status, p.status AS payment_status FROM orders o JOIN payments p ON p.order_id=o.id WHERE o.id=$1`, [orderId])).rows[0];
    console.log('DB after:', JSON.stringify(st));
    // Edge contract: rejection surfaces as HTTP 400 with top-level code.
    const pass = res.status === 400 && res.json?.code === 'amount_mismatch'
      && st.order_status === 'pending' && st.payment_status === 'pending';
    console.log(pass ? 'RESULT: PASS (amount_mismatch, zero state change)' : 'RESULT: FAIL');
    await cleanupUser();
  } else if (scenario === 'C') {
    console.log('── PROBE C: late callback after expiry ──');
    const orderId = await seedPending('PROBE-C-0001', 7777, '- interval \'1 minute\'');
    const ex = (await client.query(`SELECT expire_pending_order($1) AS r`, [orderId])).rows[0].r;
    console.log('expiry:', JSON.stringify(ex));
    const values = { ...baseValues, amount_cents: '7777', order: 'PROBE-C-0001', id: 'TXN-C-1' };
    const hmac = await sign(values);
    const res = await postCallback(values, hmac);
    console.log('HTTP', res.status, res.text);
    const st = (await client.query(
      `SELECT o.status AS order_status, p.status AS payment_status FROM orders o JOIN payments p ON p.order_id=o.id WHERE o.id=$1`, [orderId])).rows[0];
    console.log('DB after:', JSON.stringify(st));
    // Edge contract: late-callback no-op is HTTP 200 + already_processed.
    const pass = res.status === 200 && res.json?.code === 'already_processed'
      && st.order_status === 'cancelled' && st.payment_status === 'expired';
    console.log(pass ? 'RESULT: PASS (late callback rejected, terminal states hold)' : 'RESULT: FAIL');
    await cleanupUser();
  } else {
    console.error('Usage: node supabase/tests/paymob_http_probe.mjs A|B|C');
    process.exitCode = 1;
  }

} catch (err) {
  console.error('❌ Fatal:', err.message);
  process.exitCode = 1;
} finally {
  await client.end().catch(() => {});
}
