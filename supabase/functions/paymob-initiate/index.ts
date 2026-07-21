// ============================================================
// Supabase Edge Function: paymob-initiate
// Single-call Paymob payment initiation.
//
// SECURITY REPAIR (CRIT-01, HIGH-03):
//   * Accepts an existing canonical internal order (created
//     by the `create_checkout_order` RPC) and reads the
//     payable amount, currency, customer identity, and order
//     state from the database — never from the client.
//   * Creates ONE pending internal payment row linked to the
//     internal order, with `paymob_order_id` NULL until the
//     Paymob provider order is created.
//   * Creates the Paymob provider order server-side.
//   * Persists the REAL Paymob provider order id in
//     `payments.paymob_order_id` BEFORE returning the payment
//     URL to Flutter. The callback later locates the payment
//     by this provider order id.
//   * NEVER sets a fake provider transaction id during
//     initiation. `transaction_id` stays NULL until the
//     verified callback writes Paymob's real transaction id.
//   * Returns only the minimum safe client information
//     (checkout_url). No secrets, no provider order id.
//
// Expects:
//   - Authorization header (authenticated user)
//   - body: { order_id }
//
// Returns:
//   - { checkout_url }
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonHeaders } from "../_shared/cors.ts";

/// Maximum time (ms) to wait for a single Paymob HTTP call.
const PAYMOB_TIMEOUT_MS = 10_000;

/// Maximum allowed response body size (bytes) from Paymob.
/// Prevents memory exhaustion from malformed upstream payloads.
const MAX_RESPONSE_BYTES = 64 * 1024; // 64 KB

/// Fetch with a timeout and response size guard.
async function fetchWithGuard(
  url: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PAYMOB_TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    // Check Content-Length before consuming the body.
    const contentLength = Number(response.headers.get("content-length") ?? 0);
    if (contentLength > MAX_RESPONSE_BYTES) {
      throw new Error(`Response too large: ${contentLength} bytes`);
    }
    return response;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Reject non-POST requests.
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ message: "Method not allowed" }),
      { status: 405, headers: jsonHeaders() },
    );
  }

  try {
    // ─── Auth check ──────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ message: "Authentication required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Validate request ────────────────────────────────────
    // The client sends only the internal order id. Amount,
    // currency, and customer identity are read from the DB.
    const { order_id } = await req.json();

    if (!order_id) {
      return new Response(
        JSON.stringify({ message: "order_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Read canonical order from the server database ───────
    // The order was created by `create_checkout_order` as
    // `pending`. We verify ownership, status, and read the
    // authoritative total + payment method.
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, status, total, payment_method, user_id, address_snapshot")
      .eq("id", order_id)
      .eq("user_id", user.id)
      .single();

    if (orderError || !order) {
      return new Response(
        JSON.stringify({ message: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (order.status !== "pending") {
      return new Response(
        JSON.stringify({ message: "Order is not pending" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // The server-computed total is the source of truth.
    const amountCents = order.total as number;
    const currency = "EGP";

    // Build billing_data from the order's address snapshot.
    // Falls back to generic placeholders only when a field is
    // genuinely absent — never leaks real customer data.
    const addr = order.address_snapshot as Record<string, string> | null;
    const recipientParts = (addr?.recipient ?? "Customer").split(" ");
    const firstName = recipientParts[0] || "Customer";
    const lastName = recipientParts.slice(1).join(" ") || "Customer";
    const billingData = {
      apartment: addr?.apartment ?? "NA",
      email: user.email ?? "customer@example.com",
      floor: addr?.floor ?? "NA",
      first_name: firstName,
      street: addr?.line ?? "NA",
      building: addr?.building ?? "NA",
      phone_number: addr?.phone ?? "+201000000000",
      shipping_method: "NA",
      postal_code: addr?.postalCode ?? "NA",
      city: addr?.city ?? "Cairo",
      country: addr?.country ?? "EG",
      last_name: lastName,
      state: addr?.city ?? "Cairo",
    };

    // ─── Get Paymob credentials ──────────────────────────────
    const apiKey = Deno.env.get("PAYMOB_API_KEY");
    const integrationId = Deno.env.get("PAYMOB_INTEGRATION_ID");
    const iframeId = Deno.env.get("PAYMOB_IFRAME_ID");
    if (!apiKey || !integrationId || !iframeId) {
      console.error("paymob-initiate: Paymob credentials not configured");
      return new Response(
        JSON.stringify({ message: "Payment provider not configured" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Create/find one pending internal payment ───────────
    // A pending payment may already exist if the user retried
    // initiation for the same order. We reuse it so we never
    // have two pending payments for one order.
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id, paymob_order_id, status")
      .eq("order_id", order_id)
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    let paymentId: string;

    if (existingPayment && existingPayment.status === "pending") {
      // Reuse the existing pending payment. If it already has
      // a paymob_order_id from a previous initiation, we keep
      // it so a duplicate initiation does not create a second
      // provider order.
      if (existingPayment.paymob_order_id) {
        // We already have a provider order for this payment.
        // Re-issue a payment key for the SAME provider order
        // instead of creating a new one.
        paymentId = existingPayment.id as string;
        const reused = await reissuePaymentKey(
          apiKey,
          integrationId,
          existingPayment.paymob_order_id as string,
          amountCents,
          user.email ?? "customer@example.com",
          billingData,
        );
        if (!reused.ok) {
          return new Response(
            JSON.stringify({ message: reused.message }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${reused.token}`;
        return new Response(
          JSON.stringify({ checkout_url: checkoutUrl }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      paymentId = existingPayment.id as string;
    } else {
      // Create a fresh pending payment. transaction_id stays
      // NULL — it is written exactly once by the verified
      // callback.
      const { data: newPayment, error: payInsertError } = await supabase
        .from("payments")
        .insert({
          order_id: order_id,
          user_id: user.id,
          method: "paymob_card",
          amount: amountCents,
          status: "pending",
        })
        .select("id")
        .single();
      if (payInsertError || !newPayment) {
        console.error("paymob-initiate: failed to create payment row");
        return new Response(
          JSON.stringify({ message: "Failed to create payment record" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      paymentId = newPayment.id as string;
    }

    // ─── Step 1: Paymob auth token ──────────────────────────
    const authResponse = await fetchWithGuard("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    });
    const authData = await authResponse.json();
    if (!authData.token) {
      return new Response(
        JSON.stringify({ message: "Failed to get Paymob auth token" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Step 2: Register Paymob provider order ─────────────
    const paymobOrderResponse = await fetchWithGuard(
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
          amount_cents: amountCents,
          currency,
          items: [],
        }),
      },
    );
    const paymobOrderData = await paymobOrderResponse.json();
    if (!paymobOrderData.id) {
      console.error("paymob-initiate: failed to register Paymob order");
      return new Response(
        JSON.stringify({ message: "Failed to register payment order" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const paymobOrderId = String(paymobOrderData.id);

    // ─── Persist the REAL Paymob provider order id ──────────
    // HIGH-03: store the provider order id on the payment row
    // BEFORE returning the checkout URL. The callback will
    // locate this payment by paymob_order_id.
    const { data: providerOrderUpdate, error: updateError } = await supabase
      .rpc("set_payment_provider_order_id", {
        p_payment_id: paymentId,
        p_paymob_order_id: paymobOrderId,
      });

    if (updateError || !providerOrderUpdate?.ok) {
      console.error("paymob-initiate: failed to persist paymob_order_id");
      return new Response(
        JSON.stringify({ message: "Failed to persist payment order" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Step 3: Payment key ─────────────────────────────────
    const keyResponse = await fetchWithGuard(
      "https://accept.paymob.com/api/acceptance/payment_keys",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${authData.token}`,
        },
        body: JSON.stringify({
          auth_token: authData.token,
          amount_cents: amountCents,
          expiration: 3600,
          order_id: paymobOrderId,
          billing_data: billingData,
          integration_id: integrationId,
        }),
      },
    );
    const keyData = await keyResponse.json();
    if (!keyData.token) {
      return new Response(
        JSON.stringify({ message: "Failed to get payment key" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Return minimum safe client info ────────────────────
    // Only the checkout URL. No secrets, no provider order id,
    // no payment key exposure beyond the iframe token.
    const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${keyData.token}`;

    return new Response(
      JSON.stringify({ checkout_url: checkoutUrl }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (_error) {
    // SECURITY: Never log raw error — it may contain Paymob tokens
    // or request body details. Log a safe prefix for correlation.
    console.error("paymob-initiate: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeaders() },
    );
  }
});

// ─── Helper: re-issue a payment key for an existing provider order
// Used when the user retries initiation for an order that already
// has a paymob_order_id. We do NOT create a second provider order.
async function reissuePaymentKey(
  apiKey: string,
  integrationId: string,
  paymobOrderId: string,
  amountCents: number,
  email: string,
  billingData: Record<string, string>,
): Promise<{ ok: boolean; token?: string; message?: string }> {
  const authResponse = await fetchWithGuard("https://accept.paymob.com/api/auth/tokens", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ api_key: apiKey }),
  });
  const authData = await authResponse.json();
  if (!authData.token) {
    return { ok: false, message: "Failed to get Paymob auth token" };
  }
  const keyResponse = await fetchWithGuard(
    "https://accept.paymob.com/api/acceptance/payment_keys",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authData.token}`,
      },
      body: JSON.stringify({
        auth_token: authData.token,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: paymobOrderId,
        billing_data: billingData,
        integration_id: integrationId,
      }),
    },
  );
  const keyData = await keyResponse.json();
  if (!keyData.token) {
    return { ok: false, message: "Failed to get payment key" };
  }
  return { ok: true, token: keyData.token };
}
