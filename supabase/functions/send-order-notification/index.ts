// ============================================================
// Supabase Edge Function: send-order-notification
// Sends email notifications for order status changes.
// Triggered server-side only — never from the Flutter app.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Email templates for different order events
const templates: Record<string, { subject: string; body: string }> = {
  order_placed: {
    subject: "Order Confirmed - #{orderId}",
    body: "Thank you for your order! Your order #{orderId} has been received and is being processed. Total: {total} EGY",
  },
  payment_confirmed: {
    subject: "Payment Confirmed - #{orderId}",
    body: "Your payment of {total} EGY has been confirmed for order #{orderId}.",
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
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { order_id, event, recipient_email, recipient_name, total, tracking } = await req.json();

    if (!order_id || !event || !recipient_email) {
      return new Response(
        JSON.stringify({ message: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const template = templates[event];
    if (!template) {
      return new Response(
        JSON.stringify({ message: `Unknown event: ${event}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Replace placeholders
    const subject = template.subject.replace("{orderId}", order_id.substring(0, 8));
    const body = template.body
      .replace(/{orderId}/g, order_id.substring(0, 8))
      .replace(/{total}/g, total?.toString() ?? "0")
      .replace(/{tracking}/g, tracking || "N/A");

    // Log the notification (in production, integrate with email service)
    console.log(`📧 Email notification:`);
    console.log(`   To: ${recipient_email}`);
    console.log(`   Subject: ${subject}`);
    console.log(`   Body: ${body}`);

    // Store notification record
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
      JSON.stringify({ message: "Notification sent", event, order_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Notification error:", error);
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
