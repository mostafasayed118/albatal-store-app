// ============================================================
// Al Batal Elite — Staging E2E harness (shared library)
// Authorization: STAGING-E2E-E9A6DEB-2026-07-28  (staging only)
//
// Reads staging config from .env.staging in the workspace root.
// NEVER prints secret values. Only redacted status, ids, codes,
// amounts, and state names are emitted.
// ============================================================
import { readFileSync } from "node:fs";
import { createHmac } from "node:crypto";

export function loadEnv(path) {
  const env = {};
  const raw = readFileSync(path, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

export function redact(s) {
  if (!s) return s;
  if (s.length <= 8) return "***";
  return s.slice(0, 3) + "…redacted…" + s.slice(-2);
}

let CFG = null;
export function cfg() {
  if (CFG) return CFG;
  const env = loadEnv("c:/flutter_projects/albatal_store/.env.staging");
  CFG = {
    url: env.SUPABASE_URL,
    anon: env.SUPABASE_ANON_KEY,
    hmacSecret: env.PAYMOB_HMAC_SECRET,
    paymobApiKey: env.PAYMOB_API_KEY,
    paymobIntegrationId: env.PAYMOB_INTEGRATION_ID,
  };
  if (!CFG.url || !CFG.anon) throw new Error("missing SUPABASE_URL/ANON_KEY");
  return CFG;
}

const rnd = (n = 8) =>
  Array.from({ length: n }, () =>
    "abcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(Math.random() * 36)]
  ).join("");

export async function signup() {
  const c = cfg();
  const email = `e2e+${rnd(10)}@albatal-e2e.test`;
  const password = `Test-${rnd(12)}!aA1`;
  const r = await fetch(`${c.url}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: c.anon, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const j = await r.json();
  if (!r.ok || !j.access_token) {
    throw new Error(`signup failed status=${r.status} code=${j.error_code || j.msg || "?"}`);
  }
  return { email, userId: j.user.id, jwt: j.access_token };
}

// Call a PostgREST RPC. If jwt is null the call is anonymous
// (anon apikey only). Returns { status, body }.
export async function rpc(fn, params, jwt) {
  const c = cfg();
  const headers = { apikey: c.anon, "Content-Type": "application/json" };
  if (jwt) headers["Authorization"] = `Bearer ${jwt}`;
  const r = await fetch(`${c.url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers,
    body: JSON.stringify(params || {}),
  });
  let body;
  try { body = await r.json(); } catch { body = await r.text(); }
  return { status: r.status, body };
}

// Authenticated PostgREST select. path e.g. "orders?id=eq.<uuid>&select=*"
export async function restGet(path, jwt) {
  const c = cfg();
  const headers = { apikey: c.anon };
  if (jwt) headers["Authorization"] = `Bearer ${jwt}`;
  const r = await fetch(`${c.url}/rest/v1/${path}`, { headers });
  let body;
  try { body = await r.json(); } catch { body = await r.text(); }
  return { status: r.status, body };
}

export async function variantStock(variantId) {
  const r = await restGet(
    `product_variants?id=eq.${variantId}&select=stock`,
    null,
  );
  return Array.isArray(r.body) && r.body[0] ? r.body[0].stock : null;
}

// Compute a valid Paymob callback HMAC over the 20 canonical
// fields (HMAC-SHA512, hex-lowercase, no separators).
const PAYMOB_HMAC_FIELDS = [
  "amount_cents", "created_at", "currency", "error_occured",
  "has_parent_transaction", "id", "integration_id", "is_3d_secure",
  "is_auth", "is_capture", "is_refunded", "is_standalone_payment",
  "is_voided", "order", "owner", "pending", "source_data_pan",
  "source_data_sub_type", "source_data_type", "success",
];

export function signCallback(values) {
  const c = cfg();
  const payload = PAYMOB_HMAC_FIELDS.map((f) => values[f] ?? "").join("");
  return createHmac("sha512", c.hmacSecret).update(payload).digest("hex");
}

export async function postCallback(values, hmac) {
  const c = cfg();
  const form = new URLSearchParams();
  for (const f of PAYMOB_HMAC_FIELDS) form.set(f, values[f] ?? "");
  form.set("hmac", hmac);
  const r = await fetch(`${c.url}/functions/v1/paymob-callback`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  });
  let body;
  try { body = await r.json(); } catch { body = await r.text(); }
  return { status: r.status, body };
}

export const ADDRESS = { recipient: "E2E Tester", line: "1 Test St", city: "Cairo" };

export function log(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}
