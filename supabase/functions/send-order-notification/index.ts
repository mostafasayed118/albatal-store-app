// ============================================================
// Supabase Edge Function: send-order-notification
//
// Sends localized (en/ar) email notifications for order status
// changes through Resend.
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
//
// Provider configuration:
//   RESEND_API_KEY  required to send; when absent the function
//                   returns 200 { skipped: true } before any
//                   notifications row is inserted.
//   RESEND_FROM     optional sender; defaults to the Resend
//                   onboarding sender.
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersFor, jsonHeadersFor, requireCors } from "../_shared/cors.ts";
import {
  constantTimeEquals,
  requireSecret,
} from "../_shared/secrets.ts";

type LocalizedTemplate = {
  en: { subject: string; body: string };
  ar: { subject: string; body: string };
};

// Email templates for different order events.
// Subject/body use only the order id prefix to avoid leaking
// full ids in logs or notification rows.
const templates: Record<string, LocalizedTemplate> = {
  order_placed: {
    en: {
      subject: "Order Confirmed - #{orderId}",
      body:
        "Thank you for your order! Your order #{orderId} has been received and is being processed. Total: {total} EGP",
    },
    ar: {
      subject: "تم تأكيد الطلب - #{orderId}",
      body:
        "شكرًا لطلبك! تم استلام طلبك #{orderId} وهو قيد المعالجة. الإجمالي: {total} ج.م",
    },
  },
  payment_confirmed: {
    en: {
      subject: "Payment Confirmed - #{orderId}",
      body: "Your payment of {total} EGP has been confirmed for order #{orderId}.",
    },
    ar: {
      subject: "تم تأكيد الدفع - #{orderId}",
      body: "تم تأكيد دفعتك بمبلغ {total} ج.م للطلب #{orderId}.",
    },
  },
  payment_failed: {
    en: {
      subject: "Payment Failed - #{orderId}",
      body:
        "Your payment for order #{orderId} could not be processed. Please try again or contact support.",
    },
    ar: {
      subject: "فشل الدفع - #{orderId}",
      body:
        "تعذر معالجة دفعتك للطلب #{orderId}. يرجى المحاولة مرة أخرى أو التواصل مع الدعم.",
    },
  },
  order_shipped: {
    en: {
      subject: "Order Shipped - #{orderId}",
      body: "Your order #{orderId} has been shipped! Tracking: {tracking}",
    },
    ar: {
      subject: "تم شحن الطلب - #{orderId}",
      body: "تم شحن طلبك #{orderId}! رقم التتبع: {tracking}",
    },
  },
  order_delivered: {
    en: {
      subject: "Order Delivered - #{orderId}",
      body:
        "Your order #{orderId} has been delivered. Thank you for shopping with Al Batal Elite!",
    },
    ar: {
      subject: "تم توصيل الطلب - #{orderId}",
      body: "تم توصيل طلبك #{orderId}. شكرًا لتسوقك من البطل إيليت!",
    },
  },
  order_cancelled: {
    en: {
      subject: "Order Cancelled - #{orderId}",
      body:
        "Your order #{orderId} has been cancelled. If you have questions, please contact support.",
    },
    ar: {
      subject: "تم إلغاء الطلب - #{orderId}",
      body:
        "تم إلغاء طلبك #{orderId}. إذا كانت لديك أسئلة، يرجى التواصل مع الدعم.",
    },
  },
};

const DEFAULT_FROM = "Al Batal Elite <onboarding@resend.dev>";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function textToHtml(value: string): string {
  return escapeHtml(value).replace(/\r?\n/g, "<br>");
}

Deno.serve(async (req) => {
  // Fail closed on CORS misconfiguration.
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }

  try {
    // ─── Internal authorization (MEDIUM-04) ────────────────
    // Only callers that present the server-side internal key
    // may create notifications. The key is never shipped to
    // Flutter.
    const keyFail = requireSecret(req, "NOTIFICATIONS_INTERNAL_KEY");
    if (keyFail) return keyFail;
    const expectedKey = Deno.env.get("NOTIFICATIONS_INTERNAL_KEY") as string;

    const providedKey = req.headers.get("x-internal-key") ?? "";
    // Constant-time compare so the key cannot be timed.
    if (!constantTimeEquals(providedKey, expectedKey)) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Parse + validate request ──────────────────────────
    const {
      order_id,
      event,
      recipient_email,
      recipient_name,
      total,
      tracking,
      locale,
    } = await req.json();

    if (!order_id || !event || !recipient_email) {
      return new Response(
        JSON.stringify({ message: "Missing required fields" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    if (
      locale !== undefined && locale !== null && locale !== "en" &&
      locale !== "ar"
    ) {
      return new Response(
        JSON.stringify({ message: "Invalid locale" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    if (typeof event !== "string" || !Object.hasOwn(templates, event)) {
      return new Response(
        JSON.stringify({ message: "Unknown event" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }
    const template = templates[event];

    const lang = locale === "ar" ? "ar" : "en";
    const copy = template[lang];

    // Use only the order id prefix to avoid leaking full ids.
    const orderPrefix = String(order_id).substring(0, 8);
    const subject = copy.subject.replace("{orderId}", orderPrefix);
    const body = copy.body
      .replace(/{orderId}/g, orderPrefix)
      .replace(/{total}/g, total?.toString() ?? "0")
      .replace(/{tracking}/g, tracking || "N/A");

    // No email provider configured: skip cleanly BEFORE the audit
    // row is inserted, so an unconfigured deployment adds no noise.
    const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
    if (!resendApiKey) {
      return new Response(
        JSON.stringify({
          skipped: true,
          reason: "email_not_configured",
          event,
        }),
        { status: 200, headers: jsonHeadersFor(req) },
      );
    }

    // Safe audit log — no recipient email, no payment details.
    console.log(
      `send-order-notification: event=${event} locale=${lang} order=${orderPrefix}`,
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    if (!supabaseUrl) {
      console.error("send-order-notification: SUPABASE_URL is not configured");
      return new Response(
        JSON.stringify({ message: "Server configuration error" }),
        { status: 503, headers: jsonHeadersFor(req) },
      );
    }

    const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
    if (serviceRoleFail) return serviceRoleFail;

    const supabase = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string,
    );

    // Audit trail: the row starts as pending and is finalized after
    // the provider responds.
    const { data: record, error: insertError } = await supabase
      .from("notifications")
      .insert({
        order_id: order_id,
        type: event,
        recipient_email: recipient_email,
        recipient_name: recipient_name,
        subject: subject,
        body: body,
        status: "pending",
      })
      .select("id")
      .single();

    if (insertError || !record) {
      console.error("send-order-notification: failed to record notification");
      return new Response(
        JSON.stringify({ message: "Internal server error" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }

    let res: Response;
    try {
      res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: Deno.env.get("RESEND_FROM") ?? DEFAULT_FROM,
          to: [recipient_email],
          subject: subject,
          text: body,
          html: textToHtml(body),
        }),
      });
    } catch (_error) {
      // A thrown provider call must still finalize the audit row.
      console.error("send-order-notification: provider request failed");
      const { error: failError } = await supabase
        .from("notifications")
        .update({ status: "failed" })
        .eq("id", record.id);
      if (failError) {
        console.error("send-order-notification: status update failed");
      }
      return new Response(
        JSON.stringify({ message: "Email delivery failed." }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }

    if (!res.ok) {
      const { error: failError } = await supabase
        .from("notifications")
        .update({ status: "failed" })
        .eq("id", record.id);
      if (failError) {
        console.error("send-order-notification: status update failed");
      }

      // Never log the provider payload, recipient, or credentials.
      console.error(
        `send-order-notification: provider rejected email (status ${res.status})`,
      );
      return new Response(
        JSON.stringify({ message: "Email delivery failed." }),
        { status: 502, headers: jsonHeadersFor(req) },
      );
    }

    const { error: sentError } = await supabase
      .from("notifications")
      .update({ status: "sent" })
      .eq("id", record.id);
    if (sentError) {
      console.error("send-order-notification: status update failed");
    }

    return new Response(
      JSON.stringify({ message: "Notification sent", event }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (_error) {
    console.error("send-order-notification: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeadersFor(req) }
    );
  }
});
