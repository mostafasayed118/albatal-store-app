// ============================================================
// Supabase Edge Function: send-order-notification
//
// Sends email notifications for order status changes.
//
// SECURITY REPAIR (MEDIUM-04):
//   This endpoint must NOT accept arbitrary public POSTs —
//   otherwise anyone can create notification rows for any
//   order/email. It now requires an internal authorization
//   header that only server-side callers (the Edge Functions
//   in this project, or a database trigger invoking it via
//   pg_net) can produce.
//
//   Authorization model:
//     The caller MUST send `x-internal-key` matching the
//     `NOTIFICATIONS_INTERNAL_KEY` server secret. This secret
//     lives ONLY in Edge Function environment variables and
//     is never shipped to Flutter. Public callers without
//     the key receive 401.
//
//   In addition:
//     * recipient_email is never echoed back in error
//       responses or logs,
//     * payment details are not logged,
//     * only the order id prefix (first 8 chars) is used in
//       subject/body to avoid leaking full ids in logs.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonHeaders } from "../_shared/cors.ts";

// Email templates for different order events.
// Subject/body use only the order id prefix to avoid leaking
// full ids in logs or notification rows.
const templates: Record<string, { subject: string; body: string }> = {
  order_placed: {
    subject: "Order Confirmed - #{orderId}",
    body: "Thank you for your order! Your order #{orderId} has been received and is being processed. Total: {total} EGP",
  },
  payment_confirmed: {
    subject: "Payment Confirmed - #{orderId}",
    body: "Your payment of {total} EGP has been confirmed for order #{orderId}.",
  },
  payment_failed: {
    subject: "Payment Failed - #{orderId}",
    body: "Your payment for order #{orderId} could not be processed. Please try again or contact support.",
  },
  order_shipped: {
    subject: "Order Shipped - #{orderId}",
    body: "Your order #{orderId} has been shipped! Tracking: {tracking}",
  },
  order_delivered: {
    subject: "Order Delivered - #{orderId}",
    body: "Your order #{orderId} has been delivered. Thank you for shopping with Al Batal Elite!",
  },
  order_cancelled: {
    subject: "Order Cancelled - #{orderId}",
    body: "Your order #{orderId} has been cancelled. If you have questions, please contact support.",
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ─── Internal authorization (MEDIUM-04) ────────────────
    // Only callers that present the server-side internal key
    // may create notifications. The key is never shipped to
    // Flutter.
    const expectedKey = Deno.env.get("NOTIFICATIONS_INTERNAL_KEY");
    if (!expectedKey || expectedKey.trim().length === 0) {
      // The server is not configured to send notifications —
      // fail closed.
      console.error(
        "send-order-notification: NOTIFICATIONS_INTERNAL_KEY is not configured",
      );
      return new Response(
        JSON.stringify({ message: "Notification service unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const providedKey = req.headers.get("x-internal-key") ?? "";
    // Constant-time compare so the key cannot be timed.
    if (providedKey.length !== expectedKey.length) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    let diff = 0;
    for (let i = 0; i < expectedKey.length; i++) {
      diff |= providedKey.charCodeAt(i) ^ expectedKey.charCodeAt(i);
    }
    if (diff !== 0) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ─── Parse + validate request ──────────────────────────
    const { order_id, event, recipient_email, recipient_name, total, tracking } =
      await req.json();

    if (!order_id || !event || !recipient_email) {
      return new Response(
        JSON.stringify({ message: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const template = templates[event];
    if (!template) {
      return new Response(
        JSON.stringify({ message: "Unknown event" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Use only the order id prefix to avoid leaking full ids.
    const orderPrefix = String(order_id).substring(0, 8);
    const subject = template.subject.replace("{orderId}", orderPrefix);
    const body = template.body
      .replace(/{orderId}/g, orderPrefix)
      .replace(/{total}/g, total?.toString() ?? "0")
      .replace(/{tracking}/g, tracking || "N/A");

    // Safe audit log — no recipient email, no payment details.
    console.log(`send-order-notification: event=${event} order=${orderPrefix}`);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Store notification record.
    await supabase.from("notifications").insert({
      order_id: order_id,
      type: event,
      recipient_email: recipient_email,
      recipient_name: recipient_name,
      subject: subject,
      body: body,
      status: "sent",
    });

    return new Response(
      JSON.stringify({ message: "Notification sent", event }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (_error) {
    console.error("send-order-notification: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeaders() }
    );
  }
});
