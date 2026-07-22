// ============================================================
// Supabase Edge Function: cancel-expired-orders
// Cancels orders that are still "pending" past their expires_at
// timestamp and restores reserved stock.
//
// Schedule: invoke every 5 minutes via pg_cron or Supabase
// edge-function invocation. This is idempotent — cancelling
// an already-cancelled order is a no-op.
//
// Uses service-role key to bypass RLS.
//
// Auth: x-scheduler-secret must match CANCEL_EXPIRED_ORDERS_SECRET
// using SHA-256 digest constant-time comparison (fail closed).
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonHeaders } from "../_shared/cors.ts";
import { secretsMatch } from "./secrets.ts";

export { secretsMatch } from "./secrets.ts";

async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // This worker changes order/payment/stock state. It is intended for a
    // scheduler only, never an unauthenticated browser request.
    const schedulerSecret = Deno.env.get("CANCEL_EXPIRED_ORDERS_SECRET");
    if (!schedulerSecret || schedulerSecret.trim().length === 0) {
      console.error(
        "cancel-expired-orders: CANCEL_EXPIRED_ORDERS_SECRET is not configured",
      );
      return new Response(
        JSON.stringify({ message: "Scheduler configuration unavailable" }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const receivedSecret = req.headers.get("x-scheduler-secret");
    if (!(await secretsMatch(schedulerSecret, receivedSecret))) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // ─── Find expired pending orders ──────────────────────────
    const { data: expiredOrders, error: queryError } = await supabase
      .from("orders")
      .select("id")
      .eq("status", "pending")
      .lt("expires_at", new Date().toISOString())
      .limit(100); // Process in batches of 100

    if (queryError) {
      console.error("Query error:", queryError);
      return new Response(
        JSON.stringify({ message: "Failed to query expired orders" }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    if (!expiredOrders || expiredOrders.length === 0) {
      return new Response(
        JSON.stringify({ message: "No expired orders found", cancelled: 0 }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    let cancelledCount = 0;

    // Process expired orders in parallel with a concurrency cap.
    // Each `expire_pending_order` RPC locks its own order row (FOR UPDATE
    // on a distinct p_order_id), so there is no cross-row contention.
    // Batching with a concurrency limit of 10 reduces wall-clock time
    // from O(n × RTT) to O(n/10 × RTT) during outage recovery.
    const CONCURRENCY = 10;
    for (let i = 0; i < expiredOrders.length; i += CONCURRENCY) {
      const batch = expiredOrders.slice(i, i + CONCURRENCY);
      const results = await Promise.allSettled(
        batch.map((order) =>
          supabase.rpc("expire_pending_order", { p_order_id: order.id })
        ),
      );
      for (const result of results) {
        if (result.status === "fulfilled") {
          const { data, error } = result.value;
          if (error) {
            console.error(
              "cancel-expired-orders: expiry RPC failed",
              error.message,
            );
          } else if (data?.ok && data.code === "expired") {
            cancelledCount++;
          }
        } else {
          console.error("cancel-expired-orders: RPC rejected", result.reason);
        }
      }
    }

    console.log(`Cancelled ${cancelledCount} expired orders`);

    return new Response(
      JSON.stringify({
        message: "Expired orders cancelled",
        cancelled: cancelledCount,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (_error) {
    console.error("cancel-expired-orders: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeaders() },
    );
  }
}

// Supabase Edge always loads this module as the entrypoint.
Deno.serve(handleRequest);
