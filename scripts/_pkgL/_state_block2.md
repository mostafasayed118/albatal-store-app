## 2026-07-28 — Staging E2E Partial / Paymob Blocked

Authorization: STAGING-E2E-E9A6DEB-2026-07-28
Candidate: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe

Preflight:
- Migration high-water 030: PASS
- Edge Functions active: PASS
- Ratified secret names present: PASS
- CORS disallowed origin denied: PASS
- Forged HMAC callback rejected: PASS

COD E2E:
- Result: PASS
- Scored: 5/5 PASS
- N/A by design: 2
- Stock decrement exactly once at order creation
- Idempotent confirm: already_confirmed
- Non-owner denied: not_owner
- Anonymous denied: 401 / SQLSTATE 42501
- Non-COD rejected: payment_not_cod

Paymob E2E:
- Result: BLOCKED
- paymob-initiate returned HTTP 500 "Failed to create payment record"
- Deterministic across two independent disposable orders
- Root cause hypothesis: deployed paymob-initiate service-role credential not operative
- payments table design correct: RLS enabled, zero INSERT policies, no INSERT trigger
- Historical paymob_card payments prove path previously worked
- This is a staging runtime/deployment/secret regression, not a candidate SQL defect

Callback value-dependent tests: BLOCKED
Race matrix: BLOCKED

Package M: OPEN
Release verdict: NO-GO

---

