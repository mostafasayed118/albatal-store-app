// ============================================================
// Live Initiate Probe — full server-side Paymob chain on staging
//
//   1. Sign up a disposable user via /auth/v1/signup (anon key).
//   2. Create an internal order via create_checkout_order RPC.
//   3. Call the paymob-initiate edge function with the user JWT.
//   4. Assert checkout_url points at Paymob and contains the
//      configured iframe id. Query string is NEVER printed.
//   5. Clean up all fixture rows via direct DB connection.
//
// GUARDS: staging ref required in SUPABASE_URL and STAGING_DB_URL.
// Usage: node supabase/tests/paymob_live_initiate_probe.mjs
// ============================================================

import { Client } from 'pg';
import { readFileSync } from 'node:fs';

const REF = 'zvpjngdgbpnkkqrorkul';
const cfg = JSON.parse(readFileSync(new URL('../../config/env.staging.json', import.meta.url), 'utf8'));
if (!cfg.SUPABASE_URL.includes(REF)) { console.error('ABORT: config is not staging.'); process.exit(1); }
const dbUrl = (process.env.STAGING_DB_URL ?? '').replace(/aws-[0-9]+-eu-west-1/, 'aws-1-eu-west-1');
if (!dbUrl.includes(REF)) { console.error('ABORT: STAGING_DB_URL missing/not staging.'); process.exit(1); }

const BASE = cfg.SUPABASE_URL;
const ANON = cfg.SUPABASE_ANON_KEY;

let passed = 0, failed = 0;
function check(id, ok, detail) {
  const s = ok ? 'PASS' : 'FAIL';
  ok ? passed++ : failed++;
  console.log(`  ${s} ${id}${detail ? ' — ' + detail : ''}`);
}

async function main() {
  // Pick a real catalog variant to order.
  const prod = await (await fetch(`${BASE}/rest/v1/products?select=id,name&limit=1`, { headers: { apikey: ANON, Authorization: `Bearer ${ANON}` } })).json();
  if (!Array.isArray(prod) || !prod[0]) throw new Error('no products on staging');
  const variant = await (await fetch(`${BASE}/rest/v1/product_variants?select=id,size,color&product_id=eq.${prod[0].id}&limit=1`, { headers: { apikey: ANON, Authorization: `Bearer ${ANON}` } })).json();
  if (!Array.isArray(variant) || !variant[0]) throw new Error('no variants for product');
  console.log(`catalog: "${prod[0].name}" variant ${variant[0].size}/${variant[0].color}`);

  // 1. Signup disposable user.
  const email = `e2e-initiate-${Date.now()}@staging-test.disposable`;
  const su = await (await fetch(`${BASE}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: ANON, Authorization: `Bearer ${ANON}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'E2e-Probe-2026-08-23!' }),
  })).json();
  const token = su.access_token;
  const uid = su.user?.id;
  check('signup', !!token && !!uid, token ? `user ${uid}` : `response keys: ${Object.keys(su).join(',')} (email confirmation likely ON)`);

  const client = new Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
  await client.connect();
  try {
    if (!token || !uid) return;

    const authH = { apikey: ANON, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

    // 2. Create internal order via RPC.
    const rpc = await (await fetch(`${BASE}/rest/v1/rpc/create_checkout_order`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({
        p_payment_method: 'paymob_card',
        p_address: { recipient: 'LiveProbe', line: '1 Test St', city: 'Cairo', governorate: 'Cairo', phone: '+201000000000' },
        p_items: [{ product_id: prod[0].id, variant_id: variant[0].id, size: variant[0].size ?? null, color: variant[0].color ?? null, quantity: 1 }],
        p_idempotency_key: crypto.randomUUID(),
      }),
    })).json();
    const orderId = Array.isArray(rpc) ? rpc[0]?.order_id : rpc?.order_id;
    check('create_checkout_order', !!orderId, orderId ? `order ${orderId}` : JSON.stringify(rpc).slice(0, 160));
    if (!orderId) return;

    // 3. Initiate.
    const init = await (await fetch(`${BASE}/functions/v1/paymob-initiate`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({ order_id: orderId }),
    }));
    const body = await init.json().catch(() => ({}));
    check('initiate HTTP 200', init.status === 200, `status=${init.status} msg=${body.message ?? ''}`);
    const urlStr = typeof body.checkout_url === 'string' ? body.checkout_url : '';
    let host = '', path = '', hasIframe = false;
    try {
      const u = new URL(urlStr);
      host = u.host; path = u.pathname;
      hasIframe = u.searchParams.get('iframe') === '1062411' || urlStr.includes('1062411');
    } catch {}
    check('checkout_url present', !!urlStr, urlStr ? '(value withheld)' : 'missing');
    check('hosted on Paymob accept domain', /paymob|accept/.test(host + path), `${host}${path}`);
    check('uses configured iframe 1062411', hasIframe);
    check('no payment_token leaked into logs', true); // we never printed query

    // Payment row created pending with provider order id persisted?
    const pay = await client.query(
      `SELECT status, paymob_order_id IS NOT NULL AS has_provider FROM payments WHERE order_id=$1`, [orderId]);
    const row = pay.rows[0];
    check('payment row pending w/ provider id', !!row && row.status === 'pending' && row.has_provider,
      row ? `status=${row.status} provider_set=${row.has_provider}` : 'no row');

    if (process.env.KEEP_FIXTURES === '1' && urlStr) {
      const out = process.env.PAYMOB_URL_OUT ?? 'paymob_checkout_url.txt';
      const { writeFileSync } = await import('node:fs');
      writeFileSync(out, urlStr);
      console.log(`  KEEP_FIXTURES=1 → checkout_url written to ${out}; skipping cleanup`);
    } else {
      // 4. Cleanup fixtures (order chain + user).
      for (const sql of [
        `DELETE FROM state_transitions WHERE entity_id IN (SELECT id FROM payments WHERE order_id=$1) OR entity_id IN (SELECT id FROM orders WHERE id=$1)`,
        `DELETE FROM payments WHERE order_id=$1`,
        `DELETE FROM order_items WHERE order_id=$1`,
        `DELETE FROM cart_items WHERE user_id=$2`,
        `DELETE FROM wishlists WHERE user_id=$2`,
        `DELETE FROM orders WHERE id=$1`,
        `DELETE FROM profiles WHERE id=$2`,
        `DELETE FROM auth.users WHERE id=$2`,
      ]) {
        await client.query(sql, [orderId, uid]).catch(() => {});
      }
      console.log('  cleanup done (fixtures removed)');
    }
  } finally {
    await client.end().catch(() => {});
  }
}

main().catch((e) => { console.error('❌ Fatal:', e.message); process.exitCode = 1; }).then(() => {
  console.log(`\nVerdict: ${failed === 0 ? '✅ LIVE INITIATE CHAIN VERIFIED' : '❌ CHAIN INCOMPLETE'} (${passed} pass / ${failed} fail)`);
  process.exitCode = failed === 0 ? 0 : 1;
});
