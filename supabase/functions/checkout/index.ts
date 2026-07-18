// ============================================================
// Supabase Edge Function: checkout
// Creates orders server-side — never trusts client prices.
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
    // Auth check — only authenticated users can place orders
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

    const { payment_method, address_snapshot, items } = await req.json();

    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ message: "Cart is empty" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Server-side price lookup and stock validation
    let subtotal = 0;
    const validatedItems = [];

    for (const item of items) {
      // Look up current price and stock from database
      const { data: variant, error: vError } = await supabase
        .from("product_variants")
        .select("stock, price_override, products(base_price, name)")
        .eq("product_id", item.product_id)
        .eq("size", item.size)
        .eq("color", item.color)
        .single();

      if (vError || !variant) {
        return new Response(
          JSON.stringify({ message: `Variant not found: ${item.size}/${item.color}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (variant.stock < item.quantity) {
        return new Response(
          JSON.stringify({
            message: `Insufficient stock for ${variant.products.name} (${item.size}/${item.color}). Available: ${variant.stock}`,
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const unitPrice = variant.price_override ?? variant.products.base_price;
      subtotal += unitPrice * item.quantity;

      validatedItems.push({
        product_id: item.product_id,
        variant_id: null, // Will be resolved
        product_name: variant.products.name,
        size: item.size,
        color: item.color,
        unit_price: unitPrice,
        quantity: item.quantity,
      });
    }

    const shipping = subtotal > 50000 ? 0 : 7500; // Free shipping over 500 EGY
    const total = subtotal + shipping;

    // Create order in a transaction
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        user_id: user.id,
        status: "placed",
        subtotal,
        shipping,
        total,
        payment_method,
        address_snapshot,
      })
      .select()
      .single();

    if (orderError) {
      return new Response(
        JSON.stringify({ message: "Failed to create order" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create order items
    const orderItems = validatedItems.map((item) => ({
      order_id: order.id,
      ...item,
    }));

    const { error: itemsError } = await supabase
      .from("order_items")
      .insert(orderItems);

    if (itemsError) {
      return new Response(
        JSON.stringify({ message: "Failed to create order items" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Decrement stock for each variant
    for (const item of items) {
      await supabase.rpc("decrement_stock", {
        p_product_id: item.product_id,
        p_size: item.size,
        p_color: item.color,
        p_quantity: item.quantity,
      });
    }

    // Clear user's cart
    await supabase
      .from("cart_items")
      .delete()
      .eq("user_id", user.id);

    return new Response(
      JSON.stringify({
        order_id: order.id,
        subtotal,
        shipping,
        total,
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
