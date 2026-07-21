// ============================================================
// Contract test for paymob-callback security properties.
//
// Tests the pure HMAC functions in isolation (no network, no DB).
// The function exports buildHmacPayload, PAYMOB_HMAC_FIELDS for
// testing — this validates the HMAC verification contract.
//
// Run: deno test supabase/functions/paymob-callback/hmac_test.ts
// ============================================================

import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildHmacPayload,
  computeHmac,
  constantTimeEquals,
  PAYMOB_HMAC_FIELDS,
  verifyHmac,
} from "./hmac.ts";

Deno.test("PAYMOB_HMAC_FIELDS has exactly 20 fields", () => {
  assertEquals(PAYMOB_HMAC_FIELDS.length, 20);
});

Deno.test("PAYMOB_HMAC_FIELDS order is canonical", () => {
  assertEquals(PAYMOB_HMAC_FIELDS[0], "amount_cents");
  assertEquals(PAYMOB_HMAC_FIELDS[5], "id");
  assertEquals(PAYMOB_HMAC_FIELDS[13], "order");
  assertEquals(PAYMOB_HMAC_FIELDS[19], "success");
});

Deno.test("buildHmacPayload concatenates values in order", () => {
  const values: Record<string, string> = {};
  for (const field of PAYMOB_HMAC_FIELDS) {
    values[field] = field; // Use field name as value for easy verification
  }
  const payload = buildHmacPayload(values);
  // Should be all field names concatenated with no separators
  assertEquals(payload, PAYMOB_HMAC_FIELDS.join(""));
});

Deno.test("buildHmacPayload treats missing fields as empty string", () => {
  const values: Record<string, string> = {};
  const payload = buildHmacPayload(values);
  // All 20 fields are missing → 20 empty strings → empty string
  assertEquals(payload, "");
});

Deno.test("computeHmac produces deterministic output", async () => {
  const values = { amount_cents: "1000", success: "true" };
  const secret = "test-secret";
  const h1 = await computeHmac(values, secret);
  const h2 = await computeHmac(values, secret);
  assertEquals(h1, h2);
  // HMAC-SHA512 hex digest is 128 characters
  assertEquals(h1.length, 128);
});

Deno.test("computeHmac changes with different secrets", async () => {
  const values = { amount_cents: "1000" };
  const h1 = await computeHmac(values, "secret-1");
  const h2 = await computeHmac(values, "secret-2");
  assertNotEquals(h1, h2);
});

Deno.test("computeHmac changes with different values", async () => {
  const secret = "test-secret";
  const h1 = await computeHmac({ amount_cents: "1000" }, secret);
  const h2 = await computeHmac({ amount_cents: "2000" }, secret);
  assertNotEquals(h1, h2);
});

Deno.test("constantTimeEquals returns true for equal strings", () => {
  assertEquals(constantTimeEquals("abc", "abc"), true);
  assertEquals(constantTimeEquals("ABC", "abc"), true); // case-insensitive
});

Deno.test("constantTimeEquals returns false for different strings", () => {
  assertEquals(constantTimeEquals("abc", "abd"), false);
  assertEquals(constantTimeEquals("abc", "ab"), false);
  assertEquals(constantTimeEquals("abc", "abcd"), false);
});

Deno.test("verifyHmac accepts a valid signature", async () => {
  const values: Record<string, string> = {};
  for (const field of PAYMOB_HMAC_FIELDS) {
    values[field] = "test-value";
  }
  const secret = "valid-secret";
  const hmac = await computeHmac(values, secret);
  const ok = await verifyHmac(values, secret, hmac);
  assertEquals(ok, true);
});

Deno.test("verifyHmac rejects an invalid signature", async () => {
  const values: Record<string, string> = {};
  for (const field of PAYMOB_HMAC_FIELDS) {
    values[field] = "test-value";
  }
  const ok = await verifyHmac(values, "valid-secret", "invalid-hmac-value");
  assertEquals(ok, false);
});

Deno.test("verifyHmac rejects wrong secret", async () => {
  const values: Record<string, string> = {};
  for (const field of PAYMOB_HMAC_FIELDS) {
    values[field] = "test-value";
  }
  const hmac = await computeHmac(values, "correct-secret");
  const ok = await verifyHmac(values, "wrong-secret", hmac);
  assertEquals(ok, false);
});
