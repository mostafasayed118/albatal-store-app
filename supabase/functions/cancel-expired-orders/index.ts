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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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
    let stockRestoredCount = 0;

    for (const order of expiredOrders) {
      // ─── Restore stock for order items ──────────────────────
      const { data: orderItems } = await supabase
        .from("order_items")
        .select("*")
        .eq("order_id", order.id);

      if (orderItems) {
        for (const item of orderItems) {
          await supabase.rpc("increment_stock", {
            p_product_id: item.product_id,
            p_size: item.size,
            p_color: item.color,
            p_quantity: item.quantity,
          });
          stockRestoredCount++;
        }
      }

      // ─── Cancel the order ──────────────────────────────────
      await supabase
        .from("orders")
        .update({ status: "cancelled" })
        .eq("id", order.id)
        .eq("status", "pending");

      cancelledCount++;
    }

    console.log(
      `Cancelled ${cancelledCount} expired orders, restored stock for ${stockRestoredCount} items`
    );

    return new Response(
      JSON.stringify({
        message: "Expired orders cancelled",
        cancelled: cancelledCount,
        stockItemsRestored: stockRestoredCount,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("cancel-expired-orders error:", error);
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
