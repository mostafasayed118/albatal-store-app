# Staging E2E — Paymob Sandbox Matrix

Candidate SHA: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Authorization: STAGING-E2E-E9A6DEB-2026-07-28 (staging only, sandbox)

Result: BLOCKED — Paymob initiation fails; mapped-callback matrix cannot run.

## PAYMOB-1 — Initiation — FAIL (BLOCKED)

Two independent, freshly-created disposable orders, both authenticated with a
valid staging JWT:

- order `cfcb3ae6-a4a9-4ee3-8009-4a2b2235cb39`: `paymob-initiate` → HTTP 500,
  body `{"message":"Failed to create payment record"}`
- order `71e26c82-9baa-4072-a1b4-2919c5dd697b`: `paymob-initiate` → HTTP 500,
  body `{"message":"Failed to create payment record"}`

Deterministic across both runs. `checkout_url` absent; no `paymob_order_id`
persisted; no payment row created.

Because no mapped payment (real provider order id) can be created, the following
sandbox tests could NOT be executed and are recorded as BLOCKED:

- PAYMOB-2 amount_mismatch
- PAYMOB-3 success
- PAYMOB-4 duplicate_callback (idempotency)
- PAYMOB-5 decline + stock restore
- PAYMOB-6 late-callback (no resurrection)

## Root-cause diagnosis (read-only DB evidence)

The 500 originates from `paymob-initiate`'s server-side payment INSERT
(the "Creating new payment record" branch), which runs through a **service-role**
Supabase client.

Read-only inspection of staging `public.payments`:
- RLS enabled: `relrowsecurity = true`, `relforcerowsecurity = false`
- Policies: only `payments_select_own` (SELECT). **INSERT policy count: 0.**
- Triggers: `set_payments_updated_at` (BEFORE UPDATE) and
  `trg_audit_payment_status` (AFTER UPDATE OF status) — **no INSERT trigger**.
- All NOT NULL columns are supplied by the INSERT
  (`order_id, user_id, method, amount, status`); `amount>0` and `status` value
  are within their CHECK constraints. FK `user_id → profiles(id)` holds (COD
  tests inserted payment rows for equivalent signup users successfully).

Since there is no INSERT policy and no INSERT trigger, the only way to insert a
payment is a role that bypasses RLS. `service_role` has BYPASSRLS, so a *valid*
service-role client would succeed. The INSERT failing therefore indicates the
**service-role credential effective in the deployed `paymob-initiate` runtime is
not operative** (missing/stale/invalid), causing the INSERT to be evaluated
under a non-privileged role and denied by RLS.

## The design is correct; this is a deployment/secret regression

Staging `payments` already contains **14 `paymob_card` rows, 13 with a real
provider order id** — i.e. the service-role INSERT path in `paymob-initiate`
worked previously. The candidate SQL/RLS design (RLS on + no INSERT policy +
service_role bypass) is sound. The current failure is a runtime configuration
regression, not a defect in the frozen candidate's migrations or policies.

## Stop condition triggered

Matches `report_1.md` stop condition: "Edge Function returns 5xx due missing
secret." Remediation requires secret/deployment changes that are explicitly
NOT authorized during E2E (no secret changes, no Edge Function deployment, no
source/migration changes). Escalated to PACKAGE M.
