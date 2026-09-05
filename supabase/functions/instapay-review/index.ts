// ============================================================
// Supabase Edge Function: instapay-review
// Admin gate for InstaPay transfer proofs (D1: manual review).
// Approve => payments.success + orders.paid in ONE transaction,
// server-generated transaction id (migration 041 RPC). Reject =>
// payment.failed. The client NEVER decides success.
//
// SECURITY (mirrors delete-account's admin gate):
//   * JWT-authenticated caller; admin checked via
//     profiles.is_admin through the service-role client — a
//     non-admin (or tampered) JWT is refused with 403.
//   * The review itself runs through review_instapay_proof (041),
//     SECURITY DEFINER, which re-verifies admin from the JWT and
//     re-locks the payment/proof rows.
//   * Fail-closed on missing secrets; secrets never logged.
//
// Expects:
//   - Authorization header (admin user)
//   - body: { proof_id, approve, note? }
//
// Returns:
//   - { ok, code, payment_id?, order_id? }
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";

export async function handleInstapayReview(req: Request): Promise<Response> {
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

    // Authenticated (non-elevated) client to identify the caller.
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
    const proofId = typeof body.proof_id === "string" ? body.proof_id : "";
    const approve = body.approve === true;
    const note = typeof body.note === "string" ? body.note.trim() : null;

    if (!proofId || typeof body.approve !== "boolean") {
      return new Response(
        JSON.stringify({ message: "proof_id and approve are required" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }

    // Admin gate (delete-account pattern): read is_admin through a
    // service-role client so RLS can never hide the flag from us.
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!serviceKey) {
      console.error("instapay-review: service role key missing");
      return new Response(JSON.stringify({ message: "Server misconfigured" }), {
        status: 500,
        headers: jsonHeadersFor(req),
      });
    }
    const adminClient = createClient(supabaseUrl, serviceKey);
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ message: "Forbidden" }), {
        status: 403,
        headers: jsonHeadersFor(req),
      });
    }
    if (profile.is_admin !== true) {
      return new Response(JSON.stringify({ message: "Forbidden" }), {
        status: 403,
        headers: jsonHeadersFor(req),
      });
    }

    // The RPC re-verifies admin from the JWT under its own logic and
    // performs the transactional state flip.
    const { data: result, error: rpcError } = await supabase.rpc(
      "review_instapay_proof",
      { p_proof_id: proofId, p_approve: approve, p_note: note },
    );

    if (rpcError || !result?.ok) {
      const code = result?.code ?? "rpc_error";
      const status = code === "admin_required"
        ? 403
        : code === "proof_not_found"
        ? 404
        : 400;
      return new Response(JSON.stringify({ message: code }), {
        status,
        headers: jsonHeadersFor(req),
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        code: result.code,
        payment_id: result.payment_id,
        order_id: result.order_id,
      }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (_err) {
    return new Response(JSON.stringify({ message: "Internal error" }), {
      status: 500,
      headers: jsonHeadersFor(req),
    });
  }
}

if (import.meta.main) {
  Deno.serve(handleInstapayReview);
}
