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

const readFileSync = Deno.readTextFileSync;

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

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

  // Find Response constructor calls with JSON.stringify in error responses
  // (new Response(JSON.stringify({...}), {status: 4xx/5xx}))
  const responsePattern = /new Response\(\s*JSON\.stringify\(\{[^}]*\}\)/g;
  let match;
  const violations: string[] = [];

  while ((match = responsePattern.exec(source)) !== null) {
    const body = match[0];

    // Check if this is an error response (4xx/5xx within 200 chars)
    const afterMatch = source.substring(match.index, match.index + 200);
    const is4xx = /status:\s*4\d{2}/.test(afterMatch);
    const is5xx = /status:\s*5\d{2}/.test(afterMatch);
    if (!is4xx && !is5xx) continue;

    // Check for forbidden keys in error response bodies
    for (const key of FORBIDDEN_KEYS) {
      const keyRegex = new RegExp(`["']?${key}["']?\\s*:`, "i");
      if (keyRegex.test(body)) {
        violations.push(key);
      }
    }
  }

  assertEquals(
    violations.length,
    0,
    `Error response bodies contain forbidden keys: ${violations.join(", ")}`,
  );
});

Deno.test("paymob-initiate never logs raw error objects", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // The catch block should log a safe prefix, not the raw error.
  const catchIdx = source.indexOf("catch");
  if (catchIdx !== -1) {
    const catchBlock = source.substring(catchIdx, catchIdx + 300);
    assertEquals(
      catchBlock.includes("console.error"),
      true,
      "Catch block must log a safe message",
    );
    // Must not log the error variable itself
    assertEquals(
      /console\.error\([^)]*\berror\s*\)/.test(catchBlock),
      false,
      "Catch block must not log raw error object — use safe prefix only",
    );
  }
});

Deno.test("paymob-initiate response contract is documented", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // The header comment should document the return type.
  // Match patterns like "// Returns:\n//   - { checkout_url }" or "//   - checkout_url"
  assertExists(
    source.match(/Returns:[\s\S]*?checkout_url/),
    "Header comment must document that the function returns { checkout_url }",
  );
});

Deno.test("paymob-initiate uses requireCors for fail-closed CORS", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes("requireCors(req)"),
    true,
    "Function must call requireCors(req) for fail-closed CORS",
  );
});

Deno.test("paymob-initiate uses requireSecret for PAYMOB_API_KEY", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes('requireSecret(req, "PAYMOB_API_KEY")'),
    true,
    "Function must use requireSecret for PAYMOB_API_KEY",
  );
});

Deno.test("paymob-initiate uses corsHeadersFor(req) not legacy corsHeaders", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes("corsHeadersFor"),
    true,
    "Function must import corsHeadersFor",
  );
  assertEquals(
    source.includes("{ ...corsHeaders,"),
    false,
    "Function must not use legacy { ...corsHeaders } spread pattern",
  );
});

Deno.test("paymob-initiate uses jsonHeadersFor(req) not legacy jsonHeaders()", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes("jsonHeadersFor(req)"),
    true,
    "Function must use jsonHeadersFor(req)",
  );
  assertEquals(
    source.includes("jsonHeaders()"),
    false,
    "Function must not use legacy jsonHeaders()",
  );
});
