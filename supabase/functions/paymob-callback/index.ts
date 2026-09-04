// ============================================================
// Supabase Edge Function: paymob-callback
//
// SECURITY REPAIR (CRIT-01..04, HIGH-01..05):
//
//   1. Reject if the request method/body/content is invalid.
//   2. Fail CLOSED: if PAYMOB_HMAC_SECRET is missing or
//      malformed, return HTTP 503 WITHOUT touching any
//      payment/order/stock state. (CRIT-03)
//   3. Build the canonical HMAC payload from Paymob's
//      documented callback fields, in the exact documented
//      order, and compare in constant time. (HIGH-01, HIGH-02)
//   4. After HMAC verification, locate the existing payment
//      by `paymob_order_id` — never by provider order id on
//      `orders.id`. (CRIT-01, CRIT-04, HIGH-03)
//   5. NEVER insert an orphan/fallback payment. (CRIT-02)
//   6. Validate callback amount/currency against the internal
//      order total.
//   7. Delegate the state transition to the atomic
//      `process_paymob_callback` RPC so payment + order +
//      stock are mutated in one transaction. (HIGH-05)
//   8. A duplicate valid callback returns 2xx no-op.
//   9. Record only safe audit metadata; never log secrets or
//      card/customer data.
//
// HTTP results:
//   200 — valid first delivery OR valid duplicate no-op
//   400 — malformed/unmapped/invalid payload (no state change)
//   401 — invalid HMAC (no state change)
//   503 — server HMAC configuration unavailable
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  PAYMOB_HMAC_FIELDS,
  buildHmacPayload,
  canonicalValuesFromTransaction,
  verifyHmac,
} from "./hmac.ts";
import { corsHeadersFor, jsonHeadersFor } from "../_shared/cors.ts";
import { requireSecret } from "../_shared/secrets.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }

  // ─── 1. Reject non-POST / invalid content ──────────────
  // Paymob delivers the standard redirect callback as a
  // form-urlencoded POST. A GET or empty body is malformed.
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ message: "Method not allowed" }),
      { status: 400, headers: jsonHeadersFor(req) },
    );
  }

  try {
    const body = await req.text();
    if (!body || body.trim().length === 0) {
      return new Response(
        JSON.stringify({ message: "Empty callback body" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    const params = new URLSearchParams(body);

    // ─── 2. Fail closed on missing/malformed HMAC secret ──
    // CRIT-03: the secret MUST be present and non-empty. If
    // it is not, the server cannot verify any callback, so we
    // return 503 and change NO state.
    const hmacFail = requireSecret(req, "PAYMOB_HMAC_SECRET");
    if (hmacFail) return hmacFail;
    const hmacSecret = Deno.env.get("PAYMOB_HMAC_SECRET") as string;

    // ─── 3. Build canonical HMAC payload + verify ─────────
    // HIGH-02: build the payload from the documented fields
    // in the exact documented order, NOT from the raw query
    // string. The `hmac` field itself is never part of the
    // signed payload.
    // Paymob delivers TWO body shapes on this endpoint:
    //   • Redirect-style POST: flat form-urlencoded fields.
    //   • Transaction processed callback: an `obj` form field
    //     holding the transaction as JSON — with nested
    //     order.id and source_data.{pan,sub_type,type} — plus
    //     a separate `hmac` field. Raw-JSON bodies
    //     ({obj:…,hmac:…} or the transaction itself) are
    //     accepted as well. All shapes normalize into one flat
    //     string map before verification.
    const values: Record<string, string> = {};
    let receivedHmac = params.get("hmac") ?? "";
    // Paymob's processed callback sends the transaction as a raw
    // JSON body and carries the signature OUTSIDE the body — as a
    // query parameter on the callback URL (and some integrations
    // use a header). Resolution order: body field → query → header.
    const queryHmac = new URL(req.url).searchParams.get("hmac") ?? "";
    const headerHmac = req.headers.get("x-paymob-hmac") ?? "";
    const objRaw = params.get("obj");
    if (objRaw !== null) {
      try {
        const obj = JSON.parse(objRaw);
        if (typeof obj !== "object" || obj === null) throw new Error("bad obj");
        Object.assign(values, canonicalValuesFromTransaction(obj as Record<string, unknown>));
      } catch {
        console.error("paymob-callback: malformed obj payload");
        return new Response(
          JSON.stringify({ message: "Malformed obj payload" }),
          { status: 400, headers: jsonHeadersFor(req) },
        );
      }
    } else if (body.trimStart().startsWith("{")) {
      try {
        const parsed = JSON.parse(body) as Record<string, unknown>;
        const txn = ("amount_cents" in parsed)
          ? parsed
          : (parsed.obj as Record<string, unknown> | undefined);
        if (typeof txn !== "object" || txn === null) throw new Error("no txn");
        Object.assign(values, canonicalValuesFromTransaction(txn));
        receivedHmac = typeof parsed.hmac === "string" ? parsed.hmac : "";
      } catch {
        console.error("paymob-callback: malformed JSON body");
        return new Response(
          JSON.stringify({ message: "Malformed JSON body" }),
          { status: 400, headers: jsonHeadersFor(req) },
        );
      }
    } else {
      for (const field of PAYMOB_HMAC_FIELDS) {
        values[field] = params.get(field) ?? "";
      }
    }
    if (!receivedHmac) receivedHmac = queryHmac;
    if (!receivedHmac) receivedHmac = headerHmac;

    // HIGH-01: constant-time comparison.
    const ok = await verifyHmac(values, hmacSecret, receivedHmac);
    if (!ok) {
      // 401 — invalid signature. No state change.
      console.error("paymob-callback: HMAC verification failed");
      return new Response(
        JSON.stringify({ message: "Invalid signature" }),
        { status: 401, headers: jsonHeadersFor(req) },
      );
    }

    // ─── 4. Extract callback fields (now trusted) ─────────
    const paymobOrderId = values["order"];
    const paymobTxnId = values["id"];
    const amountCentsRaw = values["amount_cents"];
    const currency = values["currency"] || "EGP";
    const successStr = values["success"];
    const success = successStr === "true";

    if (!paymobOrderId || !paymobTxnId || !amountCentsRaw) {
      return new Response(
        JSON.stringify({ message: "Missing required callback fields" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    const amountCents = parseInt(amountCentsRaw, 10);
    if (Number.isNaN(amountCents)) {
      return new Response(
        JSON.stringify({ message: "Malformed amount_cents" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    // ─── 5. Delegate the state transition to the RPC ──────
    // The RPC runs as SECURITY DEFINER and performs the
    // payment/order/stock mutation in one transaction. It
    // locates the payment by paymob_order_id, validates
    // amount/currency, and is idempotent. We use the
    // service-role client because the callback is an
    // unauthenticated webhook from Paymob (HMAC is the auth).
    //
    // Fail closed when service_role key is missing.
    const serviceRoleFail = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
    if (serviceRoleFail) return serviceRoleFail;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string,
    );

    const { data, error } = await supabase.rpc("process_paymob_callback", {
      p_paymob_order_id: paymobOrderId,
      p_paymob_txn_id: paymobTxnId,
      p_amount_cents: amountCents,
      p_currency: currency,
      p_success: success,
    });

    if (error) {
      console.error("paymob-callback: RPC error", error.message);
      return new Response(
        JSON.stringify({ message: "Callback processing failed" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }

    const code = (data && data.code) ?? "unknown";
    const ok2 = Boolean(data && data.ok);

    // ─── 6. Map RPC result to HTTP ────────────────────────
    //   200 — valid first delivery OR valid duplicate no-op
    //   400 — unmapped payment / amount mismatch / order not
    //         found (no state change happened)
    if (ok2 && (code === "success" || code === "failed" || code === "already_processed")) {
      // Safe audit log — no secrets, no card data, no PII.
      console.log(
        `paymob-callback: processed order=${paymobOrderId} code=${code}`,
      );
      return new Response(
        JSON.stringify({ message: "Callback processed", code }),
        { status: 200, headers: jsonHeadersFor(req) },
      );
    }

    // 400 — unmapped_payment / amount_mismatch / currency_mismatch / order_not_found
    console.log(
      `paymob-callback: rejected order=${paymobOrderId} code=${code}`,
    );
    return new Response(
      JSON.stringify({ message: "Callback rejected", code }),
      { status: 400, headers: jsonHeadersFor(req) },
    );
  } catch (_error) {
    console.error("paymob-callback: unhandled error");
    return new Response(
      JSON.stringify({ message: "Internal server error" }),
      { status: 500, headers: jsonHeadersFor(req) }
    );
  }
});

// Exported for unit tests.
export { buildHmacPayload, PAYMOB_HMAC_FIELDS };
