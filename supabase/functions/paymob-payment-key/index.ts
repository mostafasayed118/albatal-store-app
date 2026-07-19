// ============================================================
// Supabase Edge Function: paymob-payment-key
// Server-side payment key generation.
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

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const apiKey = Deno.env.get("PAYMOB_API_KEY");
    const integrationId = Deno.env.get("PAYMOB_INTEGRATION_ID");
    if (!apiKey || !integrationId) {
      return new Response(
        JSON.stringify({ message: "Paymob credentials not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { auth_token, order_id, amount_cents, email } = await req.json();

    // Get payment key
    const response = await fetch("https://accept.paymob.com/api/acceptance/payment_keys", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${auth_token}`,
      },
      body: JSON.stringify({
        auth_token,
        amount_cents,
        expiration: 3600,
        order_id,
        billing_data: {
          apartment: "NA",
          email: email || user.email || "customer@example.com",
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
    });

    const data = await response.json();

    if (data.token) {
      return new Response(
        JSON.stringify({ payment_key: data.token }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ message: "Failed to get payment key", error: data }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
