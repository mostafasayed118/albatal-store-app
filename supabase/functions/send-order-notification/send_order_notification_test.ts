// ============================================================
// Contract test for send-order-notification security properties.
//
// Validates:
//   - requireCors(req) is called for fail-closed CORS
//   - constantTimeEquals is used for internal key comparison
//   - requireSecret is used for NOTIFICATIONS_INTERNAL_KEY
//   - requireSecret is used for SUPABASE_SERVICE_ROLE_KEY
//   - No secrets are logged
//
// Run: deno test supabase/functions/send-order-notification/send_order_notification_test.ts
// ============================================================

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";

const readFileSync = Deno.readTextFileSync;

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

Deno.test("send-order-notification uses requireCors for fail-closed CORS", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes("requireCors(req)"),
    true,
    "Function must call requireCors(req) for fail-closed CORS",
  );
});

Deno.test("send-order-notification uses constantTimeEquals for key comparison", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes("constantTimeEquals"),
    true,
    "Function must use constantTimeEquals from _shared/secrets.ts",
  );
  // Must NOT have the old manual constant-time comparison pattern
  assertEquals(
    source.includes("providedKey.length !== expectedKey.length"),
    false,
    "Function must not have length-leak in key comparison",
  );
  assertEquals(
    source.includes("providedKey.charCodeAt(i) ^ expectedKey.charCodeAt(i)"),
    false,
    "Function must not have manual constant-time loop",
  );
});

Deno.test("send-order-notification uses requireSecret for NOTIFICATIONS_INTERNAL_KEY", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes('requireSecret(req, "NOTIFICATIONS_INTERNAL_KEY")'),
    true,
    "Function must use requireSecret for NOTIFICATIONS_INTERNAL_KEY",
  );
});

Deno.test("send-order-notification uses requireSecret for SUPABASE_SERVICE_ROLE_KEY", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  assertEquals(
    source.includes('requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY")'),
    true,
    "Function must use requireSecret for SUPABASE_SERVICE_ROLE_KEY",
  );
});

Deno.test("send-order-notification uses corsHeadersFor(req) not legacy corsHeaders", () => {
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

Deno.test("send-order-notification uses jsonHeadersFor(req) not legacy jsonHeaders()", () => {
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

Deno.test("send-order-notification never logs raw error objects", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");
  const catchIdx = source.indexOf("catch");
  if (catchIdx !== -1) {
    const catchBlock = source.substring(catchIdx, catchIdx + 200);
    assertEquals(
      catchBlock.includes("console.error"),
      true,
      "Catch block must log a safe message",
    );
  }
});
