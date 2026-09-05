// ============================================================
// Supabase Edge Function: delete-account
// Self-service account deletion (UX-043).
//
// SECURITY:
//   * The caller must present their OWN valid user JWT. The
//     requested userId must equal the verified session user —
//     no user can delete another account.
//   * Admin accounts (profiles.is_admin = true) are REFUSED:
//     store operators must not self-delete through the app
//     (decision A).
//   * The destructive delete runs with the service role AFTER
//     the checks above. Service key is never exposed to clients.
//   * Deletion cascades: auth.users → profiles → addresses /
//     wishlists / cart_items. orders + payments are retained with
//     user_id set to NULL (migration 040, decision B) — their
//     content is self-contained snapshots.
//   * Fails closed on missing config; secrets never logged.
//
// Expects:
//   - Authorization header (authenticated user JWT)
//   - body: { userId }
//
// Returns:
//   - 200 { deleted: true }
//   - 4xx with a generic message on refusal/validation errors
// ============================================================

import "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeadersFor,
  jsonHeadersFor,
  requireCors,
} from "../_shared/cors.ts";
import { requireSecret } from "../_shared/secrets.ts";

async function handleDeleteAccount(req: Request): Promise<Response> {
  // Fail closed on CORS misconfiguration.
  const corsFail = requireCors(req);
  if (corsFail) return corsFail;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeadersFor(req) });
  }

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
    const userClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ message: "Unauthorized" }),
        { status: 401, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Validate request ────────────────────────────────────
    // Only self-deletion is allowed.
    const { userId } = await req.json();
    if (!userId || typeof userId !== "string") {
      return new Response(
        JSON.stringify({ message: "userId is required" }),
        { status: 400, headers: jsonHeadersFor(req) },
      );
    }
    if (userId !== user.id) {
      return new Response(
        JSON.stringify({ message: "Cannot delete another account" }),
        { status: 403, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Admin guard (decision A) ────────────────────────────
    const missing = requireSecret(req, "SUPABASE_SERVICE_ROLE_KEY");
    if (missing) return missing;

    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) {
      return new Response(
        JSON.stringify({ message: "Server error" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }
    if (profile?.is_admin === true) {
      return new Response(
        JSON.stringify({ message: "Admin accounts cannot be deleted" }),
        { status: 403, headers: jsonHeadersFor(req) },
      );
    }

    // ─── Delete ──────────────────────────────────────────────
    // admin.deleteUser removes the auth user; migration 040 lets
    // the cascade erase profiles/addresses/wishlists/cart_items
    // while orders + payments survive with user_id set to NULL.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      user.id,
    );

    if (deleteError) {
      return new Response(
        JSON.stringify({ message: "Server error" }),
        { status: 500, headers: jsonHeadersFor(req) },
      );
    }

    return new Response(
      JSON.stringify({ deleted: true }),
      { status: 200, headers: jsonHeadersFor(req) },
    );
  } catch (err) {
    console.error("delete-account: unexpected error", err);
    return new Response(
      JSON.stringify({ message: "Server error" }),
      { status: 500, headers: jsonHeadersFor(req) },
    );
  }
}

Deno.serve(handleDeleteAccount);
