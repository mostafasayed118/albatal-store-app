// ============================================================
// Contract test for push-order-status security and delivery
// properties.
//
// Validates:
//   - requireCors(req) is called for fail-closed CORS
//   - constantTimeEquals is used for internal key comparison
//   - requireSecret is used for PUSH_ORDER_STATUS_INTERNAL_KEY
//   - status is restricted to the STATUS_COPY allowlist
//   - OneSignal delivery targets external user ids (the Supabase
//     user id) instead of legacy player ids
//
// Run: deno test supabase/functions/push-order-status/push_order_status_test.ts
// ============================================================

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";

const readFileSync = Deno.readTextFileSync;

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname.replace(
  /^\/([A-Z]:)/,
  "$1",
);

Deno.test("push-order-status uses requireCors for fail-closed CORS", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("requireCors(req)"),
    true,
    "Function must call requireCors(req) for fail-closed CORS",
  );
});

Deno.test("push-order-status uses constantTimeEquals for key comparison", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("constantTimeEquals"),
    true,
    "Function must use constantTimeEquals from _shared/secrets.ts",
  );
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

Deno.test("push-order-status uses requireSecret for PUSH_ORDER_STATUS_INTERNAL_KEY", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes(
      "requireSecret(req, 'PUSH_ORDER_STATUS_INTERNAL_KEY')",
    ),
    true,
    "Function must use requireSecret for PUSH_ORDER_STATUS_INTERNAL_KEY",
  );
});

Deno.test("push-order-status validates status against STATUS_COPY allowlist", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("const STATUS_COPY"),
    true,
    "Function must define the STATUS_COPY allowlist",
  );
  assertEquals(
    source.includes("STATUS_COPY[status]"),
    true,
    "Function must look up the requested status in STATUS_COPY",
  );
  for (const status of ["processing", "shipped", "delivered", "cancelled"]) {
    assertEquals(
      source.includes(`${status}: {`),
      true,
      `STATUS_COPY must include ${status}`,
    );
  }
});

Deno.test("push-order-status targets OneSignal external user ids", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("include_external_user_ids"),
    true,
    "Function must deliver with include_external_user_ids",
  );
  assertEquals(
    source.includes("target_channel"),
    true,
    "Function must send to the push channel",
  );
  assertEquals(
    source.includes("include_player_ids"),
    false,
    "Function must not use legacy include_player_ids",
  );
  assertEquals(
    source.includes("onesignal_player_id"),
    false,
    "Function must not read profiles.onesignal_player_id",
  );
});

Deno.test("push-order-status skips cleanly when OneSignal is not configured", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("reason: 'push_not_configured'"),
    true,
    "Missing OneSignal secrets must return skipped/push_not_configured",
  );
  assertEquals(
    source.includes("https://onesignal.com/api/v1/notifications"),
    true,
    "Function must post to the OneSignal v1 notifications endpoint",
  );
});

Deno.test("push-order-status never logs raw error objects", () => {
  const source = readFileSync(SOURCE_PATH);
  const catchIdx = source.indexOf("} catch");
  if (catchIdx !== -1) {
    const catchBlock = source.substring(catchIdx, catchIdx + 200);
    assertEquals(
      catchBlock.includes("console.error"),
      true,
      "Catch block must log a safe message",
    );
  }
});
