// ============================================================
// Supabase Edge Function: cancel-expired-orders
// Cancels orders that are still "pending" past their expires_at
// timestamp and restores reserved stock.
//
// Schedule: invoke every 5 minutes via pg_cron or Supabase
// edge-function invocation. This is idempotent — cancelling
// an already-cancelled order is a no-op.
//
// SECURITY:
//   * This worker mutates order/payment/stock state. It is
//     intended for a scheduler only, never an unauthenticated
//     browser request.
//   * The scheduler secret is verified in CONSTANT TIME via
//     `requireSecretHeader`. A naive `===` would leak timing
//     that an attacker could use to recover the secret one
//     character at a time.
//   * The function FAILS CLOSED when required secrets are
//     missing (SUPABASE_SERVICE_ROLE_KEY, scheduler secret).
//     No state is mutated when the server is misconfigured.
//   * Secrets are NEVER logged.
//   * CORS origins are read from CORS_ALLOWED_ORIGINS; the
//     wildcard "*" is never used as a default. When the env
//     var is missing, the function fails closed (500).
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsConfigured,
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";
import { requireSecret, requireSecretHeader } from "../_shared/secrets.ts";

Deno.serve(async (req) => {
  // Fail closed on CORS misconfiguration.
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  const headers = corsHeadersFor(req);
  const jsonH = jsonHeadersFor(req);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    // Authorization: scheduler secret (constant-time).
    // This worker changes order/payment/stock state. It is intended
    // for a scheduler only, never an unauthenticated browser request.
    //
    // `requireSecretHeader` reads SCHEDULER_SECRET, compares it
    // against the `x-scheduler-secret` header in CONSTANT TIME, and
    // returns a 401 when the secret is missing, the header is
    // missing, or the values differ. It never logs the secret.
    //
    // NOTE: we deliberately use SCHEDULER_SECRET (the canonical
    // name required by the security brief) rather than the legacy
    // CANCEL_EXPIRED_ORDERS_SECRET. The legacy name is kept as a
    // fallback for one release to avoid breaking an in-flight
    // deployment; it will be removed in the next release.
    const secretName =
      Deno.env.get("SCHEDULER_SECRET") !== undefined
        ? "SCHEDULER_SECRET"
        : "CANCEL_EXPIRED_ORDERS_SECRET";
    const authFail = requireSecretHeader(req, secretName, "x-scheduler-secret");
    if (authFail) return authFail;

    // Fail closed when service_role key is missing.
    const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
    if (serviceRoleFail) return serviceRoleFail;

    // Read SUPABASE_URL (non-secret). If it is missing the client
    // will fail; we still treat it as a 500 server-config error.
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    if (!supabaseUrl) {
      console.error(
        "cancel-expired-orders: SUPABASE_URL is not configured",
      );
      return new Response(
        JSON.stringify({ message: "Server configuration error" }),
        { status: 503, headers: jsonH },
      );
    }

    const supabase = createClient(
      supabaseUrl,
      // Safe to read again: we already verified presence above.
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string,
    );

    // Find expired pending orders.
    const { data: expiredOrders, error: queryError } = await supabase
      .from("orders")
      .select("id")
      .eq("status", "pending")
      .lt("expires_at", new Date().toISOString())
      .limit(100); // Process in batches of 100

    if (queryError) {
      // Log the error code only (never the full error object which
      // may contain interpolated env values).
      console.error("cancel-expired-orders: query error", queryError.code);
      return new Response(
        JSON.stringify({ message: "Failed to query expired orders" }),
        { status: 500, headers: jsonH },
      );
    }

    if (!expiredOrders || expiredOrders.length === 0) {
      return new Response(
        JSON.stringify({ message: "No expired orders found", cancelled: 0 }),
        { status: 200, headers: jsonH },
      );
    }

    let cancelledCount = 0;
    for (const order of expiredOrders) {
      // expire_pending_order locks the order and updates order, payment,
      // and inventory restoration in one transaction. It is idempotent.
      const { data, error } = await supabase.rpc("expire_pending_order", {
        p_order_id: order.id,
      });
      if (error) {
        // Never log raw error.message — may contain secrets/PII.
        console.error("cancel-expired-orders: expiry RPC failed", error.code);
        continue;
      }
      if (data?.ok && data.code === "expired") cancelledCount++;
    }

    console.log(`Cancelled ${cancelledCount} expired orders`);

    return new Response(
      JSON.stringify({
        message: "Expired orders cancelled",
        cancelled: cancelledCount,
      }),
      { status: 200, headers: jsonH },
    );
  } catch (_error) {
    // SECURITY: never log the raw error — it may contain env values.
    console.error("cancel-expired-orders: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonH },
    );
  }
});