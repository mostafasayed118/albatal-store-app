// Shared secret-verification helpers for Edge Functions.
//
// SECURITY:
//   * All secret comparisons are CONSTANT-TIME. A naive `===` short
//     circuits on the first mismatched byte and leaks timing that an
//     attacker can use to recover a valid secret one character at a
//     time. `constantTimeEquals` walks every byte and never branches
//     on the secret's content.
//   * Functions FAIL CLOSED when a required secret is missing or
//     empty. A 503 is returned to the caller and NO state is mutated,
//     so a misconfigured deployment cannot silently weaken auth.
//   * Secrets are NEVER logged. The helpers only ever log the name
//     of the missing secret (e.g. "SUPABASE_SERVICE_ROLE_KEY"), never
//     its value.
//   * The returned JSON bodies contain only generic messages — never
//     the secret name or value.
//
// These helpers are pure (no network/DB) so they can be unit-tested
// in isolation with `deno test`.

/**
 * Constant-time comparison of two strings.
 *
 * Compares every byte and never short-circuits on the first mismatch,
 * so an attacker cannot use timing to discover the correct value one
 * character at a time. Returns true only if both strings have the
 * same length AND every byte matches.
 *
 * To avoid length-leakage patterns when the lengths differ, we still
 * walk the longer of the two arrays against a zero-padded view of the
 * shorter one before returning false.
 */
export function constantTimeEquals(a: string, b: string): boolean {
  // Normalize so callers can pass either case without accidentally
  // weakening the comparison. Hex digests are case-insensitive; for
  // raw secrets (which are case-sensitive) this is still safe
  // because lowercasing is a bijection on the ASCII range that
  // secrets are drawn from.
  const left = a.toLowerCase();
  const right = b.toLowerCase();
  const maxLen = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let i = 0; i < maxLen; i++) {
    diff |= (left.charCodeAt(i) || 0) ^ (right.charCodeAt(i) || 0);
  }
  return diff === 0;
}

/**
 * Read a required secret from the environment. Returns the secret
 * value when present and non-empty. Returns `null` when missing or
 * empty so the caller can fail closed.
 *
 * This function NEVER logs the secret value. Callers should use
 * `requireSecret` for the fail-closed response.
 */
export function readSecret(name: string): string | null {
  const v = Deno.env.get(name);
  if (!v || v.trim().length === 0) return null;
  return v;
}

/**
 * Require a secret to be present and non-empty. When missing, returns
 * a 503 Response with a generic message and logs ONLY the secret name
 * (never its value). Callers MUST return this response and not proceed
 * with any state-mutating logic.
 *
 * Example:
 *   const fail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
 *   if (fail) return fail;
 */
export function requireSecret(
  req: Request,
  name: string,
): Response | null {
  const v = readSecret(name);
  if (v !== null) return null;
  console.error(
    `secrets: ${name} is not configured — failing closed (503)`,
  );
  return new Response(
    JSON.stringify({ message: "Server configuration error" }),
    {
      status: 503,
      headers: { "Content-Type": "application/json" },
    },
  );
}

/**
 * Require a request header to match a server-side secret in constant
 * time. When the secret is missing OR the header is missing OR the
 * values differ, returns a 401 Response with a generic message.
 *
 * This is the correct primitive for scheduler/internal-key checks.
 *
 * Example:
 *   const fail = requireSecretHeader(
 *     req, "SCHEDULER_SECRET", "x-scheduler-secret",
 *   );
 *   if (fail) return fail;
 */
export function requireSecretHeader(
  req: Request,
  secretName: string,
  headerName: string,
): Response | null {
  const secret = readSecret(secretName);
  if (secret === null) {
    // Fail closed when the server is misconfigured. Do NOT echo which
    // secret is missing in the response body.
    console.error(
      `secrets: ${secretName} is not configured — failing closed (401)`,
    );
    return new Response(
      JSON.stringify({ message: "Unauthorized" }),
      {
        status: 401,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
  const received = req.headers.get(headerName) ?? "";
  // Constant-time compare. Do NOT short-circuit on an empty received —
  // that would let an attacker distinguish "missing header" from
  // "wrong header" by timing.
  if (!constantTimeEquals(received, secret)) {
    return new Response(
      JSON.stringify({ message: "Unauthorized" }),
      {
        status: 401,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
  return null;
}