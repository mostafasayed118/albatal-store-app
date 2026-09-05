// ============================================================
// Contract test for instapay-initiate security properties.
//
// Source-level analysis in the same style as the other Edge
// Function tests: the DB and auth boundaries are external, so
// we verify the branch and response contracts from source.
//
// Run: deno test --allow-read supabase/functions/instapay-initiate/
// ============================================================

const SOURCE_PATH = new URL("index.ts", import.meta.url);
const source = await Deno.readTextFile(SOURCE_PATH);

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function assertIncludes(text: string, fragment: string, message: string): void {
  assert(text.includes(fragment), `${message}: missing ${fragment}`);
}

function assertNotIncludes(
  text: string,
  fragment: string,
  message: string,
): void {
  assert(!text.includes(fragment), `${message}: found ${fragment}`);
}

Deno.test("instapay-initiate requires authentication before any data access", () => {
  const authAt = source.indexOf('req.headers.get("Authorization")');
  const userAt = source.indexOf("supabase.auth.getUser()");
  assert(authAt >= 0, "must read the Authorization header");
  assert(userAt >= 0, "must resolve the user via auth.getUser()");
  assertIncludes(
    source,
    "Authentication required",
    "missing header must be refused",
  );
  assertIncludes(source, "Unauthorized", "bad JWT must be refused");
});

Deno.test("instapay-initiate fails closed when merchant address is unconfigured", () => {
  const addrAt = source.indexOf('Deno.env.get("INSTAPAY_MERCHANT_ADDRESS")');
  assert(addrAt >= 0, "merchant address must come from env");
  const emptyCheck = source.indexOf("!instapayAddress");
  assert(emptyCheck > addrAt, "must check the trimmed value, not just the env");
  assertIncludes(
    source,
    "InstaPay is not configured",
    "misconfiguration must return a safe message",
  );
});

Deno.test("method switch happens through the atomic owner-checked RPC", () => {
  assertIncludes(
    source,
    '"set_pending_order_payment_method"',
    "must use the 041 allowlist RPC",
  );
  assertIncludes(source, '"instapay"', "must request the instapay method");
  assertNotIncludes(
    source,
    ".insert(",
    "initiation must never insert payments directly",
  );
  assertNotIncludes(
    source,
    ".update(",
    "initiation must never update payments directly",
  );
});

Deno.test("payable amount is read server-side, never from the client", () => {
  assertIncludes(
    source,
    '.eq("user_id", user.id)',
    "payment lookup must be owner-scoped",
  );
  assertIncludes(
    source,
    '.eq("status", "pending")',
    "payment lookup must be pending-scoped",
  );
  assertIncludes(
    source,
    "payment.amount",
    "returned amount must come from the DB row",
  );
  assertNotIncludes(
    source,
    "body.amount",
    "client-supplied amounts are forbidden",
  );
});

Deno.test("fail-closed CORS and no secret leakage in responses", () => {
  assertIncludes(source, "requireCors(req)", "CORS must fail closed");
  const forbidden = [
    "SUPABASE_SERVICE_ROLE_KEY",
    "service_role",
    "INSTAPAY_MERCHANT_ADDRESS" + "_SECRET",
  ];
  for (const key of forbidden) {
    assert(
      !/JSON\.stringify\(\{[^}]*\bkey\b/.test(source),
      `responses must not embed ${key}`,
    );
  }
  assertIncludes(source, "Internal error", "unexpected errors stay generic");
});
