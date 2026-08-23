
## Staging E2E Partial — 2026-07-28

Candidate: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Authorization: STAGING-E2E-E9A6DEB-2026-07-28

### Preflight

PASS

### COD E2E

PASS — staging only

### Forged HMAC quick probe

PASS — callback returned 401 {"message":"Invalid signature"}

### CORS disallowed-origin probe

PASS — disallowed origin not reflected, no wildcard

### Paymob initiation

BLOCKED — paymob-initiate HTTP 500 "Failed to create payment record"

### Paymob sandbox matrix

BLOCKED

### Callback value-dependent matrix

BLOCKED

### Race/concurrency matrix

BLOCKED

### Root cause

Deployed paymob-initiate service-role payment INSERT appears denied by RLS.
Candidate SQL/RLS design is correct.
Staging runtime service-role credential or deployment state requires remediation.

### Remediation

Package M — E2E Failure Remediation
Scope: verify/refresh Edge Function service-role credential and redeploy paymob-initiate if required.

### Release status

Release verdict remains NO-GO.
