// ============================================================
// Shared rate limiting for Edge Functions (audit 2026-09-13).
//
// Backed by public.rate_limit_take (migration 060): one atomic
// INSERT .. ON CONFLICT per check, SECURITY DEFINER. Handlers call
// `enforceRateLimit` BEFORE any expensive work and return the
// returned Response (429) when the caller's window budget is spent.
//
// FAILURE POSTURE: fail-OPEN on infra errors (logged). An outage of
// the rate limiter must never block payment webhooks or account
// deletion — the DB-level guarantees (single pending payment,
// HMAC-verified callbacks, owner-scoped RLS) remain the
// authoritative guards.
// ============================================================

import { jsonHeadersFor } from "./cors.ts";

/** Minimal surface of a supabase-js client this module needs. */
export interface RateLimitRpc {
  (
    fn: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
}

/** First hop of X-Forwarded-For (edge proxies prepend the client). */
export function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const first = fwd.split(",")[0].trim();
  return first.length > 0 ? first : "unknown";
}

/** Bucket namespacing: `<kind>:<id>` — see migration 060 docs. */
export function bucket(kind: string, id: string): string {
  return `${kind}:${id}`;
}

export interface RateLimitOptions {
  /** Caller identity — a user id or client IP. */
  id: string;
  /** Bucket kind, e.g. `proof:user` (see the per-function wiring). */
  kind: string;
  /** Max takes per window. */
  limit: number;
  /** Window length in seconds. */
  windowSeconds: number;
}

/**
 * Returns a 429 Response when the caller's budget is exhausted,
 * otherwise null (caller proceeds). Fail-open on RPC errors.
 */
export async function enforceRateLimit(
  req: Request,
  rpc: RateLimitRpc,
  opts: RateLimitOptions,
): Promise<Response | null> {
  try {
    const { data, error } = await rpc("rate_limit_take", {
      p_bucket: bucket(opts.kind, opts.id),
      p_limit: opts.limit,
      p_window_seconds: opts.windowSeconds,
    });
    if (error) {
      console.error("rate_limit_take failed — failing open");
      return null;
    }
    if (data === true) return null;
    return new Response(JSON.stringify({ message: "Too many requests" }), {
      status: 429,
      headers: jsonHeadersFor(req),
    });
  } catch (_err) {
    console.error("rate_limit_take threw — failing open");
    return null;
  }
}
