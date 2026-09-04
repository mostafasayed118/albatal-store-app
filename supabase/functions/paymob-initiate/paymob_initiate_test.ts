// Deterministic contract tests for paymob-initiate.
//
// These tests are intentionally source-level because the Edge Function's
// Supabase client and Paymob calls are external boundaries. They verify the
// branch and response contracts without network access, credentials, or a
// live database. The no-Authorization test exercises the real handler path.
//
// Run:
//   deno test --allow-read supabase/functions/paymob-initiate/paymob_initiate_test.ts

import { decideInitiationClaim, type PaymobClaim } from "./decision.ts";

const SOURCE_PATH = new URL("index.ts", import.meta.url);
const DECISION_PATH = new URL("decision.ts", import.meta.url);
const source = await Deno.readTextFile(SOURCE_PATH);
const decisionSource = await Deno.readTextFile(DECISION_PATH);

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

function section(start: string, end?: string): string {
  const startAt = source.indexOf(start);
  assert(startAt >= 0, `section start not found: ${start}`);
  const endAt = end === undefined
    ? source.length
    : source.indexOf(end, startAt + start.length);
  assert(endAt >= 0, `section end not found: ${end}`);
  return source.slice(startAt, endAt);
}

Deno.test("non-card orders are rejected before provider credentials or calls", () => {
  const methodGuard = 'if (order.payment_method !== "paymob_card")';
  const guardAt = source.indexOf(methodGuard);
  const secretAt = source.indexOf('requireSecret(req, "PAYMOB_API_KEY")');
  const providerFetchAt = source.indexOf(
    '"https://accept.paymob.com/api/auth/tokens"',
  );

  assert(guardAt >= 0, "method guard must exist");
  assert(
    secretAt > guardAt,
    "provider credentials must be loaded after the method guard",
  );
  assert(
    providerFetchAt > guardAt,
    "provider calls must occur after the method guard",
  );
  assertIncludes(
    section(methodGuard, "// `currency`"),
    "status: 400",
    "non-card method guard must return HTTP 400",
  );
  assertIncludes(
    section(methodGuard, "// `currency`"),
    'message: "Unsupported payment method"',
    "non-card method guard must use a safe message",
  );
});

Deno.test("pre-provider recovery is token-bound and post-submit failure is retained", () => {
  assertIncludes(
    source,
    "release_paymob_initiation_claim",
    "pre-provider recovery must use the guarded RPC",
  );
  assertIncludes(
    source,
    "p_claim_token",
    "recovery must pass the unforgeable claim token",
  );
  assertIncludes(
    source,
    "providerSubmissionStarted",
    "provider submission stage must be tracked",
  );
  assertIncludes(
    source,
    "if (!providerSubmissionStarted)",
    "pre-provider failures must be recoverable only before submission",
  );
  assertIncludes(
    source,
    "mark_paymob_initiation_submitted",
    "claim must be advanced before provider-order POST",
  );
  assertIncludes(
    source,
    "claim retained",
    "ambiguous post-submit failure must retain the claim",
  );
});

Deno.test("internal client is created only after secret validation", () => {
  const secretAt = source.indexOf(
    'const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY")',
  );
  const clientAt = source.indexOf("const serviceRoleClient = createClient(");
  assert(
    secretAt >= 0 && clientAt > secretAt,
    "service-role client must follow requireSecret",
  );
});

Deno.test("claim release is unavailable to initiation and authenticated callers", () => {
  assertIncludes(
    source,
    "release_paymob_initiation_claim",
    "only the token-bound internal recovery path may reference release",
  );
  assertNotIncludes(
    source,
    "SupabaseClient",
    "initiation must not retain a release-only client type",
  );
});

Deno.test("internal transitions use a separate service-role client", () => {
  const serviceSection = section(
    'const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY")',
    "// ─── Provider steps",
  );
  assertIncludes(
    serviceSection,
    "const serviceRoleClient = createClient(",
    "internal client must be separate",
  );
  assertIncludes(
    serviceSection,
    "auth: { autoRefreshToken: false, persistSession: false }",
    "internal client must not inherit caller auth",
  );
  const providerSection = section(
    "// ─── Provider steps",
    "// ─── Return minimum safe client info",
  );
  assert(
    /serviceRoleClient\s*\.rpc\(\s*"mark_paymob_initiation_submitted"/s.test(
      providerSection,
    ),
    "mark transition must use service role",
  );
  assert(
    /serviceRoleClient\s*\.rpc\(\s*"release_paymob_initiation_claim"/s.test(
      providerSection,
    ),
    "release transition must use service role",
  );
  assertNotIncludes(
    serviceSection,
    'serviceRoleClient.rpc(\n      "get_or_claim_paymob_payment"',
    "claim RPC must remain caller-scoped",
  );
  assertNotIncludes(
    serviceSection,
    'serviceRoleClient\n        .rpc("set_payment_provider_order_id"',
    "provider persistence must remain caller-scoped",
  );
});

Deno.test("the atomic RPC is the only payment boundary", () => {
  assertIncludes(
    source,
    '"get_or_claim_paymob_payment"',
    "atomic claim RPC must be called",
  );
  assertIncludes(
    source,
    "{ p_order_id: order_id }",
    "RPC must receive only the canonical order id",
  );
  assertNotIncludes(
    source,
    ".insert(",
    "initiation must not directly insert payments",
  );
  assertIncludes(
    source,
    'requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY")',
    "internal transitions must require the service role secret",
  );
  assertIncludes(
    decisionSource,
    "claim.amount",
    "provider amount must come from the RPC claim",
  );
  assertNotIncludes(
    source,
    "const amountCents = order.total",
    "provider amount must not come from the pre-RPC read",
  );
});

Deno.test("existing provider order reissues a key without registering an order", () => {
  const existing = section(
    'if (decision.kind === "reissue")',
    'if (decision.kind === "in_progress")',
  );
  assertIncludes(
    existing,
    "reissuePaymentKey(",
    "existing provider order must reissue a key",
  );
  assertNotIncludes(
    existing,
    "/api/ecommerce/orders",
    "existing provider order must not be registered again",
  );
  assertIncludes(
    existing,
    "status: 200",
    "successful key reissue must return HTTP 200",
  );
  assertIncludes(
    existing,
    "checkout_url",
    "successful key reissue must return checkout_url only",
  );
});

Deno.test("in-progress and claimed branches prevent duplicate provider orders", () => {
  const inProgress = section(
    'if (decision.kind === "in_progress")',
    "const paymentId = decision.paymentId",
  );
  assertIncludes(
    inProgress,
    "status: decision.status",
    "recent claim must return HTTP 409",
  );
  assertIncludes(
    decisionSource,
    "Payment initiation already in progress",
    "recent claim must use the safe in-progress message",
  );

  const claimed = section(
    "const paymentId = decision.paymentId",
    "// ─── Provider steps ─────────────────────────────────────",
  );
  assertIncludes(
    claimed,
    "provider-order creation",
    "only the claimed branch may create the provider order",
  );
  assertIncludes(
    source.slice(
      source.indexOf(
        "// ─── Provider steps ─────────────────────────────────────",
      ),
    ),
    "/api/ecommerce/orders",
    "provider order creation must remain in the claimed provider section",
  );
});

Deno.test("provider persistence uses the guarded RPC and protects the claim on persistence failure", () => {
  assertIncludes(
    source,
    '"set_payment_provider_order_id"',
    "provider order must use the guarded persistence RPC",
  );
  assertIncludes(
    source,
    "release_paymob_initiation_claim",
    "pre-provider recovery must call the token-bound internal release",
  );
  assertIncludes(
    source,
    "p_claim_token: claimToken",
    "release must be bound to the current claim token",
  );
  assertIncludes(
    source,
    "claim retained",
    "all ambiguous provider failures must retain the claim",
  );
});

Deno.test("responses expose only safe keys", () => {
  const responsePattern = /new Response\(\s*JSON\.stringify\(\{([^}]*)\}\)/gs;
  const forbidden: string[] = [];
  for (const match of source.matchAll(responsePattern)) {
    const body = match[1];
    const after = source.slice(match.index ?? 0, (match.index ?? 0) + 320);
    const isSuccess = /status:\s*200/.test(after);
    const allowed = isSuccess ? ["message", "checkout_url"] : ["message"];
    for (const keyMatch of body.matchAll(/(?:^|,)\s*([A-Za-z_]\w*)\s*:/g)) {
      const key = keyMatch[1];
      if (!allowed.includes(key)) forbidden.push(key);
    }
  }
  assert(
    forbidden.length === 0,
    `response keys are not sanitized: ${forbidden.join(", ")}`,
  );

  assertNotIncludes(
    source,
    "JSON.stringify(authData)",
    "auth responses must not be serialized to logs",
  );
  assertNotIncludes(
    source,
    "JSON.stringify(paymobOrderData)",
    "provider order responses must not be serialized to logs",
  );
  assertNotIncludes(
    source,
    'console.error("paymob-initiate: Provider initiation failed", providerFailure)',
    "raw provider failures must not be logged",
  );
});

Deno.test("claim decisions exercise safe response behavior", () => {
  const cases: Array<{
    name: string;
    method: string;
    claim: PaymobClaim | null;
    kind: string;
    status?: number;
  }> = [
    {
      name: "non-card",
      method: "cash_on_delivery",
      claim: {
        ok: true,
        code: "claimed",
        payment_id: "p1",
        claim_token: "t1",
        amount: 100,
      },
      kind: "reject",
      status: 400,
    },
    {
      name: "existing provider",
      method: "paymob_card",
      claim: {
        ok: true,
        code: "existing_provider_order",
        payment_id: "p1",
        paymob_order_id: "provider-1",
        amount: 100,
      },
      kind: "reissue",
    },
    {
      name: "recent claim",
      method: "paymob_card",
      claim: {
        ok: true,
        code: "initiation_in_progress",
        payment_id: "p1",
        claim_token: "t1",
        amount: 100,
      },
      kind: "in_progress",
      status: 409,
    },
    {
      name: "new claim",
      method: "paymob_card",
      claim: {
        ok: true,
        code: "claimed",
        payment_id: "p1",
        claim_token: "t1",
        amount: 100,
      },
      kind: "create",
    },
  ];

  for (const testCase of cases) {
    const decision = decideInitiationClaim(testCase.method, testCase.claim);
    assert(
      decision.kind === testCase.kind,
      `${testCase.name} decision mismatch`,
    );
    if (testCase.status !== undefined) {
      assert(
        "status" in decision && decision.status === testCase.status,
        `${testCase.name} status mismatch`,
      );
    }
  }
});

Deno.test("request and server-authoritative invariants remain explicit", () => {
  assertIncludes(
    source,
    "const { order_id } = await req.json()",
    "request must accept the internal order id",
  );
  assertIncludes(
    source,
    '.eq("user_id", user.id)',
    "order lookup must be scoped to the authenticated owner",
  );
  assertIncludes(
    source,
    "get_or_claim_paymob_payment",
    "server must enforce ownership and pending state in the RPC",
  );
  assertIncludes(
    decisionSource,
    "Number.isFinite(claim.amount)",
    "RPC amount must be validated before provider calls",
  );
  assertNotIncludes(
    source,
    "transaction_id:",
    "initiation must not assign a provider transaction id",
  );
  assertIncludes(
    source,
    "claim retained",
    "ambiguous provider failure must retain the claim",
  );
  assertIncludes(source, "requireCors(req)", "CORS must fail closed");
  assertIncludes(
    source,
    'requireSecret(req, "PAYMOB_API_KEY")',
    "Paymob API key must be required",
  );
});

Deno.test("missing customer email fails closed before any provider use", () => {
  // The guard must sit between authentication and request validation so
  // no provider credential is loaded and no order is read without an
  // email to bill.
  const authAt = source.indexOf("if (authError || !user)");
  const validateAt = source.indexOf("// ─── Validate request ─");
  assert(authAt >= 0 && validateAt > authAt, "auth/request anchors missing");
  const prelude = source.slice(authAt, validateAt);
  assertIncludes(
    prelude,
    "!user.email",
    "must reject authenticated users without an email",
  );
  assertIncludes(prelude, "status: 400", "missing email must return HTTP 400");
  assertNotIncludes(
    source,
    '|| "customer@example.com"',
    "must never bill a fake fallback address",
  );
  assertNotIncludes(
    source,
    '?? "customer@example.com"',
    "must never bill a fake fallback address",
  );
});
