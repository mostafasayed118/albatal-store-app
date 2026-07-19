// ============================================================
// Supabase Edge Function: paymob-auth
// Server-side Paymob auth token — NEVER expose API key to client.
//
// ⚠️ DEPRECATED: Use /paymob-initiate instead. This function is
// retained for backward compatibility during the transition period.
// It will be removed in the next release.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("PAYMOB_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ message: "PAYMOB_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const response = await fetch("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    });

    const data = await response.json();

    if (data.token) {
      return new Response(
        JSON.stringify({ token: data.token }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ message: "Failed to get auth token", error: data }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
