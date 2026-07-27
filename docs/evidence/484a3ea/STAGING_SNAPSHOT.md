# Package J — Staging Snapshot

Frozen candidate: 484a3ea39462277dd9ab0830b26d4fd724ab0c1a
Tag: release-candidate/484a3ea
Staging project: alxwvyflasewslinufqe
Date: 2026-07-27
Mode: READ-ONLY
Supabase CLI: 2.109.1

> Scope note: The API-token surface (functions, secret names, live HTTP
> probes) was fully captured automatically. The DB-catalog surface
> (migration ledger, RPC defs, grants, policies, RLS flags) requires the
> staging DB password via `supabase link` (interactive) or the Dashboard SQL
> Editor, which is a human step. Those sections below contain the exact
> read-only SQL to run and are marked PENDING HUMAN EXECUTION. No mutating
> action was taken. `config.toml` was not modified.

---

## Migration parity

### Repository migrations at tag release-candidate/484a3ea (27 files)

```
001_initial_schema.sql
002_rls_policies.sql
003_auth_profiles_and_hardening.sql
004_stock_function.sql
005_storage_buckets.sql
006_payments_table.sql
007_stock_increment_function.sql
008_order_fulfillment.sql
009_shipping_zones.sql
010_notifications_analytics.sql
011_orders_idempotency_and_expiry.sql
012_add_order_statuses.sql
013_atomic_checkout_rpc.sql
014_paymob_security_repair.sql
015_payments_update_and_stock_hardening.sql
016_seed_product_catalog.sql
017_authorize_rpcs.sql
018_confirm_cod_payment.sql
019_harden_rpc_and_payments_authorization.sql
020_fix_orders_fk.sql
021_fix_create_checkout_order.sql
022_repair_confirm_cod_payment.sql
024_hardening_rpcs_policies.sql
025_race_safe_state_machine.sql
026_forward_repair_confirm_cod_payment_and_grants.sql
027_add_payments_insert_policy.sql
028_reclose_payments_insert_policy.sql
```

Repository numbering note: there is NO `023` and NO `029` file at the tag.
Highest version = `028`. Expected staging ledger high-water mark = `028`.

### Staging applied migrations — PENDING HUMAN EXECUTION

Run in Dashboard SQL Editor (read-only):

```sql
SELECT version
FROM supabase_migrations.schema_migrations
ORDER BY version;
```

Paste result here:
```
[fill]
```

Missing migrations: [fill]
Extra migrations: [fill]
Parity verdict: PENDING (repo high-water mark is 028; confirm 018/019 slot
identity — prior Package notes flagged a historical 018/019 renumbering drift
on staging where slot 018 held a low-stock index instead of confirm_cod_payment).

---

## Critical RPCs — PENDING HUMAN EXECUTION

```sql
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef,
  p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'confirm_cod_payment',
    'create_checkout_order',
    'update_order_status',
    'process_paymob_callback',
    'calculate_shipping_fee',
    'expire_pending_order',
    'decrement_stock',
    'increment_stock',
    'set_payment_provider_order_id'
  )
ORDER BY p.proname;
```

Paste result here:
```
[fill]
```

Missing RPCs: [fill]
Note: capture the ACTUAL identity args of `process_paymob_callback` here so the
grant query below uses the correct signature.

---

## RPC grants — PENDING HUMAN EXECUTION

```sql
SELECT
  has_function_privilege('anon', 'confirm_cod_payment(uuid)', 'EXECUTE') AS anon_confirm_cod,
  has_function_privilege('authenticated', 'confirm_cod_payment(uuid)', 'EXECUTE') AS auth_confirm_cod;
```

Target: anon_confirm_cod = false, auth_confirm_cod = true.

```sql
-- Adjust signature to match the args captured above.
SELECT
  has_function_privilege('anon', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS anon_callback,
  has_function_privilege('authenticated', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS auth_callback,
  has_function_privilege('service_role', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS service_callback;
```

Target: anon_callback = false, auth_callback = false, service_callback = true.

Paste results here:
```
[fill]
```

---

## Payments policies — PENDING HUMAN EXECUTION

```sql
SELECT policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND policyname IN (
    'payments_insert_own',
    'payments_insert_authenticated_own'
  );
```

Target after migration 028: 0 rows.

Paste result here:
```
[fill]
```

Direct authenticated payment INSERT present: [fill YES/NO]

---

## RLS flags — PENDING HUMAN EXECUTION

```sql
SELECT
  relname,
  relrowsecurity,
  relforcerowsecurity
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relname IN (
    'profiles','addresses','wishlists','cart_items','orders',
    'order_items','payments','notifications','analytics_events','error_logs'
  )
ORDER BY relname;
```

Paste result here:
```
[fill]
```

Target: relrowsecurity = true for all user-private tables.

---

## Policy catalog — PENDING HUMAN EXECUTION

```sql
SELECT tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles','addresses','wishlists','cart_items','orders',
    'order_items','payments','notifications','analytics_events','error_logs'
  )
ORDER BY tablename, policyname;
```

Paste result here (review for secrets before saving — policy defs should have none):
```
[fill]
```

---

## Edge Functions — CAPTURED

`supabase functions list --project-ref alxwvyflasewslinufqe` (2026-07-27):

| Name | Slug | Status | Version | Updated (UTC) |
|---|---|---|---|---|
| checkout | checkout | ACTIVE | 27 | 2026-07-25 10:56:13 |
| paymob-initiate | paymob-initiate | ACTIVE | 34 | 2026-07-25 14:12:52 |
| cancel-expired-orders | cancel-expired-orders | ACTIVE | 25 | 2026-07-25 10:56:15 |
| paymob-callback | paymob-callback | ACTIVE | 25 | 2026-07-25 10:56:05 |
| send-order-notification | send-order-notification | ACTIVE | 24 | 2026-07-25 10:56:15 |

All 5 expected functions present and ACTIVE.

### JWT settings — CONFIRMED VIA RUNTIME PROBES

Unauthenticated `POST {}` probes classify each function's gate:

| Function | Response | Inferred verify_jwt | Target | Match |
|---|---|---|---|---|
| checkout | `401 UNAUTHORIZED_NO_AUTH_HEADER` (platform gate) | true | true | ✅ |
| paymob-initiate | `401 UNAUTHORIZED_NO_AUTH_HEADER` (platform gate) | true | true | ✅ |
| paymob-callback | `401 {"message":"Invalid signature"}` (body/HMAC) | false | false | ✅ |
| cancel-expired-orders | `401 {"message":"Unauthorized"}` (body/secret) | false | false | ✅ |
| send-order-notification | `401 {"message":"Unauthorized"}` (body/secret) | false | false | ✅ |

JWT matrix verdict: PASS — matches target exactly.

Significance: the historical B1 drift (paymob-callback previously deployed with
`verify_jwt=true`, blocking Paymob) is RESOLVED — the function body now
executes and rejects a forged callback with `Invalid signature`.

---

## Secret names only — CAPTURED

`supabase secrets list --project-ref alxwvyflasewslinufqe` (names only; digests
NOT reproduced here; no values printed):

Present:
```
ANON_KEY
CANCEL_EXPIRED_ORDERS_SECRET
CORS_ALLOWED_ORIGINS
NOTIFICATIONS_INTERNAL_KEY
PAYMOB_API_KEY
PAYMOB_HMAC_SECRET
PAYMOB_IFRAME_ID
PAYMOB_INTEGRATION_ID
SCHEDULER_SECRET
SERVICE_ROLE_KEY
SUPABASE_ANON_KEY
SUPABASE_DB_URL
SUPABASE_JWKS
SUPABASE_PUBLISHABLE_KEYS
SUPABASE_SECRET_KEYS
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_URL
URL
```

Required-name checklist:
- PAYMOB_API_KEY ✅
- PAYMOB_INTEGRATION_ID ✅
- PAYMOB_HMAC_SECRET ✅
- PAYMOB_IFRAME_ID ✅ (old B2 blocker — now present)
- SUPABASE_URL ✅
- SUPABASE_ANON_KEY ✅
- SUPABASE_SERVICE_ROLE_KEY ✅
- NOTIFICATIONS_INTERNAL_KEY ✅
- CORS_ALLOWED_ORIGINS ✅
- Scheduler secret used by code = `SCHEDULER_SECRET` ✅ (confirmed via
  `git grep Deno.env.get` at tag: cancel-expired-orders reads `SCHEDULER_SECRET`)

Missing required secret names: NONE.

Observation (not a blocker): there are duplicate/legacy name pairs
(`ANON_KEY` vs `SUPABASE_ANON_KEY`, `URL` vs `SUPABASE_URL`, `SERVICE_ROLE_KEY`
vs `SUPABASE_SERVICE_ROLE_KEY`) plus new-style `SUPABASE_PUBLISHABLE_KEYS` /
`SUPABASE_SECRET_KEYS`. Values were NOT inspected. Package K should confirm the
functions read the canonical names and consider pruning legacy duplicates
(human decision; no action under Package J).

---

## CORS probe — CAPTURED

Preflight for a disallowed origin:
```
curl -i -X OPTIONS https://alxwvyflasewslinufqe.supabase.co/functions/v1/checkout \
  -H "Origin: https://example.com" -H "Access-Control-Request-Method: POST"
=> HTTP/1.1 200 OK
   (NO Access-Control-Allow-Origin header returned; NO ACAO: * )
```

Same result for `paymob-initiate` preflight.

CORS verdict: EXPLICIT / ALLOWLIST — not wildcard. A non-allowlisted origin
(`https://example.com`) receives NO `Access-Control-Allow-Origin`, so the
browser would block it. `CORS_ALLOWED_ORIGINS` secret is set. Package K should
still positively confirm an ALLOWED origin echoes back its ACAO value and that
the allowlist contains the intended production/staging web origins.

---

## Package K remediation required (provisional — pending DB section)

Confirmed clean so far (no remediation needed):
1. Edge Function JWT matrix already matches target — no redeploy needed for JWT.
2. All required secret NAMES present, including previously-missing PAYMOB_IFRAME_ID.
3. CORS is explicit (not wildcard).
4. paymob-callback HMAC rejection works at the body level.

Still to confirm before Package K scope is final (DB section):
5. Migration ledger parity to repo high-water mark 028 (watch the historical
   018/019 slot drift).
6. `confirm_cod_payment` exists with anon=false / authenticated=true.
7. `process_paymob_callback` is service_role-only.
8. `payments_insert_own` / `payments_insert_authenticated_own` absent (028 applied).
9. RLS enabled on all user-private tables.

---

## Release verdict

NO-GO

Frozen candidate remains 484a3ea. This snapshot is read-only reconnaissance and
authorizes nothing. Staging deployment, migrations, secret changes, and live
mutating E2E remain gated on Package K human approval.
