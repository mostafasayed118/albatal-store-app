// ============================================================
// Unit tests for the Paymob HMAC verification module.
//
// Run with:
//   deno test --allow-net supabase/functions/paymob-callback/hmac_test.ts
//
// These tests exercise the pure HMAC functions — no network,
// no DB, no live Paymob credentials. They prove:
//   * the canonical field list and order matches the
//     documented Paymob callback HMAC,
//   * a modified field changes the digest,
//   * constant-time comparison rejects mismatches without
//     short-circuiting,
//   * a valid HMAC verifies,
//   * an invalid HMAC does not verify,
//   * the payload builder uses the documented 20-field order.
// ============================================================

import {
  assert,
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  PAYMOB_HMAC_FIELDS,
  buildHmacPayload,
  computeHmac,
  constantTimeEquals,
  verifyHmac,
} from "./hmac.ts";

// ─── Documented canonical field order ───────────────────
// This is the exact list and order from Paymob's standard
// redirect callback HMAC documentation. If this test fails,
// the field list/order in hmac.ts drifted from the spec.
Deno.test("PAYMOB_HMAC_FIELDS matches documented order", () => {
  assertEquals(PAYMOB_HMAC_FIELDS, [
    "amount_cents",
    "created_at",
    "currency",
    "error_occured",
    "has_parent_transaction",
    "id",
    "integration_id",
    "is_3d_secure",
    "is_auth",
    "is_capture",
    "is_refunded",
    "is_standalone_payment",
    "is_voided",
    "order",
    "owner",
    "pending",
    "source_data_pan",
    "source_data_sub_type",
    "source_data_type",
    "success",
  ]);
  assertEquals(PAYMOB_HMAC_FIELDS.length, 20);
});

// ─── Canonical payload: values concatenated, no separators
Deno.test("buildHmacPayload concatenates values in order with no separators", () => {
  const values: Record<string, string> = {
    amount_cents: "5000",
    created_at: "2026-07-20T10:00:00Z",
    currency: "EGP",
    error_occured: "false",
    has_parent_transaction: "false",
    id: "123456",
    integration_id: "5783474",
    is_3d_secure: "false",
    is_auth: "false",
    is_capture: "false",
    is_refunded: "false",
    is_standalone_payment: "false",
    is_voided: "false",
    order: "987654",
    owner: "user-uuid",
    pending: "false",
    source_data_pan: "4234",
    source_data_sub_type: "Mastercard",
    source_data_type: "card",
    success: "true",
  };
  const payload = buildHmacPayload(values);
  assertEquals(
    payload,
    "50002026-07-20T10:00:00ZEGPfalsefalse1234565783474falsefalsefalsefalsefalsefalse987654user-uuidfalse4234Mastercardcardtrue",
  );
});

// ─── Missing fields are treated as empty string ─────────
Deno.test("buildHmacPayload treats missing fields as empty string", () => {
  const payload = buildHmacPayload({ order: "42", success: "true" });
  // Every field except `order` and `success` is "".
  assertEquals(payload, "42true");
});

// ─── A modified field changes the digest ────────────────
Deno.test("a modified callback field produces a different digest", async () => {
  const base: Record<string, string> = {
    amount_cents: "5000",
    created_at: "2026-07-20",
    currency: "EGP",
    error_occured: "false",
    has_parent_transaction: "false",
    id: "123456",
    integration_id: "5783474",
    is_3d_secure: "false",
    is_auth: "false",
    is_capture: "false",
    is_refunded: "false",
    is_standalone_payment: "false",
    is_voided: "false",
    order: "987654",
    owner: "owner-1",
    pending: "false",
    source_data_pan: "4234",
    source_data_sub_type: "Mastercard",
    source_data_type: "card",
    success: "true",
  };
  const secret = "test-secret-key";
  const digestBase = await computeHmac(base, secret);

  // Tamper with the amount — the digest MUST change.
  const tampered = { ...base, amount_cents: "1" };
  const digestTampered = await computeHmac(tampered, secret);
  assertNotEquals(digestBase, digestTampered);

  // Tamper with success.
  const tamperedSuccess = { ...base, success: "false" };
  const digestTamperedSuccess = await computeHmac(tamperedSuccess, secret);
  assertNotEquals(digestBase, digestTamperedSuccess);

  // Tamper with order id.
  const tamperedOrder = { ...base, order: "999999" };
  const digestTamperedOrder = await computeHmac(tamperedOrder, secret);
  assertNotEquals(digestBase, digestTamperedOrder);
});

// ─── Valid HMAC verifies ────────────────────────────────
Deno.test("verifyHmac returns true for a matching digest", async () => {
  const values: Record<string, string> = {
    amount_cents: "5000",
    created_at: "2026-07-20",
    currency: "EGP",
    error_occured: "false",
    has_parent_transaction: "false",
    id: "123456",
    integration_id: "5783474",
    is_3d_secure: "false",
    is_auth: "false",
    is_capture: "false",
    is_refunded: "false",
    is_standalone_payment: "false",
    is_voided: "false",
    order: "987654",
    owner: "owner-1",
    pending: "false",
    source_data_pan: "4234",
    source_data_sub_type: "Mastercard",
    source_data_type: "card",
    success: "true",
  };
  const secret = "test-secret-key";
  const digest = await computeHmac(values, secret);
  const ok = await verifyHmac(values, secret, digest);
  assert(ok, "a valid HMAC should verify");
});

// ─── Invalid HMAC does not verify ───────────────────────
Deno.test("verifyHmac returns false for a wrong digest", async () => {
  const values: Record<string, string> = { order: "1", success: "true" };
  const ok = await verifyHmac(values, "secret", "deadbeef");
  assert(!ok, "a wrong digest should not verify");
});

// ─── Different secret produces a different digest ───────
Deno.test("a different secret produces a different digest", async () => {
  const values: Record<string, string> = { order: "1", success: "true" };
  const d1 = await computeHmac(values, "secret-a");
  const d2 = await computeHmac(values, "secret-b");
  assertNotEquals(d1, d2);
});

// ─── constantTimeEquals ─────────────────────────────────
Deno.test("constantTimeEquals: equal strings return true", () => {
  assert(constantTimeEquals("abc123", "abc123"));
});

Deno.test("constantTimeEquals: different strings return false", () => {
  assert(!constantTimeEquals("abc123", "abc124"));
});

Deno.test("constantTimeEquals: different lengths return false", () => {
  assert(!constantTimeEquals("abc", "abcd"));
  assert(!constantTimeEquals("abcd", "abc"));
});

Deno.test("constantTimeEquals: case-insensitive for hex", () => {
  assert(constantTimeEquals("ABCDEF", "abcdef"));
});
