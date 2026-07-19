// ============================================================
// Supabase Edge Function: paymob-initiate
// Single-call Paymob payment initiation.
// Collapses paymob-auth + paymob-order + paymob-payment-key
// into one server-side call to reduce client round trips.
//
// Expects:
//   - Authorization header (authenticated user)
//   - body: { order_id, amount_cents, customer_email }
//
// Returns:
//   - { payment_key, checkout_url, iframe_id }
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
    // ─── Auth check ──────────────────────────────────────────
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

    // ─── Validate request ────────────────────────────────────
    const { order_id, amount_cents, customer_email } = await req.json();

    if (!order_id || !amount_cents) {
      return new Response(
        JSON.stringify({ message: "order_id and amount_cents required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Verify the order belongs to this user and is pending ──
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, status, total")
      .eq("id", order_id)
      .eq("user_id", user.id)
      .single();

    if (orderError || !order) {
      return new Response(
        JSON.stringify({ message: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (order.status !== "pending") {
      return new Response(
        JSON.stringify({ message: "Order is not pending" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Verify amount matches server-computed total ──────────
    // The server computed total is the source of truth.
    // Client must never override it.
    const serverAmountCents = order.total as number;
    if (amount_cents !== serverAmountCents) {
      return new Response(
        JSON.stringify({
          message: "Amount mismatch",
          expected: serverAmountCents,
          received: amount_cents,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Get Paymob credentials ──────────────────────────────
    const apiKey = Deno.env.get("PAYMOB_API_KEY");
    const integrationId = Deno.env.get("PAYMOB_INTEGRATION_ID");
    const iframeId = Deno.env.get("PAYMOB_IFRAME_ID") ?? "85679";
    if (!apiKey || !integrationId) {
      return new Response(
        JSON.stringify({ message: "Paymob credentials not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Step 1: Auth token ──────────────────────────────────
    const authResponse = await fetch("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    });
    const authData = await authResponse.json();
    if (!authData.token) {
      return new Response(
        JSON.stringify({ message: "Failed to get Paymob auth token" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Step 2: Register order ──────────────────────────────
    const paymobOrderResponse = await fetch(
      "https://accept.paymob.com/api/ecommerce/orders",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${authData.token}`,
        },
        body: JSON.stringify({
          auth_token: authData.token,
          delivery_needed: false,
          amount_cents: amount_cents,
          currency: "EGP",
          items: [],
        }),
      }
    );
    const paymobOrderData = await paymobOrderResponse.json();
    if (!paymobOrderData.id) {
      return new Response(
        JSON.stringify({ message: "Failed to register Paymob order" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Step 3: Payment key ─────────────────────────────────
    const keyResponse = await fetch(
      "https://accept.paymob.com/api/acceptance/payment_keys",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${authData.token}`,
        },
        body: JSON.stringify({
          auth_token: authData.token,
          amount_cents: amount_cents,
          expiration: 3600,
          order_id: paymobOrderData.id,
          billing_data: {
            apartment: "NA",
            email: customer_email || user.email || "customer@example.com",
            floor: "NA",
            first_name: "Customer",
            street: "NA",
            building: "NA",
            phone_number: "+201000000000",
            shipping_method: "NA",
            postal_code: "NA",
            city: "Cairo",
            country: "EG",
            last_name: "Customer",
            state: "Cairo",
          },
          integration_id: integrationId,
        }),
      }
    );
    const keyData = await keyResponse.json();
    if (!keyData.token) {
      return new Response(
        JSON.stringify({ message: "Failed to get payment key" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Store payment record ────────────────────────────────
    await supabase.from("payments").insert({
      order_id: order_id,
      user_id: user.id,
      method: "paymob_card",
      amount: amount_cents,
      transaction_id: `PAYMOB-${paymobOrderData.id}-${Date.now()}`,
      status: "pending",
    });

    // ─── Return payment key + checkout URL ────────────────────
    const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${keyData.token}`;

    return new Response(
      JSON.stringify({
        payment_key: keyData.token,
        checkout_url: checkoutUrl,
        iframe_id: iframeId,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("paymob-initiate error:", error);
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
