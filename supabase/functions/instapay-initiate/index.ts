// ============================================================
// Supabase Edge Function: instapay-initiate
// Returns the merchant InstaPay address + the server-authoritative
// payable amount for an order the caller owns, and guarantees the
// single pending 'instapay' payments row (migration 041).
//
// SECURITY (mirrors paymob-initiate):
//   * JWT-authenticated owner only; amounts read from the DB,
//     never from the client.
//   * The merchant InstaPay address comes from the env var
//     INSTAPAY_MERCHANT_ADDRESS — never hard-coded, never
//     client-supplied. Fails closed when missing.
//   * No secrets, no internal ids beyond what the flow needs.
//   * The method switch happens through
//     set_pending_order_payment_method (041 allowlist), which is
//     owner-checked and ensures the single pending row.
//
// Expects:
//   - Authorization header (authenticated user)
//   - body: { order_id }
//
// Returns:
//   - { payment_id, instapay_address, amount, amount_formatted }
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";

export async function handleInstapayInitiate(req: Request): Promise<Response> {
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ message: "Method not allowed" }), {
      status: 405,
      headers: jsonHeadersFor(req),
    });
  }

  try {
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
      return new Response(JSON.stringify({ message: "Unauthorized" }), {
        status: 401,
        headers: jsonHeadersFor(req),
      });
    }

    // Fail closed when the merchant address is not configured.
    const instapayAddress = (Deno.env.get("INSTAPAY_MERCHANT_ADDRESS") ?? "")
      .trim();
    if (!instapayAddress) {
      console.error(
        "instapay-initiate: INSTAPAY_MERCHANT_ADDRESS is not configured",
      );
      return new Response(
        JSON.stringify({ message: "InstaPay is not configured" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }

    const { order_id } = await req.json();
    if (!order_id) {
      return new Response(JSON.stringify({ message: "order_id is required" }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }

    // Owner-checked allowlist switch + single pending row guarantee
    // (041). The RPC re-verifies ownership and pending state under
    // its own logic — the DB is the authority, as with Paymob.
    const { data: switchResult, error: switchError } = await supabase.rpc(
      "set_pending_order_payment_method",
      { p_order_id: order_id, p_method: "instapay" },
    );

    if (switchError || !switchResult?.ok) {
      const code = switchResult?.code ?? "rpc_error";
      const status = code === "not_owner" ? 403 : 400;
      return new Response(JSON.stringify({ message: code }), {
        status,
        headers: jsonHeadersFor(req),
      });
    }

    // Read the canonical order row (ownership re-checked in SQL).
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, status, payment_method, user_id, total")
      .eq("id", order_id)
      .eq("user_id", user.id)
      .single();

    if (orderError || !order) {
      return new Response(JSON.stringify({ message: "Order not found" }), {
        status: 404,
        headers: jsonHeadersFor(req),
      });
    }

    if (order.status !== "pending" || order.payment_method !== "instapay") {
      return new Response(
        JSON.stringify({ message: "Order is not pending InstaPay" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("id, amount")
      .eq("order_id", order_id)
      .eq("user_id", user.id)
      .eq("method", "instapay")
      .eq("status", "pending")
      .order("created_at")
      .limit(1)
      .single();

    if (paymentError || !payment) {
      return new Response(
        JSON.stringify({ message: "Pending InstaPay payment not found" }),
        { status: 404, headers: jsonHeadersFor(req) },
      );
    }

    return new Response(
      JSON.stringify({
        payment_id: payment.id,
        instapay_address: instapayAddress,
        amount: payment.amount,
        amount_formatted: `${Math.round(payment.amount / 100)} EGP`,
      }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (_err) {
    // Generic error — never leak internals.
    return new Response(JSON.stringify({ message: "Internal error" }), {
      status: 500,
      headers: jsonHeadersFor(req),
    });
  }
}

// Supabase executes this module as the function entrypoint. Keeping handler
// registration behind import.meta.main lets tests exercise the real request
// handler without opening a listener or changing deployed behavior.
if (import.meta.main) {
  Deno.serve(handleInstapayInitiate);
}
