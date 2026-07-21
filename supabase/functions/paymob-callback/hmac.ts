// ============================================================
// Paymob HMAC verification module.
//
// Used by the paymob-callback Edge Function to verify that a
// callback was actually issued by Paymob. Pure functions — no
// network, no DB — so this file can be unit-tested in
// isolation with `deno test`.
//
// CANONICAL HMAC PAYLOAD (Paymob Accept standard redirect
// callback, form-urlencoded POST):
//
// Paymob's documented callback HMAC is computed over the
// values of a fixed set of fields, concatenated in the exact
// order below, with NO separators between values. The
// algorithm is HMAC-SHA512 and the digest is hex-lowercase.
//
// The canonical field list and order is:
//
//   1.  amount_cents
//   2.  created_at
//   3.  currency
//   4.  error_occured
//   5.  has_parent_transaction
//   6.  id
//   7.  integration_id
//   8.  is_3d_secure
//   9.  is_auth
//   10. is_capture
//   11. is_refunded
//   12. is_standalone_payment
//   13. is_voided
//   14. order
//   15. owner
//   16. pending
//   17. source_data_pan
//   18. source_data_sub_type
//   19. source_data_type
//   20. success
//
// Notes:
//   * `order` is the Paymob provider order id (a number
//     rendered as a string). It is NOT the internal UUID.
//   * `source_data_pan`, `source_data_sub_type`,
//     `source_data_type` are sent as flat fields in the
//     form-urlencoded callback (Paymob flattens the nested
//     `source_data` object using underscores).
//   * Boolean fields are sent as the strings "true"/"false".
//   * Missing fields are treated as the empty string "".
//
// Source: Paymob Accept developer documentation (standard
// redirect callback HMAC calculation), confirmed against
// real Paymob integrations. If the project's Paymob account
// is ever migrated to a different callback type (e.g. the
// JSON `obj` webhook), the field list above MUST be
// re-verified against the official docs for that callback
// type before changing this file.
// ============================================================

/**
 * The exact, ordered list of field names that Paymob signs in
 * the standard redirect callback. Exported so tests can
 * assert against it and so a fixture can build a canonical
 * payload.
 */
export const PAYMOB_HMAC_FIELDS: readonly string[] = [
  "amount_cents",
  "created_at",
  "currency",
  "error_occured",
  "has_parent_transaction",
  "id",
  "integration_id",
  "is_3d_secure",
  "is_auth",
  "is_capture",
  "is_refunded",
  "is_standalone_payment",
  "is_voided",
  "order",
  "owner",
  "pending",
  "source_data_pan",
  "source_data_sub_type",
  "source_data_type",
  "success",
] as const;

/**
 * Build the canonical HMAC input string from a callback's
 * field values, in the documented order, with no separators.
 *
 * @param values a map of field name -> string value. Missing
 *   fields are treated as the empty string. Boolean values
 *   should be passed as the strings Paymob sends ("true" /
 *   "false").
 */
export function buildHmacPayload(values: Record<string, string>): string {
  return PAYMOB_HMAC_FIELDS.map((f) => values[f] ?? "").join("");
}

/**
 * Compute the expected HMAC-SHA512 hex digest for a callback.
 *
 * @param values  the callback field values
 * @param secret  the PAYMOB_HMAC_SECRET (server-side only)
 */
export async function computeHmac(
  values: Record<string, string>,
  secret: string,
): Promise<string> {
  const payload = buildHmacPayload(values);
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Constant-time comparison of two hex digests.
 *
 * Compares every byte and never short-circuits on the first
 * mismatch, so an attacker cannot use timing to discover the
 * correct digest one character at a time. Returns true only
 * if both strings have the same length AND every byte matches.
 */
export function constantTimeEquals(a: string, b: string): boolean {
  // Normalize to lowercase so callers can pass either case.
  const left = a.toLowerCase();
  const right = b.toLowerCase();
  if (left.length !== right.length) {
    // Still walk both arrays to keep timing roughly
    // independent of length-mismatch patterns.
    let dummy = 0;
    for (let i = 0; i < Math.max(left.length, right.length); i++) {
      dummy |= (left.charCodeAt(i) || 0) ^ (right.charCodeAt(i) || 0);
    }
    return false;
  }
  let diff = 0;
  for (let i = 0; i < left.length; i++) {
    diff |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Verify a callback's HMAC in constant time.
 *
 * @param values      the callback field values
 * @param secret      the PAYMOB_HMAC_SECRET
 * @param receivedHmac the `hmac` field from the callback
 * @returns true only if the digest matches in constant time
 */
export async function verifyHmac(
  values: Record<string, string>,
  secret: string,
  receivedHmac: string,
): Promise<boolean> {
  const expected = await computeHmac(values, secret);
  return constantTimeEquals(expected, receivedHmac);
}
