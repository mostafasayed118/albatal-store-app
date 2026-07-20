// ============================================================
// Supabase Edge Function: checkout
//
// Thin wrapper around the `create_checkout_order` PostgreSQL RPC
// (migration 013). The RPC is SECURITY DEFINER and runs the entire
// order creation in a single atomic transaction:
//   - authenticates via auth.uid()
//   - validates items, stock, and address
//   - reads DB prices (never trusts client prices)
//   - calculates shipping via calculate_shipping_fee()
//   - inserts order + order_items
//   - decrements stock atomically
//   - handles idempotency
//
// This edge function exists for backward compatibility. The Flutter
// client calls the RPC directly via `supabase.rpc()`, but this
// function can be used by other callers or for testing.
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

    // Create a client with the user's JWT so the RPC can
    // resolve auth.uid() for authentication and authorization.
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

    const { payment_method, address_snapshot, items, idempotency_key } =
      await req.json();

    // ─── Call the atomic RPC ─────────────────────────────────
    // The RPC handles all validation, price lookup, stock
    // decrement, and order creation in one transaction.
    const { data, error } = await supabase.rpc("create_checkout_order", {
      p_payment_method: payment_method,
      p_address: address_snapshot,
      p_items: items,
      p_idempotency_key: idempotency_key ?? null,
    });

    if (error) {
      // The RPC raised an exception — map it to an HTTP error.
      // PostgREST returns the exception message in error.message.
      const status = error.code === "PGRST301" ? 400 : 400;
      return new Response(
        JSON.stringify({ message: error.message ?? "Checkout failed" }),
        { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Return the canonical order data ────────────────────
    return new Response(
      JSON.stringify({
        order_id: data.order_id,
        subtotal: data.subtotal,
        shipping: data.shipping,
        total_cents: data.total,
        status: data.status,
        expires_at: data.expires_at,
        idempotent: data.idempotent,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("checkout error:", error);
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
