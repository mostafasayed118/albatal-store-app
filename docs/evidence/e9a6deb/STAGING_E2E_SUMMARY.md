# Staging E2E — Summary

Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Authorization: STAGING-E2E-E9A6DEB-2026-07-28 (staging only)

## Overall result

E2E RESULT: BLOCKED — Paymob leg cannot execute on staging.
Do NOT mark E2E passed. Release verdict remains NO-GO.
Escalated to PACKAGE M — E2E FAILURE REMEDIATION.

## Preflight (all PASS)
- Migration high-water: 030
- Edge Functions ACTIVE: checkout, paymob-initiate, paymob-callback,
  cancel-expired-orders, send-order-notification
- Secret names present: all 7 ratified names
- CORS disallowed-origin: not reflected, no wildcard
- Forged-HMAC callback: HTTP 401 `{"message":"Invalid signature"}`

## Test-leg status
| Leg | Status |
| --- | --- |
| COD matrix | PASS — 5/5 + 2 N/A-by-design |
| Forged-HMAC callback | VERIFIED — staging only |
| CORS disallowed origin | VERIFIED — staging only |
| Paymob initiation | FAIL (BLOCKED) — HTTP 500 "Failed to create payment record" |
| Paymob success / decline / amount-mismatch / duplicate / late | BLOCKED (no mapped payment) |
| Race: duplicate concurrent callbacks | BLOCKED (no mapped payment) |
| Race: concurrent COD confirm | DEFERRED (sequential guard verified via COD-2) |

## Blocking finding
`paymob-initiate` fails deterministically at its server-side payment INSERT
(HTTP 500). Read-only DB evidence shows `payments` has RLS enabled, zero INSERT
policies, and no INSERT trigger — so the insert requires a role with BYPASSRLS
(service_role). The failure indicates the service-role credential effective in
the deployed function runtime is not operative. The candidate SQL/RLS design is
correct (13 historical `paymob_card` payments have real provider order ids); the
failure is a deployment/secret regression. Full detail: STAGING_E2E_PAYMOB.md.

## Gate wording (NOT applied — E2E did not pass)
COD E2E: VERIFIED — staging only
Forged-HMAC callback: VERIFIED — staging only
CORS disallowed origin: VERIFIED — staging only
Paymob sandbox E2E: BLOCKED — see PACKAGE M
Amount-mismatch / Duplicate-callback / Late-callback / Race (callback): BLOCKED
RLS adversarial: VERIFIED — committed executable suite 44/0
RLS-ESC-001: REMEDIATED
Release verdict: NO-GO
