/**
 * Compare two secrets without short-circuiting on the first differing
 * character. Digests are fixed-length (SHA-256), so length of the raw
 * secret is not leaked via early exit of a byte loop over the secret.
 *
 * Empty/whitespace expected secrets fail closed.
 */
export async function secretsMatch(
  expected: string,
  provided: string | null,
): Promise<boolean> {
  if (!expected || expected.trim().length === 0) {
    return false;
  }
  if (provided === null) {
    return false;
  }

  const enc = new TextEncoder();
  const [expectedDigest, providedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(expected)),
    crypto.subtle.digest("SHA-256", enc.encode(provided)),
  ]);

  const a = new Uint8Array(expectedDigest);
  const b = new Uint8Array(providedDigest);
  if (a.length !== b.length) {
    return false;
  }

  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}
