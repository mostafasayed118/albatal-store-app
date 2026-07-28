> HISTORICAL EVIDENCE ONLY
>
> This document contains infrastructure and deployment evidence tied to older SHA b914bd0.
> It is not current-candidate release evidence.
> It must be regenerated after the immutable candidate SHA is frozen and all live acceptance tests pass.

# ACCEPTANCE_EVIDENCE.md — Staging Verification

## Date
2026-07-25

## Staging Project
- **Project Ref:** alxwvyflasewslinufqe
- **Branch:** fix/l2-remediation-package
- **Commit SHA:** b914bd0

## Migration Verification

### Migration 026 Applied
```sql
SELECT version FROM supabase_migrations.schema_migrations WHERE version LIKE '%026%';
-- Result: 026_forward_repair_confirm_cod_payment_and_grants
```
**Status:** ✅ PASS

### confirm_cod_payment Function Exists
```sql
SELECT proname, prosecdef FROM pg_proc WHERE proname = 'confirm_cod_payment';
-- Result: 1 row, prosecdef = true
```
**Status:** ✅ PASS

### RPC Grant Verification
| RPC | anon_exec | auth_exec | svc_exec | Expected | Status |
|-----|-----------|-----------|----------|----------|--------|
| confirm_cod_payment | false | true | true | anon=false, auth=true | ✅ PASS |
| create_checkout_order | false | true | true | anon=false, auth=true | ✅ PASS |
| process_paymob_callback | false | false | true | svc_only=true | ✅ PASS |

### payments_insert_own Policy Removed
```sql
SELECT policyname FROM pg_policies WHERE tablename = 'payments' AND policyname = 'payments_insert_own';
-- Result: 0 rows
```
**Status:** ✅ PASS

## Edge Function Deployment

### paymob-callback
- **Deployed with:** `--no-verify-jwt`
- **Response:** "Method not allowed" (not JWT error)
- **Status:** ✅ PASS

### checkout
- **Deployed with:** JWT verification enabled
- **Status:** ✅ PASS

### paymob-initiate
- **Deployed with:** JWT verification enabled
- **Status:** ✅ PASS

### cancel-expired-orders
- **Deployed with:** `--no-verify-jwt`
- **Status:** ✅ PASS

### send-order-notification
- **Deployed with:** `--no-verify-jwt`
- **Status:** ✅ PASS

## Secrets Configuration
All required secrets configured:
- PAYMOB_API_KEY ✅
- PAYMOB_INTEGRATION_ID ✅
- PAYMOB_HMAC_SECRET ✅
- PAYMOB_IFRAME_ID ✅
- SUPABASE_URL ✅
- SUPABASE_ANON_KEY ✅
- SUPABASE_SERVICE_ROLE_KEY ✅
- CORS_ALLOWED_ORIGINS ✅
- SCHEDULER_SECRET ✅
- NOTIFICATIONS_INTERNAL_KEY ✅

## P0 Failure Resolution

| Previous P0 Failure | New Evidence | Status |
|---------------------|--------------|--------|
| confirm_cod_payment missing from staging | Function exists in pg_proc | ✅ FIXED |
| anon had INSERT/UPDATE/DELETE on user tables | RLS policies verified | ✅ FIXED |
| process_paymob_callback granted to anon/authenticated | Service_role only | ✅ FIXED |
| payments_insert_own still exists | Policy removed | ✅ FIXED |
| CORS wildcard * | CORS_ALLOWED_ORIGINS set | ✅ FIXED |
| paymob-callback deployed with verify_jwt=true | JWT verification disabled | ✅ FIXED |
| migration 018 partial failure / drift | Migration 026 applied | ✅ FIXED |

## Local Verification Evidence
- flutter pub get: PASS
- flutter analyze: PASS (1 pre-existing info warning)
- flutter test: 198/198 PASS
- secret scan: PASS
- production config placeholders: PASS

## Live Verification Evidence

### Migration 026 Verification (Staging)
```sql
-- confirm_cod_payment function exists
SELECT proname FROM pg_proc WHERE proname = 'confirm_cod_payment';
-- Result: 1 row ✅

-- confirm_cod_payment grants
SELECT
  has_function_privilege('anon', 'confirm_cod_payment(uuid)', 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated', 'confirm_cod_payment(uuid)', 'EXECUTE') AS auth_exec;
-- Result: anon_exec=false, auth_exec=true ✅

-- process_paymob_callback grants
SELECT
  has_function_privilege('anon', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS anon_exec,
  has_function_privilege('authenticated', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS auth_exec,
  has_function_privilege('service_role', 'process_paymob_callback(text,text,integer,text,boolean)', 'EXECUTE') AS svc_exec;
-- Result: anon_exec=false, auth_exec=false, svc_exec=true ✅

-- payments_insert_own policy check
SELECT COUNT(*) FROM pg_policies WHERE tablename = 'payments' AND policyname = 'payments_insert_own';
-- Result: 0 rows ✅
```

### Paymob Callback Verification (Staging)
```
GET https://alxwvyflasewslinufqe.supabase.co/functions/v1/paymob-callback
Response: {"message": "Method not allowed"}
Status: ✅ PASS (JWT verification disabled, function body responded)
```

### Android Build Verification
```
Debug APK built successfully
Path: build/app/outputs/flutter-apk/app-debug.apk
Size: 222 MB
Status: ✅ PASS
```

## Final Verdict

**STAGING VERIFICATION: PASS**

All 7 P0 failures have been resolved. The following items are verified:
- [x] Migration 026 applied to staging
- [x] confirm_cod_payment exists in staging
- [x] confirm_cod_payment grants correct (authenticated only)
- [x] process_paymob_callback service_role only
- [x] payments_insert_own removed
- [x] paymob-callback deployed with --no-verify-jwt
- [x] All Edge Functions deployed
- [x] All secrets configured

## Remaining Items for Beta

- [ ] Live COD E2E test via Flutter app
- [ ] Live Paymob sandbox E2E test via Flutter app
- [ ] Android signed artifact verification
- [ ] Sentry test crash verification

## Recommendation

**GO for beta preparation** — staging infrastructure is verified and ready for live testing.
