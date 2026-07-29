Decisions:

```text
1. PUSH BLOCKED E2E EVIDENCE NOW — APPROVED
2. PACKAGE M — SERVICE-ROLE / PAYMOB-INITIATE REMEDIATION — AUTHORIZED
3. FULL PAYMOB/CALLBACK/RACE E2E RE-RUN — NOT AUTHORIZED YET
   Authorized only after Package M smoke passes and a fresh E2E re-run authorization is recorded
4. RELEASE STATUS — NO-GO
```

The COD result is strong and should be recorded.

The Paymob block is a real staging-runtime blocker, not a candidate SQL/RLS defect based on the evidence. It must be remediated before Paymob E2E can pass.

---

# Part A — Push Blocked Evidence Now

Pushing the BLOCKED evidence is approved.

Do not mark Paymob, callback value-dependent tests, or race tests as VERIFIED.

Record them as:

```text
COD E2E: PASS
Preflight: PASS
Forged HMAC quick probe: PASS
CORS disallowed-origin probe: PASS
Paymob initiation: BLOCKED — HTTP 500 service-role payment INSERT denied
Paymob sandbox matrix: BLOCKED
Callback value-dependent matrix: BLOCKED
Race matrix: BLOCKED
Package M: OPEN
Release verdict: NO-GO
```

---

## Evidence Push Commands

Use the docs evidence worktree:

```bash
cd C:/flutter_projects/albatal-freeze-fix
git status --porcelain=v1 --branch
git pull --ff-only origin docs/release-evidence-484a3ea
```

Create directories:

```bash
mkdir -p docs/evidence/e9a6deb
```

Copy the local evidence files:

```bash
cp ../albatal_store/docs/evidence/e9a6deb/STAGING_E2E_COD.md docs/evidence/e9a6deb/STAGING_E2E_COD.md
cp ../albatal_store/docs/evidence/e9a6deb/STAGING_E2E_CALLBACK_SECURITY.md docs/evidence/e9a6deb/STAGING_E2E_CALLBACK_SECURITY.md
cp ../albatal_store/docs/evidence/e9a6deb/STAGING_E2E_PAYMOB.md docs/evidence/e9a6deb/STAGING_E2E_PAYMOB.md
cp ../albatal_store/docs/evidence/e9a6deb/STAGING_E2E_RACE.md docs/evidence/e9a6deb/STAGING_E2E_RACE.md
cp ../albatal_store/docs/evidence/e9a6deb/STAGING_E2E_SUMMARY.md docs/evidence/e9a6deb/STAGING_E2E_SUMMARY.md
cp ../albatal_store/docs/PACKAGE_M_E2E_FAILURE_REMEDIATION.md docs/PACKAGE_M_E2E_FAILURE_REMEDIATION.md
```

Do not copy:

```text
scripts/_pkgL/
raw logs
secret values
service_role keys
Paymob HMAC secrets
authorization headers
```

---

## Additive STATE.md Entry

Add a new dated section. Do not remove existing content.

```md
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
```

---

## Additive RELEASE_GATE.md Entry

Append:

```md
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
```

---

## Stage, Scan, Commit, Push

Stage explicitly:

```bash
git add docs/evidence/e9a6deb/STAGING_E2E_COD.md
git add docs/evidence/e9a6deb/STAGING_E2E_CALLBACK_SECURITY.md
git add docs/evidence/e9a6deb/STAGING_E2E_PAYMOB.md
git add docs/evidence/e9a6deb/STAGING_E2E_RACE.md
git add docs/evidence/e9a6deb/STAGING_E2E_SUMMARY.md
git add docs/PACKAGE_M_E2E_FAILURE_REMEDIATION.md
git add STATE.md
git add docs/RELEASE_GATE.md
```

Verify:

```bash
git diff --cached --name-only
```

Do not stage:

```text
scripts/
docs/DECISIONS.md
supabase/
lib/
android/
config/
raw logs
```

Secret scans:

```bash
git diff --cached --name-only | grep -E "\.env$|\.env\.|secrets|key\.properties|\.jks|keystore" || echo "clean"
```

Expected:

```text
clean
```

```bash
git diff --cached | grep -E "eyJ|PAYMOB_API_KEY=|PAYMOB_HMAC_SECRET=|SUPABASE_SERVICE_ROLE_KEY=|BEGIN PRIVATE KEY|MII" || echo "clean"
```

Expected:

```text
clean
```

Commit:

```bash
git commit -m "docs: record staging E2E partial pass and Paymob initiation blocker

- Preflight PASS
- COD E2E PASS 5/5 plus 2 N/A by design
- Forged HMAC quick probe PASS
- CORS disallowed-origin probe PASS
- Paymob initiation BLOCKED: HTTP 500 Failed to create payment record
- Root cause hypothesis: deployed paymob-initiate service-role credential not operative
- Candidate SQL/RLS design appears correct
- Package M opened for staging runtime remediation
- Release verdict remains NO-GO"
```

Push:

```bash
git push origin docs/release-evidence-484a3ea
```

Do not force push.

Do not merge.

---

# Part B — Package M Authorization

Authorize Package M now.

```text
PACKAGE M AUTHORIZATION — SERVICE-ROLE / PAYMOB-INITIATE REMEDIATION

Project:
PROJECT_NAME = Al Batal Elite

Staging project:
STAGING_PROJECT_REF = alxwvyflasewslinufqe

Candidate:
CANDIDATE_SHA = e9a6debbb3f807030bab698f8b92241e5b3526d4
FROZEN_TAG = release-candidate/e9a6deb

Finding:
paymob-initiate returns HTTP 500 "Failed to create payment record".
The server-side payment INSERT via service_role appears denied by RLS.
Candidate SQL/RLS design is correct.
Historical paymob_card payments prove the path previously worked.

Owner:
Mustaf Sayed Saeed

Date:
2026-07-28

Approval reference:
PACKAGE-M-SERVICE-ROLE-E9A6DEB

Authorized scope:
1. Verify whether SUPABASE_SERVICE_ROLE_KEY is available to Edge Functions on staging.
2. Verify the service_role credential is current and valid for the staging project.
3. Refresh or set SUPABASE_SERVICE_ROLE_KEY from the Supabase Dashboard if required.
4. Redeploy paymob-initiate from release-candidate/e9a6deb if required.
5. Verify paymob-initiate JWT verification remains enabled.
6. Run a minimal Paymob initiation smoke test using disposable staging data.
7. Record redacted evidence.
8. If smoke passes, prepare a fresh E2E re-run authorization for Paymob/callback/race legs.

Not authorized:
- printing secret values
- pasting secret values into chat, docs, logs, or commits
- modifying source code
- modifying migrations
- modifying Edge Function business logic
- modifying payments RLS design
- setting production secrets
- deploying to production
- running the full Paymob/callback/race E2E matrix before fresh authorization
- merge to master
- force push
- deleting frozen tags
- final release sign-off

Release verdict remains:
NO-GO
```

---

# Platform Secret Ratification

Because `SUPABASE_SERVICE_ROLE_KEY` is a platform/server credential required by Edge Functions, record this small ratification:

```text
PLATFORM SECRET RATIFICATION — SUPABASE_SERVICE_ROLE_KEY

I approve using and, if necessary, refreshing SUPABASE_SERVICE_ROLE_KEY as a
platform-managed server secret for Edge Functions on staging project
alxwvyflasewslinufqe.

The secret value must not be printed, logged, committed, uploaded, or pasted.
This approval is staging-only.
No production secret is authorized.

Owner: Mustaf Sayed Saeed
Date: 2026-07-28
Approval reference: PLATFORM-SECRET-SERVICE-ROLE-E9A6DEB
```

---

# Package M Diagnosis Steps

## Step 1 — Check secret names only

```bash
supabase secrets list --project-ref alxwvyflasewslinufqe
```

Check whether this name exists:

```text
SUPABASE_SERVICE_ROLE_KEY
```

Do not print the value.

Record only:

```text
SUPABASE_SERVICE_ROLE_KEY present: YES / NO
```

Also record whether these platform names exist:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Again, names only.

---

## Step 2 — Verify service_role database role

Run read-only:

```sql
SELECT
  rolname,
  rolbypassrls
FROM pg_roles
WHERE rolname = 'service_role';
```

Expected:

```text
service_role exists
rolbypassrls = true
```

If `rolbypassrls` is false, stop and record a platform configuration issue.

Do not manually grant bypass unless separately authorized.

---

## Step 3 — Verify payments table design remains correct

```sql
SELECT
  c.relname,
  c.relrowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'payments';
```

Expected:

```text
relrowsecurity = true
```

```sql
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'payments'
ORDER BY policyname;
```

Expected:

```text
payments_select_own SELECT
no INSERT policy
```

This is correct because payment INSERT must happen via service_role bypass.

---

## Step 4 — Check Edge Function logs in Dashboard

Open:

```text
Supabase Dashboard
→ Edge Functions
→ paymob-initiate
→ Logs
```

Trigger one disposable initiation attempt if needed.

Look for redacted error indicators:

```text
missing SUPABASE_SERVICE_ROLE_KEY
invalid API key
401 from PostgREST
403 from PostgREST
relation payments does not exist
permission denied
JWT expired
signature mismatch
```

Do not copy secret values.

Record only:

```text
Log error class:
Redacted message:
Likely cause:
```

---

# Package M Remediation Paths

## Path A — SUPABASE_SERVICE_ROLE_KEY missing

If the secret name is missing, set it using the Supabase Dashboard or CLI.

Do not paste the value into chat.

If using CLI and it supports secret entry without echoing:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY --project-ref alxwvyflasewslinufqe
```

If the CLI requires a value argument, prefer the Dashboard to avoid shell history exposure.

After setting, redeploy:

```bash
cd C:/flutter_projects/albatal-candidate-post-l
git rev-parse HEAD
```

If this worktree is not at `e9a6deb`, create one:

```bash
git worktree add ../albatal-candidate-e9a6deb release-candidate/e9a6deb
cd ../albatal-candidate-e9a6deb
git rev-parse HEAD
```

Expected:

```text
e9a6debbb3f807030bab698f8b92241e5b3526d4
```

Deploy only `paymob-initiate`:

```bash
supabase functions deploy paymob-initiate --project-ref alxwvyflasewslinufqe
```

Verify JWT verification remains enabled for `paymob-initiate`.

Do not deploy `paymob-callback` with JWT verification enabled if you redeploy it later.

---

## Path B — SUPABASE_SERVICE_ROLE_KEY present but stale/invalid

If the name exists but logs show invalid key / 401 / 403 / signature mismatch:

1. Refresh the staging `service_role` key from the Supabase Dashboard.
2. Update the Edge Function secret `SUPABASE_SERVICE_ROLE_KEY` with the refreshed value.
3. Redeploy `paymob-initiate`.

Do not print the old or new value.

Record only:

```text
SUPABASE_SERVICE_ROLE_KEY refreshed: YES
Redeployed paymob-initiate: YES
```

---

## Path C — service_role role missing BYPASSRLS

If:

```sql
SELECT rolbypassrls FROM pg_roles WHERE rolname = 'service_role';
```

returns false, stop.

Record:

```text
PACKAGE M BLOCKED — service_role lacks BYPASSRLS
```

This is a platform-level issue and requires explicit separate authorization to modify role attributes.

---

## Path D — Source defect suspected

If logs show a code exception unrelated to missing/invalid service_role credential, stop.

Do not modify source under Package M.

Create:

```text
PACKAGE N — PAYMOB-INITIATE SOURCE DEFECT REMEDIATION
```

---

# Package M Smoke Test

After remediation, run only a minimal smoke test.

Do not run the full Paymob matrix yet.

Smoke test steps:

```text
1. Create disposable authenticated user.
2. Create disposable address.
3. Create disposable order via create_checkout_order with payment_method = paymob_card.
4. Call paymob-initiate with user JWT and order_id.
5. Expect HTTP 200 and checkout_url.
6. Query payments as owner.
7. Expect one paymob_card payment row:
   - status = pending
   - amount = order total
   - paymob_order_id not null
8. Do not complete the payment.
```

Expected smoke result:

```text
paymob-initiate: 200
checkout_url present
payment row created
paymob_order_id present
status pending
```

If smoke fails, do not authorize full E2E re-run.

Record:

```text
PACKAGE M SMOKE: FAIL
Redacted response:
Likely cause:
```

---

# Package M Evidence

Create:

```text
docs/evidence/e9a6deb/PACKAGE_M_SERVICE_ROLE_FIX.md
```

Include:

```md
# Package M — Service Role / Paymob-Initiate Remediation

Candidate: e9a6debbb3f807030bab698f8b92241e5b3526d4
Frozen tag: release-candidate/e9a6deb
Staging project: alxwvyflasewslinufqe
Date: 2026-07-28
Executed by: Mustaf Sayed Saeed
Approval reference: PACKAGE-M-SERVICE-ROLE-E9A6DEB

## Secret name check

SUPABASE_SERVICE_ROLE_KEY present: YES / NO
SUPABASE_URL present: YES / NO
SUPABASE_ANON_KEY present: YES / NO

## service_role role check

rolbypassrls: true / false

## payments design check

RLS enabled: YES / NO
INSERT policies: 0
SELECT policy: payments_select_own

## Edge Function log diagnosis

Redacted error class:
Likely cause:

## Remediation action

Secret refreshed: YES / NO
paymob-initiate redeployed: YES / NO
JWT verification enabled: YES / NO

## Smoke test

paymob-initiate HTTP status:
checkout_url present: YES / NO
payment row created: YES / NO
payment status:
paymob_order_id present: YES / NO

## Smoke verdict

PASS / FAIL

## Next step

Full Paymob/callback/race E2E re-run authorized: YES / NO
```

Secret scan before committing:

```bash
grep -E "eyJ|PAYMOB_API_KEY=|PAYMOB_HMAC_SECRET=|SUPABASE_SERVICE_ROLE_KEY=|BEGIN PRIVATE KEY|MII" docs/evidence/e9a6deb/PACKAGE_M_SERVICE_ROLE_FIX.md || echo "clean"
```

Expected:

```text
clean
```

---

# Fresh E2E Re-Run Authorization

Only record this if Package M smoke passes.

```text
STAGING E2E RE-RUN AUTHORIZATION — PAYMOB / CALLBACK / RACE

Project:
PROJECT_NAME = Al Batal Elite

Staging project:
STAGING_PROJECT_REF = alxwvyflasewslinufqe

Candidate:
CANDIDATE_SHA = e9a6debbb3f807030bab698f8b92241e5b3526d4
FROZEN_TAG = release-candidate/e9a6deb

Prior E2E reference:
STAGING-E2E-E9A6DEB-2026-07-28

Package M reference:
PACKAGE-M-SERVICE-ROLE-E9A6DEB

Package M smoke:
PASS

I authorize re-running the previously blocked E2E legs against staging only:

1. COD regression smoke:
   - happy path
   - idempotent confirm
   - non-owner denial
   - anonymous denial

2. Paymob sandbox matrix:
   - initiation
   - success
   - decline
   - cancel/close/retry

3. Callback security matrix:
   - forged HMAC
   - amount mismatch
   - duplicate callback
   - late callback after expiry

4. Race/concurrency matrix:
   - duplicate concurrent callbacks
   - callback versus expiry
   - concurrent confirmation where applicable

Secret scope:
- Ratified application secret names:
  CORS_ALLOWED_ORIGINS
  PAYMOB_IFRAME_ID
  SCHEDULER_SECRET
  NOTIFICATIONS_INTERNAL_KEY
  PAYMOB_API_KEY
  PAYMOB_HMAC_SECRET
  PAYMOB_INTEGRATION_ID
- Platform secret:
  SUPABASE_SERVICE_ROLE_KEY

No secret values may be printed, logged, committed, uploaded, or pasted.

Exclusions:
- No production project
- No production Paymob credentials
- No source-code commits
- No migration changes
- No Edge Function business logic changes
- No merge to master
- No force push
- No Android release operations
- No beta release
- No final release sign-off

Release verdict remains:
NO-GO
```

---

# If Package M Smoke Passes

Then execute:

```text
1. COD regression smoke
2. Paymob sandbox matrix
3. Callback security matrix
4. Race/concurrency matrix
```

If all pass, update the release gate:

```text
COD E2E: VERIFIED — staging only
Paymob sandbox E2E: VERIFIED — staging only
Forged HMAC: VERIFIED — staging only
Amount mismatch: VERIFIED — staging only
Duplicate callback: VERIFIED — staging only
Late callback: VERIFIED — staging only
Race/concurrency: VERIFIED — staging only
```

Then push the final E2E evidence additively.

---

# If Package M Smoke Fails

Do not re-run full E2E.

Record:

```text
PACKAGE M SMOKE: FAIL
PAYMOB E2E: BLOCKED
RELEASE: NO-GO
```

Then decide between:

```text
PACKAGE M continued — deeper secret/deployment diagnosis
```

or:

```text
PACKAGE N — source defect remediation
```

depending on the redacted log evidence.

---

# Final Decision

```text
PUSH BLOCKED EVIDENCE NOW: APPROVED
PACKAGE M SERVICE-ROLE REMEDIATION: AUTHORIZED
FULL PAYMOB/CALLBACK/RACE E2E RE-RUN: NOT AUTHORIZED UNTIL PACKAGE M SMOKE PASS
RELEASE: NO-GO
```

Your immediate next actions are:

```text
1. Push the blocked E2E evidence and Package M document additively.
2. Execute Package M diagnosis.
3. Refresh/set SUPABASE_SERVICE_ROLE_KEY if required, without printing it.
4. Redeploy paymob-initiate from release-candidate/e9a6deb if required.
5. Run the minimal Paymob initiation smoke test.
6. If smoke passes, record the fresh E2E re-run authorization and execute the blocked Paymob/callback/race legs.
```