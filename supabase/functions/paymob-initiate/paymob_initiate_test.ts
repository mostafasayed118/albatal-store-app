// ============================================================
// Contract test for paymob-initiate response shape.
//
// SECURITY (CRIT-01): This test locks the response contract so
// that a future regression cannot leak Paymob tokens, auth
// tokens, API keys, or raw upstream fields in the success path.
//
// Strategy: static source analysis. We parse the function source
// and assert that every success-path JSON.stringify call contains
// ONLY the approved keys (`checkout_url`, `message`). This is
// cheaper and more reliable than mocking the full Paymob API
// pipeline, and it catches regressions at CI time.
//
// Run: deno test supabase/functions/paymob-initiate/paymob_initiate_test.ts
// ============================================================

import { assertEquals, assertExists } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { readFileSync } from "https://deno.land/std@0.177.0/fs/mod.ts";

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname;

// Keys that must NEVER appear in a success response body.
const FORBIDDEN_KEYS = [
  "token",
  "auth_token",
  "api_key",
  "Authorization",
  "authorization",
  "paymob_order_id",
  "transaction_id",
  "id",
  "status",
  "amount_cents",
  "currency",
  "integration_id",
];

// Approved keys for success responses.
const APPROVED_SUCCESS_KEYS = ["checkout_url"];
// Approved keys for error responses.
const APPROVED_ERROR_KEYS = ["message"];

Deno.test("paymob-initiate success response leaks no secrets", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // Find all JSON.stringify calls that appear in 200-status responses.
  // Pattern: JSON.stringify({ ... }) followed (within ~200 chars) by status: 200
  const stringifyPattern = /JSON\.stringify\(\{([^}]+)\}\)/g;
  let match;
  const violations: string[] = [];

  while ((match = stringifyPattern.exec(source)) !== null) {
    const body = match[1];

    // Check if this is a success response (status: 200 nearby)
    const afterMatch = source.substring(match.index, match.index + 300);
    const is200 = /status:\s*200/.test(afterMatch);
    const is4xx = /status:\s*4\d{2}/.test(afterMatch);
    const is5xx = /status:\s*5\d{2}/.test(afterMatch);

    if (!is200) continue; // Only audit success responses

    // Extract all keys from the response body
    const keyPattern = /(\w+)\s*:/g;
    let keyMatch;
    while ((keyMatch = keyPattern.exec(body)) !== null) {
      const key = keyMatch[1];
      if (!APPROVED_SUCCESS_KEYS.includes(key)) {
        violations.push(key);
      }
    }
  }

  assertEquals(
    violations.length,
    0,
    `Success response contains forbidden keys: ${violations.join(", ")}`,
  );
});

Deno.test("paymob-initiate error responses never leak tokens", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // Find all JSON.stringify({ message: ... }) patterns
  const stringifyPattern = /JSON\.stringify\(\{[^}]*\}\)/g;
  let match;
  const violations: string[] = [];

  while ((match = stringifyPattern.exec(source)) !== null) {
    const body = match[0];

    // Check for forbidden keys in any response
    for (const key of FORBIDDEN_KEYS) {
      // Check if the key appears as a property in the response
      const keyRegex = new RegExp(`["']?${key}["']?\\s*:`, "i");
      if (keyRegex.test(body)) {
        violations.push(key);
      }
    }
  }

  assertEquals(
    violations.length,
    0,
    `Response bodies contain forbidden keys: ${violations.join(", ")}`,
  );
});

Deno.test("paymob-initiate never logs raw error objects", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // The catch block should log a safe prefix, not the raw error.
  // Assert no console.error with variable interpolation of error.
  const catchBlock = source.substring(source.indexOf("catch"));
  const hasRawErrorLog = /console\.error\(.*\berror\b/.test(catchBlock);
  assertEquals(
    hasRawErrorLog,
    false,
    "Catch block must not log raw error object — use safe prefix only",
  );
});

Deno.test("paymob-initiate response contract is documented", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // The header comment should document the return type.
  assertExists(
    source.match(/Returns:\s*\n\s*-\s*\{\s*checkout_url\s*\}/),
    "Header comment must document that the function returns { checkout_url }",
  );
});
