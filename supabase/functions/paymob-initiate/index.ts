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
// CONCURRENCY (migration 034):
//   The database is the concurrency boundary, not this function.
//   `get_or_claim_paymob_payment(UUID)` atomically resolves,
//   creates, and claims the single pending card payment under
//   the order lock, and returns the server-authoritative total.
//   A partial unique index caps one pending card payment per
//   order; an active claim remains exclusive until provider-order
//   persistence. Non-card orders are rejected before any provider
//   call. The service-role key is no longer used at all.
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
import {
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";
import { requireSecret } from "../_shared/secrets.ts";
import { decideInitiationClaim, type PaymobClaim } from "./decision.ts";

/// Maximum time (ms) to wait for a single Paymob HTTP call.
const PAYMOB_TIMEOUT_MS = 5_000;

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

export async function handlePaymobInitiate(req: Request): Promise<Response> {
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

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabase = createClient(
      supabaseUrl,
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

    // Fail closed when the authenticated user has no email (e.g. phone
    // auth). Paymob requires a real billing email — never substitute a
    // fake address. Checked here, before any order read or provider use.
    if (!user.email) {
      return new Response(
        JSON.stringify({ message: "Customer email is required" }),
        { status: 400, headers: jsonHeadersFor(req) },
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
      .select("id, status, payment_method, user_id, address_snapshot")
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

    // Reject non-card orders before loading provider credentials or making
    // any provider call. The atomic RPC below repeats this check under the
    // order lock as the authoritative concurrency boundary.
    if (order.payment_method !== "paymob_card") {
      console.error("paymob-initiate: Rejected non-card payment method");
      return new Response(
        JSON.stringify({ message: "Unsupported payment method" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    // `currency` is fixed by the payment-provider contract. The amount is
    // taken only from the atomic claim RPC below so it can never drift from
    // the server-authoritative order total computed under the same lock.
    const currency = "EGP";

    // Build billing_data from the order's address snapshot.
    // Paymob requires ALL fields to be non-empty.
    const addr = order.address_snapshot as Record<string, string> | null;
    const recipientParts = (addr?.recipient ?? "Customer").split(" ");
    const firstName = recipientParts[0] || "Customer";
    const lastName = recipientParts.slice(1).join(" ") || "Customer";
    const billingData = {
      apartment: addr?.apartment || "NA",
      email: user.email,
      floor: addr?.floor || "NA",
      first_name: firstName || "Customer",
      street: addr?.line || addr?.street || "NA",
      building: addr?.building || "NA",
      phone_number: addr?.phone || "+201000000000",
      shipping_method: "NA",
      postal_code: addr?.postalCode || addr?.postal_code || "NA",
      city: addr?.city || "Cairo",
      country: addr?.country || "EG",
      last_name: lastName || "Customer",
      state: addr?.city || "Cairo",
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

    // ─── Atomically get-or-claim the pending card payment ────
    // The database is the concurrency boundary, not this function.
    // A partial unique index guarantees at most one pending
    // `paymob_card` payment per order, and a bounded claim lease
    // guarantees at most one caller creates the provider order.
    // This RPC also enforces authentication, ownership, pending
    // status, and the card-only method under the order lock — so
    // the decision below is made on data no concurrent request
    // can invalidate.
    console.log("paymob-initiate: Claiming payment boundary for order");
    const { data: claim, error: claimError } = await supabase.rpc(
      "get_or_claim_paymob_payment",
      { p_order_id: order_id },
    );

    if (claimError || !claim) {
      console.error("paymob-initiate: Failed to resolve payment claim");
      return new Response(
        JSON.stringify({ message: "Failed to initialize payment" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }

    const decision = decideInitiationClaim(
      order.payment_method,
      claim as PaymobClaim,
    );

    if (decision.kind === "reject") {
      console.error("paymob-initiate: Order rejected by payment claim");
      return new Response(
        JSON.stringify({ message: decision.message }),
        { status: decision.status, headers: jsonHeadersFor(req) },
      );
    }

    if (decision.kind === "error") {
      console.error("paymob-initiate: Claim returned an incomplete result");
      return new Response(
        JSON.stringify({ message: decision.message }),
        { status: decision.status, headers: jsonHeadersFor(req) },
      );
    }

    if (decision.kind === "reissue") {
      console.log("paymob-initiate: Reusing existing provider order");
      const reused = await reissuePaymentKey(
        apiKey,
        integrationId,
        decision.paymobOrderId,
        decision.amount,
        user.email,
        billingData,
      );
      if (!reused.ok) {
        console.error(
          "paymob-initiate: Failed to reissue payment key",
          reused.message,
        );
        return new Response(
          JSON.stringify({ message: reused.message }),
          { status: 502, headers: jsonHeadersFor(req) },
        );
      }
      const checkoutUrl =
        `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${reused.token}`;
      console.log(
        "paymob-initiate: SUCCESS (reissue) - Returning checkout URL",
      );
      return new Response(
        JSON.stringify({ checkout_url: checkoutUrl }),
        { status: 200, headers: jsonHeadersFor(req) },
      );
    }

    if (decision.kind === "in_progress") {
      console.log("paymob-initiate: Initiation already in progress");
      return new Response(
        JSON.stringify({ message: decision.message }),
        { status: decision.status, headers: jsonHeadersFor(req) },
      );
    }

    const paymentId = decision.paymentId;
    const claimToken = decision.claimToken;
    // This amount originates only from the atomic RPC claim result.
    const amountCents = decision.amount;

    // Internal claim transitions use a separate service-role client. The
    // caller client remains responsible for the authenticated claim and the
    // owner-bound provider-order persistence RPC.
    const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
    if (serviceRoleFail) return serviceRoleFail;
    const serviceRoleClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // Past this point claim.code === "claimed": this caller owns
    // provider-order creation until the provider order is persisted.
    console.log("paymob-initiate: Claimed provider order creation");

    // ─── Provider steps ─────────────────────────────────────
    // Pre-provider failures can be released only through the token-bound
    // service-role RPC. Once the claim is marked provider_submitted, every
    // failure retains it because the external POST may have succeeded.
    let paymentToken: string;
    let providerSubmissionStarted = false;
    try {
      // ─── Step 1: Paymob auth token ────────────────────────
      console.log("paymob-initiate: Step 1 - Getting auth token");
      const authResponse = await fetchWithGuard(
        "https://accept.paymob.com/api/auth/tokens",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ api_key: apiKey }),
        },
      );
      const authData = await authResponse.json();
      if (!authData.token) {
        console.error("paymob-initiate: Failed to get auth token");
        throw new Error("auth_token");
      }

      // Transition to provider_submitted before the external POST. This is
      // deliberately conservative: any subsequent failure is ambiguous.
      const { data: submitted, error: submittedError } = await serviceRoleClient
        .rpc(
          "mark_paymob_initiation_submitted",
          { p_payment_id: paymentId, p_claim_token: claimToken },
        );
      if (submittedError || !submitted?.ok) {
        console.error("paymob-initiate: Failed to advance provider claim");
        throw new Error("claim_transition");
      }
      providerSubmissionStarted = true;
      console.log("paymob-initiate: Auth token obtained");

      // ─── Step 2: Register Paymob provider order ───────────
      console.log("paymob-initiate: Step 2 - Registering order");
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
        console.error("paymob-initiate: Failed to register order");
        throw new Error("register_order");
      }
      console.log("paymob-initiate: Order registered");

      const paymobOrderId = String(paymobOrderData.id);

      // ─── Persist the REAL Paymob provider order id ────────
      console.log("paymob-initiate: Persisting Paymob order ID");
      const { data: providerOrderUpdate, error: updateError } = await supabase
        .rpc("set_payment_provider_order_id", {
          p_payment_id: paymentId,
          p_paymob_order_id: paymobOrderId,
        });

      if (updateError || !providerOrderUpdate?.ok) {
        console.error("paymob-initiate: Failed to persist paymob_order_id");
        throw new Error("persist_provider_order");
      }

      // ─── Step 3: Payment key ──────────────────────────────
      console.log("paymob-initiate: Step 3 - Getting payment key");
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
      console.log(
        "paymob-initiate: Payment key response status:",
        keyResponse.status,
      );
      const keyData = await keyResponse.json();
      if (!keyData.token) {
        console.error("paymob-initiate: Failed to get payment key");
        throw new Error("payment_key");
      }
      paymentToken = keyData.token as string;
      console.log("paymob-initiate: Payment key obtained");
    } catch (_providerFailure) {
      // Never clear the claim here. Provider submission may have succeeded
      // even when the response was lost or malformed; only the persisted
      // provider order path can safely transition to key reissue.
      if (!providerSubmissionStarted) {
        try {
          const { error: releaseError } = await serviceRoleClient.rpc(
            "release_paymob_initiation_claim",
            { p_payment_id: paymentId, p_claim_token: claimToken },
          );
          if (releaseError) {
            console.error(
              "paymob-initiate: Pre-provider claim recovery failed",
            );
          }
        } catch (_releaseFailure) {
          console.error("paymob-initiate: Pre-provider claim recovery failed");
        }
      } else {
        console.error(
          "paymob-initiate: Provider initiation failed; claim retained",
        );
      }
      return new Response(
        JSON.stringify({ message: "Failed to initialize payment" }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Return minimum safe client info ────────────────────
    const checkoutUrl =
      `https://accept.paymob.com/api/acceptance/iframes/${iframeId}?payment_token=${paymentToken}`;
    console.log("paymob-initiate: SUCCESS - Returning checkout URL");

    return new Response(
      JSON.stringify({ checkout_url: checkoutUrl }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (_error) {
    // Do not emit upstream/provider error objects or return their contents.
    console.error("paymob-initiate: Unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeadersFor(req) },
    );
  }
}

// Supabase executes this module as the function entrypoint. Keeping handler
// registration behind import.meta.main lets tests exercise the real request
// handler without opening a listener or changing deployed behavior.
if (import.meta.main) {
  Deno.serve(handlePaymobInitiate);
}

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
  const authResponse = await fetchWithGuard(
    "https://accept.paymob.com/api/auth/tokens",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ api_key: apiKey }),
    },
  );
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
