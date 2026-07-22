// ============================================================
// Contract + unit tests for cancel-expired-orders security.
//
// Run:
//   deno test supabase/functions/cancel-expired-orders/cancel_expired_orders_test.ts
// ============================================================

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { secretsMatch } from "./secrets.ts";

const SOURCE_PATH = new URL("index.ts", import.meta.url);

async function readSource(): Promise<string> {
  return await Deno.readTextFile(SOURCE_PATH);
}

Deno.test("secretsMatch: equal secrets return true", async () => {
  assertEquals(
    await secretsMatch("scheduler-secret-value", "scheduler-secret-value"),
    true,
  );
});

Deno.test("secretsMatch: unequal secrets return false", async () => {
  assertEquals(
    await secretsMatch("scheduler-secret-value", "wrong-secret"),
    false,
  );
});

Deno.test("secretsMatch: null provided returns false", async () => {
  assertEquals(await secretsMatch("scheduler-secret-value", null), false);
});

Deno.test("secretsMatch: empty expected returns false (fail closed)", async () => {
  assertEquals(await secretsMatch("", "anything"), false);
  assertEquals(await secretsMatch("   ", "anything"), false);
});

Deno.test("secretsMatch: empty provided against non-empty expected is false", async () => {
  assertEquals(await secretsMatch("scheduler-secret-value", ""), false);
});

Deno.test("secretsMatch: length-mismatched strings still compare via digest (false)", async () => {
  assertEquals(
    await secretsMatch("short", "much-longer-secret-value"),
    false,
  );
});

Deno.test("cancel-expired-orders requires scheduler secret env", async () => {
  const source = await readSource();
  assert(source.includes("x-scheduler-secret"));
  assert(source.includes("CANCEL_EXPIRED_ORDERS_SECRET"));
});

Deno.test("cancel-expired-orders fails closed when secret missing (503 path)", async () => {
  const source = await readSource();
  assert(source.includes("Scheduler configuration unavailable"));
  assert(/status:\s*503/.test(source));
});

Deno.test("cancel-expired-orders does not use raw !== for secret compare", async () => {
  const source = await readSource();
  assert(source.includes("secretsMatch"));
  assertEquals(
    /receivedSecret\s*!==\s*schedulerSecret/.test(source),
    false,
    "Must not use !== between raw secret strings",
  );
});

Deno.test("cancel-expired-orders uses atomic RPC", async () => {
  const source = await readSource();
  assert(source.includes("expire_pending_order"));
});

Deno.test("cancel-expired-orders uses service-role key", async () => {
  const source = await readSource();
  assert(source.includes("SUPABASE_SERVICE_ROLE_KEY"));
});

Deno.test("cancel-expired-orders response never leaks secrets", async () => {
  const source = await readSource();
  const stringifyPattern = /JSON\.stringify\(\{([^}]+)\}\)/g;
  let match;
  const violations: string[] = [];

  while ((match = stringifyPattern.exec(source)) !== null) {
    const body = match[1];
    const afterMatch = source.substring(match.index, match.index + 300);
    if (!/status:\s*200/.test(afterMatch)) continue;

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
