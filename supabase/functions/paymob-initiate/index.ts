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
import { corsHeadersFor, jsonHeadersFor, requireCors } from "../_shared/cors.ts";
import { requireSecret } from "../_shared/secrets.ts";

/// Maximum time (ms) to wait for a single Paymob HTTP call.
const PAYMOB_TIMEOUT_MS = 8_000;

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
  // Fail closed on CORS misconfiguration.
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }

  // Reject non-POST requests.
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ message: "Method not allowed" }),
      { status: 405, headers: jsonHeadersFor(req) },
    );
  }

  try {
    // ─── Auth check ──────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ message: "Authentication required" }),
        { status: 401, headers: jsonHeadersFor(req) },
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
        { status: 401, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Validate request ────────────────────────────────────
    // The client sends only the internal order id. Amount,
    // currency, and customer identity are read from the DB.
    const { order_id } = await req.json();

    if (!order_id) {
      return new Response(
        JSON.stringify({ message: "order_id is required" }),
        { status: 400, headers: jsonHeadersFor(req) },
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
        { status: 404, headers: jsonHeadersFor(req) },
      );
    }

    if (order.status !== "pending") {
      return new Response(
        JSON.stringify({ message: "Order is not pending" }),
        { status: 400, headers: jsonHeadersFor(req) },
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
    // Fail closed when required Paymob credentials are missing.
    const apiKeyFail = requireSecret(req, "PAYMOB_API_KEY");
    if (apiKeyFail) return apiKeyFail;
    const integrationId = Deno.env.get("PAYMOB_INTEGRATION_ID");
    const iframeId = Deno.env.get("PAYMOB_IFRAME_ID");
    if (!integrationId || !iframeId) {
      console.error("paymob-initiate: Paymob credentials not configured");
      return new Response(
        JSON.stringify({ message: "Payment provider not configured" }),
        { status: 503, headers: jsonHeadersFor(req) },
      );
    }
    const apiKey = Deno.env.get("PAYMOB_API_KEY") as string;

    // ─── Create/find one pending internal payment ───────────
    console.log("paymob-initiate: Checking for existing payment for order", order_id);
    const { data: existingPayment, error: existingPayError } = await supabase
      .from("payments")
      .select("id, paymob_order_id, status")
      .eq("order_id", order_id)
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existingPayError) {
      console.error("paymob-initiate: Error checking existing payment", JSON.stringify(existingPayError));
    }

    let paymentId: string;

    if (existingPayment && existingPayment.status === "pending") {
      console.log("paymob-initiate: Found existing pending payment", existingPayment.id);
      if (existingPayment.paymob_order_id) {
        console.log("paymob-initiate: Reusing existing Paymob order", existingPayment.paymob_order_id);
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
          console.error("paymob-initiate: Failed to reissue payment key", reused.message);
          return new Response(
            JSON.stringify({ message: reused.message }),
            { status: 502, headers: jsonHeadersFor(req) },
          );
        }
        const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${reused.token}`;
        console.log("paymob-initiate: SUCCESS (reissue) - Returning checkout URL");
        return new Response(
          JSON.stringify({ checkout_url: checkoutUrl }),
          { status: 200, headers: jsonHeadersFor(req) },
        );
      }
      paymentId = existingPayment.id as string;
    } else {
      console.log("paymob-initiate: Creating new payment record");
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
        console.error("paymob-initiate: Failed to create payment row", JSON.stringify(payInsertError));
        return new Response(
          JSON.stringify({ message: "Failed to create payment record", error: payInsertError?.message }),
          { status: 500, headers: jsonHeadersFor(req) },
        );
      }
      paymentId = newPayment.id as string;
      console.log("paymob-initiate: Payment record created", paymentId);
    }

    // ─── Step 1: Paymob auth token ──────────────────────────
    console.log("paymob-initiate: Step 1 - Getting auth token from Paymob");
    console.log("paymob-initiate: API key length:", apiKey?.length);
    const authResponse = await fetchWithGuard("https://accept.paymob.com/api/auth/tokens", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    });
    console.log("paymob-initiate: Auth response status:", authResponse.status);
    const authData = await authResponse.json();
    console.log("paymob-initiate: Auth response:", JSON.stringify(authData).substring(0, 200));
    if (!authData.token) {
      console.error("paymob-initiate: Failed to get auth token", JSON.stringify(authData));
      return new Response(
        JSON.stringify({ message: "Failed to get Paymob auth token", details: authData }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }
    console.log("paymob-initiate: Auth token obtained successfully");

    // ─── Step 2: Register Paymob provider order ─────────────
    console.log("paymob-initiate: Step 2 - Registering order with Paymob");
    console.log("paymob-initiate: Amount:", amountCents, "Currency:", currency);
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
    console.log("paymob-initiate: Order response status:", paymobOrderResponse.status);
    const paymobOrderData = await paymobOrderResponse.json();
    console.log("paymob-initiate: Order response:", JSON.stringify(paymobOrderData).substring(0, 200));
    if (!paymobOrderData.id) {
      console.error("paymob-initiate: Failed to register order", JSON.stringify(paymobOrderData));
      return new Response(
        JSON.stringify({ message: "Failed to register payment order", details: paymobOrderData }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }
    console.log("paymob-initiate: Order registered with ID", paymobOrderData.id);

    const paymobOrderId = String(paymobOrderData.id);

    // ─── Persist the REAL Paymob provider order id ──────────
    console.log("paymob-initiate: Persisting Paymob order ID", paymobOrderId, "for payment", paymentId);
    const { data: providerOrderUpdate, error: updateError } = await supabase
      .rpc("set_payment_provider_order_id", {
        p_payment_id: paymentId,
        p_paymob_order_id: paymobOrderId,
      });

    if (updateError || !providerOrderUpdate?.ok) {
      console.error("paymob-initiate: Failed to persist paymob_order_id", JSON.stringify(updateError));
      return new Response(
        JSON.stringify({ message: "Failed to persist payment order", error: updateError?.message }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }
    console.log("paymob-initiate: Paymob order ID persisted successfully");

    // ─── Step 3: Payment key ─────────────────────────────────
    console.log("paymob-initiate: Step 3 - Getting payment key from Paymob");
    console.log("paymob-initiate: Integration ID:", integrationId);
    console.log("paymob-initiate: Paymob Order ID:", paymobOrderId);
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
          currency: currency,
          expiration: 3600,
          order_id: paymobOrderId,
          billing_data: billingData,
          integration_id: integrationId,
        }),
      },
    );
    console.log("paymob-initiate: Payment key response status:", keyResponse.status);
    const keyData = await keyResponse.json();
    console.log("paymob-initiate: Payment key response:", JSON.stringify(keyData).substring(0, 200));
    if (!keyData.token) {
      console.error("paymob-initiate: Failed to get payment key", JSON.stringify(keyData));
      return new Response(
        JSON.stringify({ message: "Failed to get payment key", details: keyData }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }
    console.log("paymob-initiate: Payment key obtained successfully");

    // ─── Return minimum safe client info ────────────────────
    const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${keyData.token}`;
    console.log("paymob-initiate: SUCCESS - Returning checkout URL");
    console.log("paymob-initiate: Checkout URL:", checkoutUrl);

    return new Response(
      JSON.stringify({ checkout_url: checkoutUrl }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (error) {
    console.error("paymob-initiate: Unhandled error", JSON.stringify(error));
    return new Response(
      JSON.stringify({ message: "Internal server error", error: String(error) }),
      { status: 500, headers: jsonHeadersFor(req) },
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
        currency: "EGP",
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
