// ============================================================
// Supabase Edge Function: instapay-submit-proof
// Records a customer's transfer proof (screenshot + optional
// reference) against the pending InstaPay payment for an order
// they own. Status stays 'pending' — success is decided ONLY by
// instapay-review (admin) or expiry.
//
// SECURITY:
//   * JWT-authenticated owner only; the pending 'instapay'
//     payments row is located server-side by (order, user) —
//     never accepted from the client.
//   * The screenshot is uploaded to the PRIVATE 'instapay-proofs'
//     bucket under the user's own folder (storage RLS enforces
//     the same layout); only the path is stored in the DB row.
//   * Body size guarded (max ~5 MB base64).
//   * Insert into instapay_proofs is RLS-guarded to
//     (owner, pending payment) — migration 041.
//
// Expects:
//   - Authorization header (authenticated user)
//   - JSON body: { order_id, proof_base64, reference? }
//
// Returns:
//   - { proof_id, payment_id, status: "pending" }
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";

const MAX_PROOF_BYTES = 5 * 1024 * 1024; // 5 MB decoded

export async function handleInstapaySubmitProof(
  req: Request,
): Promise<Response> {
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

    const body = await req.json();
    const orderId = typeof body.order_id === "string" ? body.order_id : "";
    const proofBase64 = typeof body.proof_base64 === "string"
      ? body.proof_base64
      : "";
    const reference = typeof body.reference === "string"
      ? body.reference.trim()
      : "";

    if (!orderId || !proofBase64) {
      return new Response(
        JSON.stringify({ message: "order_id and proof_base64 are required" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    // Size guard BEFORE decoding (base64 inflates ~4/3).
    if (proofBase64.length > Math.ceil((MAX_PROOF_BYTES * 4) / 3)) {
      return new Response(JSON.stringify({ message: "Proof too large" }), {
        status: 413,
        headers: jsonHeadersFor(req),
      });
    }

    // Locate the pending instapay payment server-side (owner-scoped).
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("id, status")
      .eq("order_id", orderId)
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

    // Decode and sanity-check the image payload.
    let bytes: Uint8Array;
    try {
      const binary = atob(proofBase64);
      bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    } catch {
      return new Response(
        JSON.stringify({ message: "Invalid proof encoding" }),
        {
          status: 400,
          headers: jsonHeadersFor(req),
        },
      );
    }

    if (bytes.byteLength === 0 || bytes.byteLength > MAX_PROOF_BYTES) {
      return new Response(JSON.stringify({ message: "Invalid proof size" }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }

    // Upload to the private bucket under the caller's own folder —
    // storage RLS (041) enforces the same layout for reads.
    const storagePath = `${user.id}/${payment.id}/${Date.now()}.png`;
    const { error: uploadError } = await supabase.storage
      .from("instapay-proofs")
      .upload(storagePath, bytes, { contentType: "image/png" });

    if (uploadError) {
      console.error("instapay-submit-proof: upload failed");
      return new Response(JSON.stringify({ message: "Upload failed" }), {
        status: 500,
        headers: jsonHeadersFor(req),
      });
    }

    // Record the proof. RLS (041) re-checks owner + pending payment.
    const { data: proof, error: insertError } = await supabase
      .from("instapay_proofs")
      .insert({
        payment_id: payment.id,
        storage_path: storagePath,
        reference: reference || null,
      })
      .select("id")
      .single();

    if (insertError || !proof) {
      console.error("instapay-submit-proof: insert failed");
      return new Response(JSON.stringify({ message: "Insert failed" }), {
        status: 500,
        headers: jsonHeadersFor(req),
      });
    }

    return new Response(
      JSON.stringify({
        proof_id: proof.id,
        payment_id: payment.id,
        status: "pending",
      }),
      { status: 201, headers: jsonHeadersFor(req) },
    );
  } catch (_err) {
    return new Response(JSON.stringify({ message: "Internal error" }), {
      status: 500,
      headers: jsonHeadersFor(req),
    });
  }
}

if (import.meta.main) {
  Deno.serve(handleInstapaySubmitProof);
}
