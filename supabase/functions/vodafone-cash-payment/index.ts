// ============================================================
// Supabase Edge Function: vodafone-cash-payment
// Initiates a Vodafone Cash payment request.
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

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { amount, phone_number, order_id } = await req.json();

    if (!amount || !phone_number || !order_id) {
      return new Response(
        JSON.stringify({ message: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // In production, this would call the Vodafone Cash API
    // For now, simulate the payment request
    const transactionId = `VFC-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    // Store the pending payment
    await supabase.from("payments").insert({
      order_id: order_id,
      user_id: user.id,
      method: "vodafone_cash",
      amount: amount,
      phone_number: phone_number,
      transaction_id: transactionId,
      status: "pending",
    });

    return new Response(
      JSON.stringify({
        transaction_id: transactionId,
        status: "pending",
        message: "Payment request sent. Please approve on your phone.",
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
