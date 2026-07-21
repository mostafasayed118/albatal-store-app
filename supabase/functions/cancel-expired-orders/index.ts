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
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // This worker changes order/payment/stock state. It is intended for a
    // scheduler only, never an unauthenticated browser request.
    const schedulerSecret = Deno.env.get("CANCEL_EXPIRED_ORDERS_SECRET");
    const receivedSecret = req.headers.get("x-scheduler-secret");
    if (!schedulerSecret || receivedSecret !== schedulerSecret) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
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
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!expiredOrders || expiredOrders.length === 0) {
      return new Response(
        JSON.stringify({ message: "No expired orders found", cancelled: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let cancelledCount = 0;
    for (const order of expiredOrders) {
      // `expire_pending_order` locks the order and updates order, payment,
      // and inventory restoration in one transaction. It is idempotent.
      const { data, error } = await supabase.rpc("expire_pending_order", {
        p_order_id: order.id,
      });
      if (error) {
        console.error("cancel-expired-orders: expiry RPC failed", error.message);
        continue;
      }
      if (data?.ok && data.code === "expired") cancelledCount++;
    }

    console.log(
      `Cancelled ${cancelledCount} expired orders`
    );

    return new Response(
      JSON.stringify({
        message: "Expired orders cancelled",
        cancelled: cancelledCount,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (_error) {
    console.error("cancel-expired-orders: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeaders() }
    );
  }
});
