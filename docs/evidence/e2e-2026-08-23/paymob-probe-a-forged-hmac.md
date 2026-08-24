# Paymob Callback — Probe A: Forged-HMAC Rejection (staging)

Date: 2026-08-23 · Target: `https://zvpjngdgbpnkkqrorkul.supabase.co/functions/v1/paymob-callback`
Auth: `Authorization: Bearer <SUPABASE_ANON_KEY>` from `config/env.staging.json`
(anon key is public-by-design; used so the platform `verify_jwt` gate passes and
the test isolates the function's OWN HMAC verification layer).

## Results

| Probe | Request body | HTTP | Response |
|---|---|---|---|
| A1 | `{"hmac":"deadbeef","amount_cents":100}` | **401** | `{"message":"Invalid signature"}` |
| A2 | `{"amount_cents":100}` (hmac field absent) | **401** | `{"message":"Invalid signature"}` |

Both forged shapes are rejected identically: no crash, no differential error
messages, no payload echo. Rejection occurs before any order/payment lookup,
so no database state change is possible on this path by construction.

## Interpretation

- The HMAC verification wall is ACTIVE on the new isolated staging project.
- Because the anon-key bearer satisfied platform JWT checking, this result also
  predicts identical behavior once the owner flips `verify_jwt` OFF for this
  function (owner dashboard step): forged callbacks will still die at the
  function-level signature check with 401.
- Probes B (valid HMAC + amount mismatch) and C (late callback after expiry)
  require staging DB row creation → blocked until owner exports `STAGING_DB_URL`.
