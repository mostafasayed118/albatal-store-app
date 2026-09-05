#!/usr/bin/env node
// ============================================================
// Static contract verification for migration 034
// (payment initiation + expiry hardening).
//
// This is a SOURCE contract check, not a database check. It
// asserts the migration cannot be edited into an unsafe shape
// without failing CI, and it requires no live database, no
// credentials, and no network access.
//
// Run: node supabase/tests/verify_payment_initiation_contract.mjs
// Exit code 0 = contract satisfied; 1 = violated.
// ============================================================

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const MIGRATION = join(
  HERE,
  "..",
  "migrations",
  "035_payment_initiation_and_expiry_hardening.sql",
);

const failures = [];
const checks = [];

function check(name, condition, detail = "") {
  checks.push({ name, ok: Boolean(condition), detail });
  if (!condition) failures.push(`${name}${detail ? ` — ${detail}` : ""}`);
}

let raw;
try {
  raw = readFileSync(MIGRATION, "utf8");
} catch (error) {
  console.error(
    `FAIL: cannot read ${MIGRATION} (${error.code ?? error.message})`,
  );
  process.exit(1);
}

// ── Normalize ────────────────────────────────────────────────
// Strip line comments and block comments so that commented-out
// SQL cannot satisfy an assertion. Without this, a migration
// could "pass" by merely mentioning the required text.
const sql = raw
  .replace(/\/\*[\s\S]*?\*\//g, " ")
  .replace(/--[^\n]*/g, " ")
  // Collapse whitespace so multi-line statements match single-line regexes.
  .replace(/\s+/g, " ");

// ── Helper: ordered list of locked row reads ─────────────────
// Returns e.g. ["orders", "payments"] in acquisition order. The
// tempered pattern stops each match at the next FROM, so an
// UNLOCKED read (e.g. resolving a payment id before locking the
// order) cannot be mistaken for a lock acquisition.
function lockSequence(statement) {
  const pattern =
    /FROM\s+(orders|payments)(?:(?!FROM\s+(?:orders|payments))[\s\S])*?FOR\s+UPDATE/gi;
  return [...statement.matchAll(pattern)].map((m) => m[1].toLowerCase());
}

// ── Helper: extract a whole CREATE FUNCTION statement ────────
// The full statement is captured (not just the $$ body) because
// SECURITY DEFINER and SET search_path are attribute clauses that
// live in the header. Checking only the body would let a migration
// silently drop them.
function functionStatement(name) {
  const pattern = new RegExp(
    `CREATE\\s+(?:OR\\s+REPLACE\\s+)?FUNCTION\\s+(?:[\\w]+\\.)?${name}\\s*\\([^)]*\\)[\\s\\S]*?\\$\\$[\\s\\S]*?\\$\\$`,
    "i",
  );
  const match = sql.match(pattern);
  return match ? match[0] : null;
}

// ── 1. Unique partial index: one pending card payment per order ──
check(
  "partial unique index on payments(order_id) exists",
  /CREATE\s+UNIQUE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?\w+ \s*ON\s+payments\s*\(\s*order_id\s*\)/i.test(
    sql,
  ),
  "expected CREATE UNIQUE INDEX ... ON payments (order_id)",
);

const partialIndex = sql.match(
  /CREATE\s+UNIQUE\s+INDEX[\s\S]{0,200}?ON\s+payments\s*\(\s*order_id\s*\)\s*WHERE\s*([^;]+)/i,
);
const predicate = partialIndex ? partialIndex[1] : "";
check(
  "unique index predicate restricts to paymob_card + pending",
  /method\s*=\s*'paymob_card'/i.test(predicate) &&
    /status\s*=\s*'pending'/i.test(predicate),
  `predicate was: ${predicate || "<missing>"}`,
);

// ── 2. Claim timestamp must be indexed ───────────────────────
check(
  "set_payment_provider_order_id is redefined with compatible contract",
  /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.set_payment_provider_order_id\s*\(\s*p_payment_id\s+UUID\s*,\s*p_paymob_order_id\s+TEXT\s*\)[\s\S]*?RETURNS\s+JSONB/i.test(sql) &&
    /auth\.uid\s*\(\s*\)/i.test(sql) &&
    /code',\s*'not_owner'/i.test(sql) &&
    /code',\s*'not_pending'/i.test(sql) &&
    /code',\s*'already_set'/i.test(sql) &&
    /paymob_initiation_phase\s*=\s*'provider_persisted'/i.test(sql),
  "provider-id persistence must retain its owner/status/result contract and advance phase",
);
check(
  "provider-order claim timestamp is nullable and indexed",
  /ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+paymob_initiation_claimed_at\s+TIMESTAMPTZ/i.test(sql) &&
    /CREATE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?\w+\s+ON\s+payments\s*\(\s*paymob_initiation_claimed_at\s*\)/i.test(sql),
  "claim lease timestamp must be added and indexed",
);
check(
  "claim phase and token are forward-compatible",
  /ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+paymob_initiation_phase\s+TEXT\s+NOT\s+NULL\s+DEFAULT\s+'none'/i.test(sql) &&
    /ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+paymob_initiation_claim_token\s+UUID/i.test(sql),
  "safe pre-provider recovery needs a typed phase and unforgeable token",
);

// ── 3. Duplicate-pending detection must fail loudly ──────────
check(
  "duplicate pending payments raise a migration error",
  /RAISE\s+EXCEPTION/i.test(sql) &&
    /HAVING\s+COUNT\s*\(\s*\*\s*\)\s*>\s*1/i.test(sql),
  "migration must detect duplicate pending rows and RAISE EXCEPTION",
);

// ── 4. Atomic get-or-create/claim RPC ────────────────────────
const claimFn = functionStatement("get_or_claim_paymob_payment");
check("get_or_claim_paymob_payment is defined", claimFn !== null);

if (claimFn) {
  check(
    "claim RPC declares the pre-provider lease interval",
    /v_lease\s+INTERVAL\s*:=\s*INTERVAL\s*'[^']+'/i.test(claimFn),
    "the stale pre-provider claim comparison must use a declared interval",
  );
  check(
    "claim RPC is SECURITY DEFINER",
    /SECURITY\s+DEFINER/i.test(claimFn),
    "must run as SECURITY DEFINER to own the payment row insert",
  );
  check(
    "claim RPC sets search_path",
    /SET\s+search_path\s*=/i.test(claimFn),
    "SECURITY DEFINER without a pinned search_path is a hijack risk",
  );
  check(
    "claim RPC enforces authentication",
    /auth\.uid\s*\(\s*\)/i.test(claimFn),
    "must resolve and verify auth.uid()",
  );
  check(
    "claim RPC verifies order ownership",
    // Ownership may be compared against auth.uid() directly or against a
    // local variable. The latter is required to be bound to auth.uid()
    // so the comparison cannot drift from the real caller identity.
    (() => {
      const direct =
        /user_id\s*(?:<>|!=)\s*auth\.uid\s*\(\s*\)/i.test(claimFn);
      const viaVariable = /user_id\s*(?:<>|!=)\s*v_uid/i.test(claimFn) &&
        /v_uid\s*:=\s*auth\.uid\s*\(\s*\)/i.test(claimFn);
      return direct || viaVariable;
    })(),
    "must reject orders that do not belong to the caller",
  );
  check(
    "claim RPC requires status pending",
    /status\s*<>\s*'pending'|status\s*!=\s*'pending'/i.test(claimFn),
    "must reject orders that are no longer pending",
  );
  check(
    "claim RPC enforces the paymob_card method",
    /payment_method\s*(?:<>|!=)\s*'paymob_card'/i.test(claimFn),
    "must reject non-card orders before any provider call",
  );
  check(
    "claim RPC enforces payment ownership",
    /WHERE\s+order_id\s*=\s*p_order_id[\s\S]*?AND\s+user_id\s*=\s*v_uid/i.test(claimFn),
    "must not reuse a pending payment owned by another user",
  );
  check(
    "claim RPC does not expose an authenticated claim release",
    !/GRANT\s+EXECUTE\s+ON\s+FUNCTION\s+public\.release_paymob_initiation_claim\([^)]*\)\s+TO\s+authenticated/i.test(sql) &&
      /REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.release_paymob_initiation_claim\([^)]*\)\s+FROM\s+authenticated/i.test(sql),
    "authenticated callers must not be able to clear an active provider claim",
  );
  check(
    "claim RPC keeps provider-submitted claims exclusive",
    (() => {
      const submittedAt = claimFn.indexOf(
        "v_payment.paymob_initiation_phase = 'provider_submitted'",
      );
      const preProviderAt = claimFn.indexOf(
        "v_payment.paymob_initiation_phase = 'pre_provider'",
        submittedAt + 1,
      );
      if (submittedAt < 0) return false;
      const submittedSection = claimFn.slice(
        submittedAt,
        preProviderAt > submittedAt ? preProviderAt : claimFn.length,
      );
      return !/now\(\)\s*-\s*v_lease/i.test(submittedSection);
    })(),
    "provider-submitted claims must never be reclaimed by a lease",
  );
  check(
    "claim RPC locks the order before the payment",
    (() => {
      const locks = lockSequence(claimFn);
      return locks.length > 0 && locks[0] === "orders";
    })(),
    `lock order was: [${lockSequence(claimFn).join(", ")}]`,
  );
  check(
    "claim RPC inserts with ON CONFLICT DO NOTHING",
    /ON\s+CONFLICT\s+DO\s+NOTHING/i.test(claimFn),
    "concurrent initiation must not fail or duplicate the payment row",
  );
  check(
    "claim RPC returns an existing provider order when present",
    /paymob_order_id\s+IS\s+NOT\s+NULL/i.test(claimFn),
    "must short-circuit to key reissue instead of creating a second provider order",
  );
  check(
    "claim RPC stores an initiation claim",
    /paymob_initiation_claimed_at/i.test(claimFn) &&
      /SET\s+paymob_initiation_claimed_at\s*=\s*now\(\)/i.test(claimFn),
    "provider-order creation must be claimed under the payment lock",
  );
  check(
    "claim RPC returns an unforgeable claim token",
    /paymob_initiation_claim_token/i.test(claimFn) &&
      /claim_token/i.test(claimFn),
    "Edge Function needs a token-bound phase transition and recovery path",
  );
  check(
    "claim RPC distinguishes pre-provider claims",
    /paymob_initiation_phase\s*=\s*'pre_provider'/i.test(claimFn),
    "pre-provider failures must be safely recoverable",
  );
  check(
    "claim RPC reclaims only stale pre-provider claims",
    /paymob_initiation_phase\s*=\s*'provider_submitted'[\s\S]*?initiation_in_progress/i.test(claimFn) &&
      /paymob_initiation_phase\s*=\s*'pre_provider'[\s\S]*?now\(\)\s*-\s*v_lease/i.test(claimFn),
    "only pre-provider claims may use the bounded lease",
  );
  check(
    "pre-provider release is token-bound and phase-bound",
    /release_paymob_initiation_claim[\s\S]*?p_claim_token\s+UUID/i.test(sql) &&
      /paymob_initiation_phase\s*=\s*'pre_provider'/i.test(sql) &&
      /paymob_initiation_claim_token\s*=\s*p_claim_token/i.test(sql),
    "only the current attempt may release a pre-provider claim",
  );
  check(
    "provider submission transition is token-bound",
    /mark_paymob_initiation_submitted[\s\S]*?p_claim_token\s+UUID/i.test(sql) &&
      /paymob_initiation_phase\s*=\s*'provider_submitted'/i.test(sql),
    "the claim must become non-releasable before provider-order submission",
  );
}

// ── 5. Expiry batch RPC must be service-only ─────────────────
check(
  "batch_expire_pending_orders revoked from authenticated",
  /REVOKE\s+(?:ALL\s+ON\s+FUNCTION|EXECUTE\s+ON\s+FUNCTION)\s+(?:public\.)?batch_expire_pending_orders\s*\(\s*\)\s*FROM\s+(?:[^;]*\bauthenticated\b)/i.test(
    sql,
  ),
  "authenticated users must not be able to trigger global order expiry",
);
check(
  "batch_expire_pending_orders still granted to service_role",
  /GRANT\s+EXECUTE\s+ON\s+FUNCTION\s+(?:public\.)?batch_expire_pending_orders\s*\(\s*\)\s*TO\s+service_role/i.test(
    sql,
  ),
  "pg_cron must retain execution rights",
);

// ── 6. Lock ordering in callback and expiry ──────────────────
for (const fnName of ["process_paymob_callback", "expire_pending_order"]) {
  const body = functionStatement(fnName);
  check(`${fnName} is (re)defined in this migration`, body !== null);
  if (!body) continue;

  const locks = lockSequence(body);

  check(
    `${fnName} locks the order row`,
    locks.includes("orders"),
    "expected a FOR UPDATE on orders",
  );
  check(
    `${fnName} acquires the order lock before any payment lock`,
    locks.length > 0 && locks[0] === "orders",
    `lock order was: [${locks.join(", ")}]`,
  );
  check(
    `${fnName} locks the payment rows it mutates`,
    locks.includes("payments"),
    "expected a FOR UPDATE on payments before reading or writing payment state",
  );
  const rereadSequence =
    /FOR\s+UPDATE[\s\S]*?(?:PERFORM\s+1[\s\S]*?FROM\s+payments[\s\S]*?FOR\s+UPDATE|SELECT[\s\S]*?FROM\s+payments[\s\S]*?FOR\s+UPDATE)[\s\S]*?SELECT[\s\S]*?INTO\s+v_order[\s\S]*?FROM\s+orders[\s\S]*?FOR\s+UPDATE[\s\S]*?SELECT[\s\S]*?INTO\s+v_payment[\s\S]*?FROM\s+payments[\s\S]*?FOR\s+UPDATE/i;
  check(
    `${fnName} explicitly rereads both rows after both locks`,
    rereadSequence.test(body),
    "must reread order and payment after acquiring order then payment locks",
  );
}

// ── 7. RLS / insert policy safety ────────────────────────────
check(
  "migration does not re-open direct client payments INSERT",
  !/CREATE\s+POLICY[\s\S]{0,200}?ON\s+payments\s+FOR\s+INSERT/i.test(sql),
  "direct authenticated INSERT on payments must stay closed",
);

// ── Report ───────────────────────────────────────────────────
const passed = checks.filter((c) => c.ok).length;
for (const c of checks) {
  console.log(`${c.ok ? "PASS" : "FAIL"}  ${c.name}${c.ok ? "" : ` — ${c.detail}`}`);
}
console.log(`\n${passed}/${checks.length} checks passed.`);

if (failures.length > 0) {
  console.error(`\n${failures.length} contract violation(s) detected.`);
  process.exit(1);
}
console.log("Payment initiation contract: OK");
