// ============================================================
// Supabase Edge Function: vodafone-cash-verify
// Idempotent verification — duplicate calls return same result.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ message: "Authentication required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { transaction_id } = await req.json();

    if (!transaction_id) {
      return new Response(
        JSON.stringify({ message: "Transaction ID required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Idempotent: look up existing payment
    const { data: payment, error } = await supabase
      .from("payments")
      .select("*")
      .eq("transaction_id", transaction_id)
      .single();

    if (error || !payment) {
      return new Response(
        JSON.stringify({ message: "Payment not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // If already successful, return immediately (idempotent)
    if (payment.status === "success") {
      return new Response(
        JSON.stringify({
          status: "SUCCESS",
          amount: payment.amount,
          transaction_id,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Simulate verification (in production, call Vodafone Cash API)
    const newStatus = payment.status === "pending" ? "SUCCESS" : payment.status;

    if (newStatus === "SUCCESS") {
      // Update payment
      await supabase
        .from("payments")
        .update({ status: "success" })
        .eq("transaction_id", transaction_id);

      // Update order (only if still pending)
      await supabase
        .from("orders")
        .update({ status: "placed", payment_id: transaction_id })
        .eq("id", payment.order_id)
        .eq("status", "pending");
    }

    return new Response(
      JSON.stringify({
        status: newStatus,
        amount: payment.amount,
        transaction_id,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
