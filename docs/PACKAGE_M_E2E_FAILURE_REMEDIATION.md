# PACKAGE M — E2E FAILURE REMEDIATION

Status: OPEN
Opened: 2026-07-28
Authorization context: STAGING-E2E-E9A6DEB-2026-07-28 (staging only)
Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Release verdict: NO-GO (unchanged)

## E2E RESULT: BLOCKED

Staging E2E stopped at the Paymob leg per the report_1.md stop condition
"Edge Function returns 5xx due missing secret". COD and callback signature/CORS
gates passed; the Paymob sandbox matrix could not execute.

### Failed test
`PAYMOB-1 initiation` — `POST /functions/v1/paymob-initiate` (valid JWT, valid
pending order) returns HTTP 500. Deterministic across two independent orders
(`cfcb3ae6-…cb39`, `71e26c82-…697b`).

### Redacted response
`{"message":"Failed to create payment record"}` (HTTP 500). No secrets emitted.

### DB before/after
No change. No payment row is created (INSERT fails); the disposable orders remain
`pending` and are reclaimed by the 15-minute expiry sweep (stock restored).
Read-only inspection of `public.payments`:
- RLS enabled (`relrowsecurity=true`), `relforcerowsecurity=false`
- Policies: `payments_select_own` (SELECT) only — INSERT policy count 0
- Triggers: UPDATE-only (`set_payments_updated_at`, `trg_audit_payment_status`)
- Historical rows: 14 `paymob_card` (13 with provider order id), 2 `cash_on_delivery`

### Suspected component
Service-role credential effective in the deployed `paymob-initiate` runtime.
The failing statement is the server-side payment INSERT that uses a service-role
client. With RLS enabled, no INSERT policy, and no INSERT trigger, only a
BYPASSRLS role (service_role) can insert. The INSERT being denied indicates the
service-role client is NOT operating as service_role — i.e. `SUPABASE_SERVICE_ROLE_KEY`
in the function environment is stale/invalid/overridden (likely a post-JWT-rotation
mismatch). The candidate migrations/RLS are correct; 13 historical provider-mapped
payments prove the path previously worked.

## Remediation (requires owner authorization — NOT performed here)

The following are explicitly outside the E2E authorization (no secret changes,
no Edge Function deployment) and are queued for owner action:

1. Verify the `SUPABASE_SERVICE_ROLE_KEY` value available to Edge Functions on
   `alxwvyflasewslinufqe` matches the project's current service_role key
   (regenerate/re-inject if it was overridden or rotated). Do not print the value.
2. Redeploy `paymob-initiate` if the runtime env needs a refresh.
3. Re-run the E2E harness (COD already green; re-run Paymob + callback-security +
   race legs) under a fresh dated authorization.

## Re-run plan (after remediation)
- Re-run `paymob-initiate` initiation → expect 200 + `checkout_url` + pending
  payment with `paymob_order_id`.
- Execute PAYMOB success / amount-mismatch / duplicate / decline+restore / late.
- Execute RACE-1 (concurrent duplicate callbacks) and RACE-2 (concurrent COD).
- Update STAGING_E2E_PAYMOB.md / _CALLBACK_SECURITY.md / _RACE.md / _SUMMARY.md
  and apply the "VERIFIED — staging only" gate wording only if all pass.

## Do not
- Do not mark E2E passed.
- Do not change the release verdict from NO-GO.
- Do not weaken RLS or add a payments INSERT policy to "fix" this — the design is
  correct; the fix is restoring the service-role credential.
