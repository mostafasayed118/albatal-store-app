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

SQL Block 1 — run in Dashboard SQL Editor (read-only):

```sql
SELECT
  count(*) AS migration_count,
  max(version) AS high_water
FROM supabase_migrations.schema_migrations;

SELECT version
FROM supabase_migrations.schema_migrations
ORDER BY version;
```

Paste result here:
```
[fill]
```

Staging migration count: [fill]
Staging high-water: [fill]
Missing migrations: [fill]
Extra migrations: [fill]
Parity verdict: PENDING (repo high-water mark is 028; confirm 018/019 slot
identity — prior Package notes flagged a historical 018/019 renumbering drift
on staging where slot 018 held a low-stock index instead of confirm_cod_payment,
and staging 019 differed from the on-disk 019).


---

## Critical RPCs + grants — PENDING HUMAN EXECUTION

SQL Block 2 — existence + SECURITY DEFINER + per-role EXECUTE in one query:

```sql
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef,
  p.proconfig,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
  has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'confirm_cod_payment',
    'process_paymob_callback',
    'create_checkout_order',
    'update_order_status',
    'calculate_shipping_fee',
    'expire_pending_order',
    'decrement_stock',
    'increment_stock',
    'set_payment_provider_order_id'
  )
ORDER BY p.proname;
```

Target:
- confirm_cod_payment: exists, args uuid, prosecdef true, anon false, authenticated true
- process_paymob_callback: exists, anon false, authenticated false, service_role true
- create_checkout_order / update_order_status / calculate_shipping_fee: authenticated true, anon false
- expire_pending_order / decrement_stock / increment_stock: service_role true, anon false, authenticated false

Paste result here:
```
[fill]
```

confirm_cod_payment present: [YES/NO]
confirm_cod_payment grants correct: [YES/NO]
process_paymob_callback service_role only: [YES/NO]
Missing RPCs: [fill]
Grant failures: [fill]
RPC verdict: [PASS/FAIL]

---

## Payments INSERT policy absence — PENDING HUMAN EXECUTION

SQL Block 3:

```sql
SELECT
  policyname,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
ORDER BY policyname;

SELECT policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
  AND policyname IN (
    'payments_insert_own',
    'payments_insert_authenticated_own'
  );
```

Target: second query returns 0 rows; no active policy grants anon/authenticated
direct INSERT into payments.

Paste result here:
```
[fill]
```

payments_insert_own present: [YES/NO]
payments_insert_authenticated_own present: [YES/NO]
Other payments INSERT policies: [fill]
Direct authenticated payment INSERT allowed by policy: [YES/NO]
Payments policy verdict: [PASS/FAIL]

---

## RLS enabled flags — PENDING HUMAN EXECUTION

SQL Block 4:

```sql
SELECT
  c.relname,
  c.relrowsecurity,
  c.relforcerowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'profiles','addresses','wishlists','cart_items','orders',
    'order_items','payments','notifications','analytics_events','error_logs'
  )
ORDER BY c.relname;
```

Target: relrowsecurity = true for all user-private tables (at minimum profiles,
addresses, wishlists, cart_items, orders, order_items, payments).

Paste result here:
```
[fill]
```

RLS enabled tables: [fill]
RLS disabled tables: [fill]
RLS verdict: [PASS/FAIL]

---

## Anonymous/public write grants — PENDING HUMAN EXECUTION

SQL Block 5 (checks the historical P0 where anon had write grants):

```sql
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'public')
  AND table_name IN (
    'profiles','addresses','wishlists','cart_items','orders',
    'order_items','payments','notifications','analytics_events','error_logs'
  )
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY table_name, grantee, privilege_type;
```

Target: 0 rows.

Paste result here:
```
[fill]
```

Anonymous/public write grants found: [YES/NO]
Anonymous write grant verdict: [PASS/FAIL]

### Optional — authenticated write grant context (informational)

```sql
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee = 'authenticated'
  AND table_name IN (
    'profiles','addresses','wishlists','cart_items','orders',
    'order_items','payments','notifications','analytics_events','error_logs'
  )
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY table_name, privilege_type;
```

Does not auto-fail. Key question: RLS must deny unsafe authenticated writes;
for payments, direct authenticated INSERT must be denied by absence of an
INSERT policy (see SQL Block 3).

Paste result here (informational):
```
[fill]
```

---

## Policy catalog (detail) — PENDING HUMAN EXECUTION (optional deep dive)

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

### Secret names the Edge Function code actually reads (git grep at frozen tag)

`git grep 'env.get' release-candidate/484a3ea -- supabase/functions` (parsed to
distinct names) yields EXACTLY these 10 canonical names:

```
CORS_ALLOWED_ORIGINS
NOTIFICATIONS_INTERNAL_KEY
PAYMOB_API_KEY
PAYMOB_HMAC_SECRET
PAYMOB_IFRAME_ID
PAYMOB_INTEGRATION_ID
SCHEDULER_SECRET
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_URL
```

All 10 are present in staging secrets. Nothing the code reads is missing.

Legacy/duplicate secrets NOT referenced by function code (safe pruning
candidates for Package K with approval): `ANON_KEY`, `URL`, `SERVICE_ROLE_KEY`,
`CANCEL_EXPIRED_ORDERS_SECRET` (code reads `SCHEDULER_SECRET`, not this), plus
platform-managed `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `SUPABASE_PUBLISHABLE_KEYS`,
`SUPABASE_SECRET_KEYS`. Values were NOT inspected. Do NOT unset any of these
under Package J; leave them until Package K explicit approval.


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

---

## DB Catalog Snapshot Summary

Executed by: [fill]
Date: [fill]
Method: Dashboard SQL Editor / supabase db execute
Staging project: alxwvyflasewslinufqe
Frozen candidate: 484a3ea39462277dd9ab0830b26d4fd724ab0c1a

### Migration parity

Staging migration count: [fill]
Staging high-water: [fill]
Missing migrations: [fill]
Extra migrations: [fill]
Verdict: PASS / FAIL / DRIFT

### Critical RPCs

confirm_cod_payment present: YES / NO
confirm_cod_payment grants correct: YES / NO
process_paymob_callback service_role only: YES / NO
Missing RPCs: [fill]
Grant failures: [fill]
Verdict: PASS / FAIL

### Payments policies

payments_insert_own present: YES / NO
payments_insert_authenticated_own present: YES / NO
Direct authenticated payment INSERT allowed by policy: YES / NO
Verdict: PASS / FAIL

### RLS flags

RLS disabled tables: [fill]
Verdict: PASS / FAIL

### Anonymous/public write grants

Anonymous/public write grants found: YES / NO
Verdict: PASS / FAIL

### Overall DB catalog verdict

PASS / FAIL

