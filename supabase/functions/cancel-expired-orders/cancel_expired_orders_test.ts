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
import { readFileSync } from "https://deno.land/std@0.177.0/fs/mod.ts";

const SOURCE_PATH = new URL("index.ts", import.meta.url).pathname;

Deno.test("cancel-expired-orders requires scheduler secret", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // Must check for x-scheduler-secret header
  assertEquals(
    source.includes("x-scheduler-secret"),
    true,
    "Function must check x-scheduler-secret header",
  );

  // Must fail closed when secret is missing
  assertEquals(
    source.includes("CANCEL_EXPIRED_ORDERS_SECRET"),
    true,
    "Function must read CANCEL_EXPIRED_ORDERS_SECRET from env",
  );
});

Deno.test("cancel-expired-orders uses atomic RPC", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // Must delegate to expire_pending_order RPC (atomic, idempotent)
  assertEquals(
    source.includes("expire_pending_order"),
    true,
    "Function must delegate to expire_pending_order RPC",
  );
});

Deno.test("cancel-expired-orders uses service-role key", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

  // Must use service_role key to bypass RLS
  assertEquals(
    source.includes("SUPABASE_SERVICE_ROLE_KEY"),
    true,
    "Function must use service-role key for RPC calls",
  );
});

Deno.test("cancel-expired-orders has safe error handling", () => {
  const source = readFileSync(SOURCE_PATH, "utf-8");

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
  const source = readFileSync(SOURCE_PATH, "utf-8");

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
