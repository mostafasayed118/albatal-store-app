// ============================================================
// Contract test for instapay-review security properties.
//
// Source-level analysis: verifies the admin gate ordering
// (fail-closed, delete-account pattern), that the transactional
// state flip is delegated to the 041 RPC, and that responses
// never leak internals.
//
// Run: deno test --allow-read supabase/functions/instapay-review/
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

Deno.test("review requires authentication", () => {
  assertIncludes(
    source,
    'req.headers.get("Authorization")',
    "must read the Authorization header",
  );
  assertIncludes(source, "Unauthorized", "bad JWT must be refused");
});

Deno.test("admin gate runs before any privileged work (delete-account pattern)", () => {
  const adminAt = source.indexOf('.from("profiles")');
  const rpcAt = source.indexOf('"review_instapay_proof"');
  const serviceAt = source.indexOf('Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")');
  assert(adminAt >= 0, "must read the caller's profile");
  assert(rpcAt >= 0, "must call the 041 review RPC");
  assert(serviceAt >= 0, "must read the service-role key");
  assert(
    adminAt < rpcAt,
    "admin check must precede the review RPC",
  );
  assert(
    serviceAt < rpcAt,
    "service-role key must be read before the review RPC",
  );
  const adminSection = source.slice(adminAt, rpcAt);
  assertIncludes(
    adminSection,
    "is_admin !== true",
    "non-admin callers must be refused (403)",
  );
  assertIncludes(
    source,
    "SUPABASE_SERVICE_ROLE_KEY",
    "is_admin must be read through the service-role client so RLS cannot hide it",
  );
  const missingSecret = source.indexOf(
    'serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""',
  );
  assert(missingSecret >= 0, "service key read must be null-safe");
  assertIncludes(
    source,
    "Server misconfigured",
    "missing service key must fail closed",
  );
});

Deno.test("state flip is delegated to the atomic RPC — no direct writes", () => {
  assertIncludes(
    source,
    '"review_instapay_proof"',
    "must delegate to the 041 SECURITY DEFINER RPC",
  );
  assertNotIncludes(
    source,
    '.from("payments")',
    "review must never touch payment rows directly",
  );
  assertNotIncludes(
    source,
    '.from("orders")',
    "review must never touch order rows directly",
  );
  assertNotIncludes(
    source,
    ".update(",
    "review must never write rows directly",
  );
  assertIncludes(
    source,
    "p_approve: approve",
    "approve decision must be passed through",
  );
});

Deno.test("errors are generic and codes map to safe statuses", () => {
  assertIncludes(source, "requireCors(req)", "CORS must fail closed");
  assertIncludes(source, "admin_required", "403 path must exist");
  assertIncludes(source, "proof_not_found", "404 path must exist");
  assertIncludes(source, "Internal error", "unexpected errors stay generic");
  assertNotIncludes(
    source,
    "console.error(profile",
    "raw profile rows must never be logged",
  );
});
