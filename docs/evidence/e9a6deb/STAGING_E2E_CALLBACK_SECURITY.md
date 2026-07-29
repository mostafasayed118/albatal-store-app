# Staging E2E — Callback Security

Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Authorization: STAGING-E2E-E9A6DEB-2026-07-28 (staging only)

Result: PARTIAL — signature/CORS gates VERIFIED; value-dependent callback tests
BLOCKED by the Paymob-initiation failure (see STAGING_E2E_PAYMOB.md).

## Forged-HMAC callback — VERIFIED — staging only
- POST to `/functions/v1/paymob-callback` with a well-formed form body and a
  bogus HMAC → HTTP 401, body `{"message":"Invalid signature"}`.
- Response is NOT `{"code":"UNAUTHORIZED_NO_AUTH_HEADER"}`, confirming the
  callback is reachable without a JWT gateway block and is rejected at HMAC
  validation before any DB state change.
- No payment/order/stock change (request rejected before the RPC).

## CORS disallowed-origin probe — VERIFIED — staging only
- OPTIONS to `/functions/v1/checkout` with `Origin: https://evil.example.com`
  → HTTP 200 "ok" with NO `Access-Control-Allow-Origin` header.
- No `*` wildcard; no reflection of the disallowed origin.

## Value-dependent callback security tests — BLOCKED
These require a real mapped payment (provider order id), which cannot be created
because `paymob-initiate` returns HTTP 500 (see STAGING_E2E_PAYMOB.md):
- Amount-mismatch (valid HMAC, wrong amount → expect `amount_mismatch`, no change)
- Duplicate-callback idempotency (expect `already_processed`, exactly-once effect)
- Late-callback after terminal state (expect no resurrection)

Callback state-machine guarantees for the above are implemented in migration 014
(`process_paymob_callback`): amount check vs order.total, terminal-state
idempotency, single stock restore via `order_items.restored`. Executable staging
confirmation is deferred to PACKAGE M once initiation is restored.
