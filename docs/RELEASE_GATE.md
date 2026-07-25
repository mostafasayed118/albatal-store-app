# RELEASE_GATE.md — Release Status

## Current Status

```
STAGING VERIFICATION: PASS
BETA READINESS: IN PROGRESS
RELEASE STATUS: NO-GO / LIVE TESTING REQUIRED
```

## Release Gate Checklist

### Phase 0: Decisions
- [x] All 9 decisions APPROVED in DECISIONS.md

### Phase 1: Local Verification
- [x] flutter pub get PASS
- [x] flutter analyze PASS
- [x] flutter test 198/198 PASS
- [x] secret scan PASS
- [x] production config placeholders PASS
- [x] migration 026 safety check PASS

### Phase 2: Staging Deployment
- [x] Branch pushed (fix/l2-remediation-package)
- [x] Migration 026 applied to staging
- [x] Migration 024 applied to staging
- [x] Migration 025 applied to staging
- [x] paymob-callback deployed with --no-verify-jwt
- [x] checkout deployed with JWT verification
- [x] paymob-initiate deployed with JWT verification
- [x] cancel-expired-orders deployed
- [x] send-order-notification deployed
- [x] All secrets configured

### Phase 3: Staging Verification
- [x] confirm_cod_payment function exists
- [x] confirm_cod_payment grants correct (authenticated only)
- [x] create_checkout_order grants correct (authenticated only)
- [x] process_paymob_callback service_role only
- [x] payments_insert_own removed
- [x] paymob-callback JWT verification disabled
- [x] Paymob callback responds correctly

### Phase 4: Live Testing
- [ ] Live COD E2E test via Flutter app
- [ ] Live Paymob sandbox E2E test via Flutter app
- [ ] RLS adversarial tests pass
- [ ] Sentry test crash verification

### Phase 5: Android Release
- [ ] Android signed artifact verification
- [ ] apksigner verify PASS
- [ ] Package name com.albatal.elite verified
- [ ] debuggable=false verified

### Phase 6: Documentation
- [x] ACCEPTANCE_EVIDENCE.md updated
- [x] RELEASE_GATE.md updated
- [ ] Beta scope documented

## Gate Owners

| Gate | Owner | Status |
|------|-------|--------|
| Product | [fill] | Pending |
| Engineering | [fill] | Pending |
| QA | [fill] | Pending |
| Security | [fill] | Pending |

## Decision Summary

| # | Decision | Status | Evidence |
|---|---|---|---|
| 1 | Migration repair strategy | APPROVED | Migration 026 applied |
| 2 | COD missing-payment behavior | APPROVED | payment_not_found implemented |
| 3 | Paymob callback gateway | APPROVED | verify_jwt=false deployed |
| 4 | Staging/production isolation | APPROVED | Separate projects |
| 5 | Secret provisioning | APPROVED | All secrets configured |
| 6 | Observability | APPROVED | Sentry added |
| 7 | Android release | APPROVED | Pending artifact |
| 8 | Beta scope | APPROVED | Android-only 10-20 users |
| 9 | Release gate ownership | APPROVED | Pending names |

## GO/NO-GO Decision

**Current: NO-GO**

Reason: Live testing not yet completed.

**Next milestone:**
- Live COD E2E test passes
- Live Paymob sandbox E2E test passes
- Android signed artifact verified

**Estimated GO:**
After live testing evidence is captured.
