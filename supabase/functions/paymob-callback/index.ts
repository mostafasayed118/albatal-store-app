// ============================================================
// Supabase Edge Function: paymob-callback
// Handles Paymob webhook/callback — verifies payment server-side.
// Idempotent: duplicate callbacks return the same result.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.177.0/hash/sha256.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET");
    const body = await req.text();
    const params = new URLSearchParams(body);

    // Verify HMAC signature
    if (hmacSecret) {
      const receivedHmac = params.get("hmac") || "";
      const hmacData = params.toString().replace(/&hmac=[^&]*/, "");
      const computedHmac = createHmac("sha256", hmacSecret)
        .update(hmacData)
        .digest("hex");

      if (receivedHmac !== computedHmac) {
        console.error("HMAC verification failed");
        return new Response(
          JSON.stringify({ message: "Invalid signature" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const transactionId = params.get("id");
    const success = params.get("success") === "true";
    const orderId = params.get("order");

    if (!transactionId || !orderId) {
      return new Response(
        JSON.stringify({ message: "Missing required parameters" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Idempotent: check if payment already processed
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id, status")
      .eq("transaction_id", transactionId)
      .single();

    if (existingPayment && existingPayment.status === "success") {
      // Already processed — return OK without duplicate work
      return new Response(
        JSON.stringify({ message: "Payment already processed", id: existingPayment.id }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get the payment record
    const { data: payment, error: payError } = await supabase
      .from("payments")
      .select("*")
      .eq("transaction_id", transactionId)
      .single();

    if (payError || !payment) {
      // Payment record doesn't exist — this might be a direct callback
      // Store it
      await supabase.from("payments").insert({
        order_id: orderId,
        user_id: "00000000-0000-0000-0000-000000000000",
        method: "paymob_card",
        amount: parseInt(params.get("amount_cents") || "0"),
        transaction_id: transactionId,
        status: success ? "success" : "failed",
      });
    } else {
      // Update existing payment
      await supabase
        .from("payments")
        .update({ status: success ? "success" : "failed" })
        .eq("transaction_id", transactionId);
    }

    // Update order status
    if (success) {
      await supabase
        .from("orders")
        .update({
          status: "placed",
          payment_id: transactionId,
        })
        .eq("id", orderId)
        .eq("status", "pending"); // Only update if still pending
    } else {
      // Payment failed — restore stock
      const { data: orderItems } = await supabase
        .from("order_items")
        .select("*")
        .eq("order_id", orderId);

      if (orderItems) {
        for (const item of orderItems) {
          await supabase.rpc("increment_stock", {
            p_product_id: item.product_id,
            p_size: item.size,
            p_color: item.color,
            p_quantity: item.quantity,
          });
        }
      }

      await supabase
        .from("orders")
        .update({ status: "cancelled" })
        .eq("id", orderId)
        .eq("status", "pending");
    }

    return new Response(
      JSON.stringify({ message: "Callback processed", success }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Callback error:", error);
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
