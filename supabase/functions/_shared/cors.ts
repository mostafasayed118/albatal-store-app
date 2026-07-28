// Shared CORS configuration for all Edge Functions.
//
// SECURITY: Origins are sourced ONLY from the explicit
// `CORS_ALLOWED_ORIGINS` environment variable (comma-separated).
// The wildcard "*" is NEVER used as a default. If the variable is
// missing OR empty, the function fails CLOSED: no
// `Access-Control-Allow-Origin` header is emitted and a 500 is
// returned to the caller, so a misconfigured deployment cannot
// silently widen the CORS surface.
//
// In production, set CORS_ALLOWED_ORIGINS to the exact Flutter web
// origin(s), e.g.
//   CORS_ALLOWED_ORIGINS=https://app.albatal.example,https://staging.albatal.example
// For mobile-only deployments the header is harmless (browsers do not
// enforce CORS on native HTTP clients) but an explicit list is still
// required so a future web deployment cannot accidentally inherit a
// permissive wildcard.

const RAW_ORIGINS = Deno.env.get("CORS_ALLOWED_ORIGINS") ?? "";

/**
 * Parsed, trimmed, non-empty list of allowed origins.
 * Exported for tests and for `isOriginAllowed`.
 */
export const ALLOWED_ORIGINS: readonly string[] = RAW_ORIGINS
  .split(",")
  .map((o) => o.trim())
  .filter((o) => o.length > 0);

/**
 * True only when CORS is properly configured (at least one
 * explicit origin). When false, handlers MUST fail closed.
 */
export const corsConfigured: boolean = ALLOWED_ORIGINS.length > 0;

/**
 * Resolve the `Access-Control-Allow-Origin` value for a given
 * request's `Origin` header. Returns the matched origin string when
 * the request origin is in the allow-list, otherwise returns the
 * empty string (caller should not emit the header).
 *
 * Single-origin deployments are still served correctly because we
 * echo the specific matched origin rather than a wildcard.
 */
export function resolveAllowOrigin(req: Request): string {
  if (!corsConfigured) return "";
  const origin = req.headers.get("origin");
  if (!origin) return "";
  return ALLOWED_ORIGINS.includes(origin) ? origin : "";
}

/**
 * Build the CORS headers for a request. When CORS is not configured,
 * returns an empty record so the caller can detect misconfiguration
 * and fail closed.
 *
 * Exported for tests. Handlers should prefer `corsHeadersFor(req)`
 * over reading `corsHeaders` directly.
 */
export function corsHeadersFor(req: Request): Record<string, string> {
  const allow = resolveAllowOrigin(req);
  if (!allow) return {};
  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

/**
 * Backwards-compatible static CORS header set. NOTE: this does NOT
 * include `Access-Control-Allow-Origin` when the env var is missing
 * (it would be empty / undefined). Prefer `corsHeadersFor(req)` in
 * handlers that have a `Request` available.
 *
 * Kept for handlers that respond to OPTIONS preflight before a request
 * body is parsed; they should call `corsHeadersFor(req)` instead.
 */
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * Returns standard JSON response headers (CORS + Content-Type) for a
 * request. When CORS is misconfigured, the returned headers omit the
 * `Access-Control-Allow-Origin` header entirely; the caller is
 * responsible for returning a 500 in that case (see `requireCors`).
 */
export function jsonHeadersFor(
  req: Request,
  extra?: Record<string, string>,
): Record<string, string> {
  return { ...corsHeadersFor(req), "Content-Type": "application/json", ...extra };
}

/**
 * Legacy `jsonHeaders` (no request context). Returns headers WITHOUT
 * an `Access-Control-Allow-Origin` value. Handlers that still call
 * this should be migrated to `jsonHeadersFor(req)`.
 */
export function jsonHeaders(extra?: Record<string, string>): Record<string, string> {
  return { ...corsHeaders, "Content-Type": "application/json", ...extra };
}

/**
 * Guard for handlers: returns a 500 Response when CORS is not
 * configured. Handlers should call this at the top of OPTIONS/GET/POST
 * handling to fail closed on misconfiguration.
 *
 * Example:
 *   const fail = requireCors(req);
 *   if (fail) return fail;
 */
export function requireCors(req: Request): Response | null {
  if (corsConfigured) return null;
  // Fail closed: no origin header, 500.
  console.error(
    "cors: CORS_ALLOWED_ORIGINS is not configured — failing closed (500)",
  );
  return new Response(
    JSON.stringify({ message: "Server CORS configuration error" }),
    {
      status: 500,
      headers: { "Content-Type": "application/json" },
    },
  );
}

/// Sanitize an unknown error to a safe client-facing string.
/// Never return raw error objects, stack traces, or upstream payloads.
/// Never log secret values.
export function sanitizeError(error: unknown): string {
  if (error instanceof Error) {
    // Log the message only (never the stack which may include env
    // values interpolated from upstream). Return a generic message.
    console.error("error:", error.name, error.message);
    return "Internal server error";
  }
  console.error("unknown error:", typeof error);
  return "Internal server error";
}
