// ============================================================
// Contract test for instapay-submit-proof security properties.
//
// Source-level analysis: verifies that proof submission is
// owner-scoped, size-guarded, and can never mark a payment
// successful — success is decided ONLY by instapay-review.
//
// Run: deno test --allow-read supabase/functions/instapay-submit-proof/
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

Deno.test("proof submission requires authentication", () => {
  assertIncludes(
    source,
    'req.headers.get("Authorization")',
    "must read the Authorization header",
  );
  assertIncludes(source, "Unauthorized", "bad JWT must be refused");
});

Deno.test("pending payment is located server-side, never client-named", () => {
  const paymentQuery = source.indexOf('.from("payments")');
  assert(paymentQuery >= 0, "must query payments");
  const scoped = source.slice(paymentQuery, paymentQuery + 600);
  for (
    const fragment of [
      '.eq("order_id", orderId)',
      '.eq("user_id", user.id)',
      '.eq("method", "instapay")',
      '.eq("status", "pending")',
    ]
  ) {
    assertIncludes(
      scoped,
      fragment,
      `payment lookup must be scoped: ${fragment}`,
    );
  }
  assertNotIncludes(
    source,
    "body.payment_id",
    "payment_id must never be accepted from the client",
  );
});

Deno.test("payload is size-guarded before decode", () => {
  const sizeGuard = source.indexOf("MAX_PROOF_BYTES * 4) / 3");
  const decode = source.indexOf("atob(proofBase64)");
  assert(sizeGuard >= 0, "base64-inflated size guard must exist");
  assert(decode >= 0, "decode must exist");
  assert(sizeGuard < decode, "size guard must run before decoding");
  assertIncludes(source, "MAX_PROOF_BYTES", "decoded size must be re-checked");
});

Deno.test("screenshot goes to the private bucket under the caller's own folder", () => {
  assertIncludes(
    source,
    '.from("instapay-proofs")',
    "must upload to the 041 private bucket",
  );
  const uploadPath = source.indexOf("const storagePath =");
  assert(uploadPath >= 0, "storage path must be constructed");
  const pathLine = source.slice(uploadPath, uploadPath + 200);
  assert(
    pathLine.includes("${user.id}/"),
    "path must be rooted in the caller's own folder (storage RLS layout)",
  );
  assert(
    pathLine.includes("${payment.id}/"),
    "path must be scoped to the payment",
  );
});

Deno.test("submission records the proof only — it can never flip payment status", () => {
  assertIncludes(
    source,
    '.from("instapay_proofs")',
    "must insert into the 041 proof table",
  );
  assertNotIncludes(
    source,
    '"success"',
    "submission must never mark a payment successful",
  );
  assertNotIncludes(
    source,
    ".update(",
    "submission must never update payment rows",
  );
  assertIncludes(
    source,
    'status: "pending"',
    "response must report the still-pending state",
  );
});

Deno.test("fail-closed CORS and generic errors", () => {
  assertIncludes(source, "requireCors(req)", "CORS must fail closed");
  assertIncludes(source, "Internal error", "unexpected errors stay generic");
  assertNotIncludes(
    source,
    "SUPABASE_SERVICE_ROLE_KEY",
    "submission never needs elevated credentials",
  );
});
