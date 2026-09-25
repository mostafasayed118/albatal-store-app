// ============================================================
// Unit tests for _shared/rate_limit.ts
//
// Pure-function tests with a fake RPC surface (no network, no DB):
// budget enforcement, bucket namespacing, X-Forwarded-For parsing,
// and the fail-open contract on RPC errors.
//
// Run: deno test supabase/functions/_shared/rate_limit_test.ts
// ============================================================

import { assert, assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  bucket,
  clientIp,
  enforceRateLimit,
  type RateLimitRpc,
} from "./rate_limit.ts";

function reqWithIp(ip: string | null): Request {
  const headers = new Headers();
  if (ip) headers.set("x-forwarded-for", `${ip}, 10.0.0.1`);
  return new Request("https://example.com/function", { headers });
}

Deno.test("bucket namespaces kind and id", () => {
  assertEquals(bucket("proof:user", "abc"), "proof:user:abc");
});

Deno.test("rate-limit SQL accepts IPv4 callback buckets", async () => {
  const migration = await Deno.readTextFile(
    new URL("../../migrations/070_payment_review_rate_limit_hardening.sql", import.meta.url),
  );
  assert(migration.includes("[A-Za-z0-9:._-]+"));
});

Deno.test("clientIp takes the first forwarded hop, unknown when absent", () => {
  assertEquals(clientIp(reqWithIp("203.0.113.7")), "203.0.113.7");
  assertEquals(clientIp(reqWithIp(null)), "unknown");
  const spoofed = new Request("https://example.com/function", {
    headers: { "x-forwarded-for": "not-an-ip" },
  });
  assertEquals(clientIp(spoofed), "unknown");
});

Deno.test("enforceRateLimit allows while budget lasts, 429 when spent", async () => {
  let takes = 0;
  const rpc: RateLimitRpc = (_fn, args) => {
    takes++;
    const limit = (args as { p_limit: number }).p_limit;
    return Promise.resolve({ data: takes <= limit, error: null });
  };
  const opts = { id: "u1", kind: "proof:user", limit: 2, windowSeconds: 3600 };
  assertEquals(await enforceRateLimit(reqWithIp(null), rpc, opts), null);
  assertEquals(await enforceRateLimit(reqWithIp(null), rpc, opts), null);
  const blocked = await enforceRateLimit(reqWithIp(null), rpc, opts);
  assertEquals(blocked?.status, 429);
  assertEquals(takes, 3);
});

Deno.test("enforceRateLimit fails open on RPC error payloads", async () => {
  const rpc: RateLimitRpc = () =>
    Promise.resolve({ data: null, error: { message: "db down" } });
  const res = await enforceRateLimit(
    reqWithIp(null),
    rpc,
    { id: "u2", kind: "proof:user", limit: 1, windowSeconds: 60 },
  );
  assertEquals(res, null);
});

Deno.test("enforceRateLimit fails open when the client throws", async () => {
  const rpc: RateLimitRpc = () => Promise.reject(new Error("network"));
  const res = await enforceRateLimit(
    reqWithIp(null),
    rpc,
    { id: "u3", kind: "cb:ip", limit: 1, windowSeconds: 60 },
  );
  assertEquals(res, null);
});

Deno.test("enforceRateLimit treats a non-true payload as exhausted", async () => {
  const rpc: RateLimitRpc = () =>
    Promise.resolve({ data: "nope", error: null });
  const res = await enforceRateLimit(
    reqWithIp(null),
    rpc,
    { id: "u4", kind: "init:user", limit: 5, windowSeconds: 60 },
  );
  assertEquals(res?.status, 429);
});
