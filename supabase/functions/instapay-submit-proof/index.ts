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
import { enforceRateLimit } from "../_shared/rate_limit.ts";

const MAX_PROOF_BYTES = 5 * 1024 * 1024;
const MAX_REFERENCE_LENGTH = 64;

function hasImageSignature(bytes: Uint8Array, ext: string): boolean {
  if (ext === "png") {
    return bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
      bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d &&
      bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
  }
  if (ext === "jpg" || ext === "jpeg") {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  if (ext === "webp") {
    return bytes.length >= 12 && String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

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
    // Rate limit (audit 2026-09-13): 10 proof submissions per user
    // per hour, checked before any body parsing or upload work.
    const rateLimited = await enforceRateLimit(
      req,
      (fn, args) => supabase.rpc(fn, args),
      { id: user.id, kind: "proof:user", limit: 10, windowSeconds: 3600 },
    );
    if (rateLimited) return rateLimited;

    const rawBody = await req.text();
    if (rawBody.length > Math.ceil((MAX_PROOF_BYTES * 4) / 3) + 1024) {
      return new Response(JSON.stringify({ message: "Proof too large" }), {
        status: 413,
        headers: jsonHeadersFor(req),
      });
    }
    let body: Record<string, unknown>;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return new Response(JSON.stringify({ message: "Invalid JSON body" }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }
    const orderId = typeof body.order_id === "string" ? body.order_id : "";
    const proofBase64 = typeof body.proof_base64 === "string"
      ? body.proof_base64
      : "";
    const reference = typeof body.reference === "string"
      ? body.reference.trim()
      : "";
    if (reference.length > MAX_REFERENCE_LENGTH) {
      return new Response(JSON.stringify({ message: "Reference too long" }), {
        status: 400,
        headers: jsonHeadersFor(req),
      });
    }
    const EXT_CONTENT_TYPES: Record<string, string> = {
      png: "image/png",
      jpg: "image/jpeg",
      jpeg: "image/jpeg",
      webp: "image/webp",
    };
    const fileExt = typeof body.file_ext === "string"
      ? body.file_ext.trim().toLowerCase()
      : "png";
    const contentType = EXT_CONTENT_TYPES[fileExt];

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

    // Cap proofs per payment (audit 2026-09-13): at most 5 rows per
    // payment — legitimate re-submissions after a failed review still
    // work, but a single payment cannot be spammed with 5 MB uploads.
    // RLS (041) scopes the count to the caller's own rows.
    const { count: proofCount } = await supabase
      .from("instapay_proofs")
      .select("id", { count: "exact", head: true })
      .eq("payment_id", payment.id);
    if ((proofCount ?? 0) >= 5) {
      return new Response(
        JSON.stringify({ message: "Proof limit reached for this payment" }),
        { status: 429, headers: jsonHeadersFor(req) },
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

    if (!contentType) {
      return new Response(
        JSON.stringify({ message: "Unsupported proof format" }),
        {
          status: 400,
          headers: jsonHeadersFor(req),
        },
      );
    }

    if (!hasImageSignature(bytes, fileExt)) {
      return new Response(
        JSON.stringify({ message: "Proof content does not match format" }),
        {
          status: 400,
          headers: jsonHeadersFor(req),
        },
      );
    }

    // Upload to the private bucket under the caller's own folder —
    // storage RLS (041) enforces the same layout for reads.
    const storagePath = `${user.id}/${payment.id}/${Date.now()}.${fileExt}`;
    const { error: uploadError } = await supabase.storage
      .from("instapay-proofs")
      .upload(storagePath, bytes, { contentType });

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
      await supabase.storage.from("instapay-proofs").remove([storagePath]);
      console.error("instapay-submit-proof: insert failed");
      const status = insertError?.code === "23505" ? 409 : 500;
      return new Response(
        JSON.stringify({
          message: status === 409 ? "A proof is already pending" : "Insert failed",
        }),
        { status, headers: jsonHeadersFor(req) },
      );
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
