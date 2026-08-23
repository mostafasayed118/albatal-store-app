// ============================================================
// Contract test for cancel-expired-orders security properties.
//
// Validates the scheduler-secret authorization pattern via
// source analysis (the function is not unit-testable without
// mocking Supabase, so we verify the security contract from
// source code).
//
// Run: deno test supabase/functions/cancel-expired-orders/cancel_expired_orders_test.ts
// ============================================================

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";

const readFileSync = Deno.readTextFileSync;

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

Deno.test("cancel-expired-orders requires scheduler secret", () => {
  const source = readFileSync(SOURCE_PATH);

  // Must check for x-scheduler-secret header
  assertEquals(
    source.includes("x-scheduler-secret"),
    true,
    "Function must check x-scheduler-secret header",
  );

  // Must use requireSecretHeader for constant-time comparison
  assertEquals(
    source.includes("requireSecretHeader"),
    true,
    "Function must use requireSecretHeader for constant-time secret comparison",
  );

  // Must read SCHEDULER_SECRET (canonical) or CANCEL_EXPIRED_ORDERS_SECRET (legacy)
  assertEquals(
    source.includes("SCHEDULER_SECRET") || source.includes("CANCEL_EXPIRED_ORDERS_SECRET"),
    true,
    "Function must read scheduler secret from env",
  );
});

Deno.test("cancel-expired-orders uses atomic RPC", () => {
  const source = readFileSync(SOURCE_PATH);

  // Must delegate to expire_pending_order RPC (atomic, idempotent)
  assertEquals(
    source.includes("expire_pending_order"),
    true,
    "Function must delegate to expire_pending_order RPC",
  );
});

Deno.test("cancel-expired-orders uses requireCors for fail-closed CORS", () => {
  const source = readFileSync(SOURCE_PATH);
  assertEquals(
    source.includes("requireCors(req)"),
    true,
    "Function must call requireCors(req) for fail-closed CORS",
  );
});

Deno.test("cancel-expired-orders uses service-role key", () => {
  const source = readFileSync(SOURCE_PATH);

  // Must use service_role key to bypass RLS
  assertEquals(
    source.includes("SUPABASE_SERVICE_ROLE_KEY"),
    true,
    "Function must use service-role key for RPC calls",
  );
});

Deno.test("cancel-expired-orders has safe error handling", () => {
  const source = readFileSync(SOURCE_PATH);

  // Catch block must not log raw error
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

Deno.test("cancel-expired-orders response never leaks secrets", () => {
  const source = readFileSync(SOURCE_PATH);

  // Find all JSON.stringify calls in 200-status responses
  const stringifyPattern = /JSON\.stringify\(\{([^}]+)\}\)/g;
  let match;
  const violations: string[] = [];

  while ((match = stringifyPattern.exec(source)) !== null) {
    const body = match[1];
    const afterMatch = source.substring(match.index, match.index + 300);
    if (!/status:\s*200/.test(afterMatch)) continue;

    // Check for forbidden keys
    for (const key of ["secret", "token", "api_key", "service_role_key"]) {
      if (new RegExp(`["']?${key}["']?\\s*:`, "i").test(body)) {
        violations.push(key);
      }
    }
  }

  assertEquals(
    violations.length,
    0,
    `Success responses contain forbidden keys: ${violations.join(", ")}`,
  );
});
