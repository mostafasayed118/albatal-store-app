// ============================================================
// Contract test for paymob-callback security properties.
//
// Validates:
//   - requireSecret is used for PAYMOB_HMAC_SECRET
//   - requireSecret is used for SUPABASE_SERVICE_ROLE_KEY
//   - corsHeadersFor(req) is used (no legacy corsHeaders)
//   - HMAC verification is constant-time (via verifyHmac)
//   - No secrets are logged
//
// Run: deno test supabase/functions/paymob-callback/paymob_callback_test.ts
// ============================================================

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";

const readFileSync = Deno.readTextFileSync;

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

Deno.test("paymob-callback uses requireSecret for PAYMOB_HMAC_SECRET", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes('requireSecret(req, "PAYMOB_HMAC_SECRET")'),
    true,
    "Function must use requireSecret for PAYMOB_HMAC_SECRET",
  );
});

Deno.test("paymob-callback uses requireSecret for SUPABASE_SERVICE_ROLE_KEY", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes('requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY")'),
    true,
    "Function must use requireSecret for SUPABASE_SERVICE_ROLE_KEY",
  );
});

Deno.test("paymob-callback uses corsHeadersFor(req) not legacy corsHeaders", () => {
  const source = readFileSync(SOURCE_PATH);
  // Should import corsHeadersFor
  assertEquals(
    source.includes("corsHeadersFor"),
    true,
    "Function must import corsHeadersFor",
  );
  // Should NOT use the legacy static corsHeaders pattern
  assertEquals(
    source.includes("{ ...corsHeaders,"),
    false,
    "Function must not use legacy { ...corsHeaders } spread pattern",
  );
});

Deno.test("paymob-callback uses jsonHeadersFor(req) not legacy jsonHeaders()", () => {
  const source = readFileSync(SOURCE_PATH);
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

Deno.test("paymob-callback never logs raw error objects", () => {
  const source = readFileSync(SOURCE_PATH);
  const catchIdx = source.indexOf("catch");
  if (catchIdx !== -1) {
    const catchBlock = source.substring(catchIdx, catchIdx + 300);
    assertEquals(
      catchBlock.includes("console.error"),
      true,
      "Catch block must log a safe message",
    );
    // Must not log the error variable itself (e.g. console.error("...", error))
    assertEquals(
      /console\.error\([^)]*\berror\s*\)/.test(catchBlock),
      false,
      "Catch block must not log raw error object",
    );
  }
});

Deno.test("paymob-callback uses verifyHmac for constant-time comparison", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("verifyHmac"),
    true,
    "Function must use verifyHmac for constant-time HMAC verification",
  );
});
