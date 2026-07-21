// Shared CORS configuration for all Edge Functions.
//
// SECURITY: In production, replace "*" with the actual Flutter web
// domain(s). The wildcard is acceptable for mobile-only apps because
// browsers don't enforce CORS on native HTTP clients, but it MUST be
// tightened before any web deployment.

const ALLOWED_ORIGINS = Deno.env.get("CORS_ALLOWED_ORIGINS") ?? "*";

export const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGINS,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/// Returns standard JSON response headers (CORS + Content-Type).
export function jsonHeaders(extra?: Record<string, string>): Record<string, string> {
  return { ...corsHeaders, "Content-Type": "application/json", ...extra };
}

/// Sanitize an unknown error to a safe client-facing string.
/// Never return raw error objects, stack traces, or upstream payloads.
export function sanitizeError(error: unknown): string {
  if (error instanceof Error) {
    // Log full error server-side; return only a generic message.
    console.error(error);
    return "Internal server error";
  }
  console.error("Unknown error:", String(error));
  return "Internal server error";
}
