# DECISIONS.md — Phase 0 Human Authorization Register

**Project:** Al Batal Elite  
**Review date:** 2026-07-26  
**Release verdict:** **NO-GO**  
**Planning authorization:** **APPROVED FOR PLANNING AND CONTROLLED EXECUTION**  
**Approval reference:** `PHASE0-ALBATAL-2026-07-26-001`  
**Final decision-signature status:** **APPROVED AS RECOMMENDED BY SOLO OWNER**

This register records the solo owner's final Phase 0 decisions. It authorizes
controlled remediation planning and implementation within the documented safety
constraints. It does not authorize production deployment, beta, public launch,
or final release.

## Human approval record

| Field | Value |
|---|---|
| Approval status | **APPROVED FOR PLANNING AND CONTROLLED EXECUTION** |
| Approved by | Mustafa Sayed |
| Role | Solo Owner — Product Owner, Engineering Lead, QA Lead, and Security Owner |
| Date | 2026-07-26 |
| Approval reference | `PHASE0-ALBATAL-2026-07-26-001` |
| Release candidate SHA | `PENDING — must be frozen after clean PR and green CI` |

This approval authorizes controlled remediation planning, implementation, and
verification work against the nine approved options. It records the named
solo-owner decision authorization below and does **not** authorize:

- production deployment or public launch;
- Paymob production-key cutover;
- beta release;
- migration promotion to production; or
- any final GO decision.

Approval conditions:

1. All technical gates remain mandatory.
2. Live staging evidence is required before staging acceptance.
3. Signed Android artifact evidence is required before release.
4. Four-party release sign-off is required before production launch.
5. The migration 027 payment-insert contradiction must be resolved before
   further migration promotion.
6. A clean, frozen candidate SHA must exist before live acceptance evidence is
   treated as release evidence.

## Decision register

| # | Decision | Decision status | Recommended option | Final approved option | Owner role | Owner name | Date | Risk if unsigned |
|---:|---|---|---|---|---|---|---|---|
| 1 | Migration repair strategy | APPROVED AS RECOMMENDED | Forward-only repair migration; never renumber or rewrite applied history; preserve unresolved drafts separately | APPROVED — forward-only repair migration | Engineering Lead / DBA | Mustafa Sayed | 2026-07-26 | Schema drift, non-reproducible deployments, and migration-history corruption |
| 2 | COD missing-payment behavior | APPROVED AS RECOMMENDED | Reject with `payment_not_found`; checkout creates the pending COD payment row first | APPROVED — reject with `payment_not_found` | Product Owner + Engineering Lead | Mustafa Sayed | 2026-07-26 | Inconsistent financial state, orphaned orders, and ambiguous recovery |
| 3 | Paymob callback gateway | APPROVED AS RECOMMENDED | Disable platform JWT only for the provider callback; retain mandatory fail-closed HMAC; keep client functions JWT-protected | APPROVED — stated callback exception and HMAC policy | Engineering Lead + Security Owner | Mustafa Sayed | 2026-07-26 | Rejected or spoofable callbacks, payment-state errors, and revenue loss |
| 4 | Staging/production isolation | APPROVED AS RECOMMENDED | Separate Supabase projects and Paymob integrations; never reuse staging credentials in production | APPROVED — separate projects and integrations | Product Owner + Security Owner | Mustafa Sayed | 2026-07-26 | Environment bleed, production mutation, and expanded payment blast radius |
| 5 | Secret provisioning | APPROVED AS RECOMMENDED | Server secrets only in approved server/CI secret stores; only client-safe build variables; never print/package secrets | APPROVED — stated secret-boundary policy | Security Owner + Engineering Lead | Mustafa Sayed | 2026-07-26 | Credential compromise, client-bundle leakage, and secret exposure |
| 6 | Observability | APPROVED AS RECOMMENDED | Sentry with NoOp fallback, PII scrubbing, defined analytics events, alert thresholds, and incident ownership | APPROVED — stated Sentry and privacy policy | Engineering Lead + Security Owner + Product Owner | Mustafa Sayed | 2026-07-26 | Silent crashes, unowned incidents, missed payment failures, or PII leakage |
| 7 | Android release | APPROVED AS RECOMMENDED | Fail-closed signing; no debug fallback; protected CI; signature/package/debuggable checks; reviewed ProGuard rules | APPROVED — stated fail-closed release policy | Engineering Lead + Security Owner | Mustafa Sayed | 2026-07-26 | Unsafe or unverifiable artifacts reaching testers/customers |
| 8 | Beta scope | APPROVED AS RECOMMENDED | Android-only beta for 10–20 users after all P0/P1 gates and release sign-off; defer iOS | APPROVED — Android-only beta for 10–20 users | Product Owner + QA Lead | Mustafa Sayed | 2026-07-26 | Uncontrolled rollout and excessive blast radius |
| 9 | Release-gate ownership | APPROVED AS RECOMMENDED | Four-party approval by Product Owner, Engineering Lead, QA Lead, and Security Owner | APPROVED — solo owner signs in all four governance capacities | Product Owner + Engineering Lead + QA Lead + Security Owner | Mustafa Sayed | 2026-07-26 | No accountable release decision; gates may be bypassed or unresolved |

## Decision-specific constraints

1. **Migration repair:** Do not renumber, delete, or rewrite applied history. Reconcile repository and staging before any application; promote from one frozen SHA.
2. **COD:** The recommended `payment_not_found` behavior requires a pending COD payment row to exist before confirmation. Live staging verification remains required.
3. **Paymob:** JWT is disabled only at the provider callback boundary. HMAC, amount, currency, provider-order mapping, and service-role RPC authorization remain mandatory. A forged callback must reach the function body and return invalid-signature, not a platform JWT error.
4. **Isolation:** Staging and production must use distinct Supabase projects and Paymob integrations. Production identity remains owner-confirmation dependent.
5. **Secrets:** Client-safe build inputs are limited to `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SENTRY_DSN`. Paymob credentials, service-role keys, scheduler secrets, and internal keys remain server-side.
6. **Observability:** Preserve PII scrubbing and NoOp fallback. A staging event and named incident owner are required before acceptance.
7. **Android:** Missing signing inputs must stop the build. Artifact existence alone is not release evidence.
8. **Beta:** Beta is not release authorization and begins only after staging gates and four-party sign-off.
9. **Ownership:** A role without a named person, signature/reference, and date does not satisfy approval.

## Human signature record

| Decision | Required signatory role | Name | Signature / approval reference | Date | Status |
|---:|---|---|---|---|---|
| 1 | Engineering Lead / DBA | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 2 | Product Owner + Engineering Lead | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 3 | Engineering Lead + Security Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 4 | Product Owner + Security Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 5 | Security Owner + Engineering Lead | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 6 | Engineering Lead + Security Owner + Product Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 7 | Engineering Lead + Security Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 8 | Product Owner + QA Lead | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| 9 | Product Owner + Engineering Lead + QA Lead + Security Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |

## Phase 0 gate

**PHASE 0 APPROVED / RELEASE NO-GO.** Mustafa Sayed, acting as the solo owner
for all governance roles, approved all nine recommended decisions under
`PHASE0-ALBATAL-2026-07-26-001`. Controlled planning and implementation may
proceed. Technical evidence and final release acceptance remain separate and
mandatory.

## Package L authorization — RLS-ESC-001 remediation (2026-07-28)

Recorded before starting Package L, per owner directive.

```text
PACKAGE L AUTHORIZATION — RLS-ESC-001 REMEDIATION

Project:
PROJECT_NAME = Al Batal Elite

Finding:
RLS-ESC-001 — authenticated profiles.is_admin self-escalation

Root cause:
Redundant permissive UPDATE policy profiles_update_own from migration 002
has no WITH CHECK and defeats profiles_update_own_safe from migration 003.

Current staging candidate:
CANDIDATE_SHA = b74d32653462d555213ac171b12f0f4b7cded7ad
FROZEN_TAG = release-candidate/b74d326

Owner:
Mustaf Sayed Saeed

Date:
2026-07-28

Approval reference:
PACKAGE-L-RLS-ESC-001-2026-07-28

Authorized scope:
1. Create a new branch from release-candidate/b74d326.
2. Add forward-only migration 030_fix_profiles_admin_escalation.sql.
3. The migration must drop profiles_update_own if it exists.
4. The migration must refuse to proceed if profiles_update_own_safe is missing.
5. Add read-only verification SQL for the policy fix.
6. If required to run test_rls_adversarial.sql cleanly, make minimal test-harness
   compatibility fixes only.
7. Test-harness fixes must not weaken assertions, remove adversarial cases,
   or change expected security outcomes.
8. Push the new branch and open a draft PR.
9. Wait for CI green.
10. Freeze a new candidate tag after CI green.
11. Apply migration 030 to staging from the new frozen candidate.
12. Re-run the five DB catalog checks.
13. Re-run test_rls_adversarial.sql.
14. Record evidence in docs/evidence/<NEW_SHORT_SHA>/.

Not authorized:
- modifying release-candidate/b74d326
- deleting frozen tags
- force push
- merge to master
- applying migration 030 before CI green and new tag freeze
- Edge Function deployment
- secret changes
- E2E payment tests
- Paymob sandbox traffic
- Android release operations
- production activity
- beta release
- final release sign-off

Release verdict remains:
NO-GO
```

## Package L.1 authorization — adversarial suite harness repair (2026-07-28)

```text
PACKAGE L.1 AUTHORIZATION — ADVERSARIAL SUITE HARNESS REPAIR

Project: Al Batal Elite
Base candidate: 6c8521a90f4600f6038bcf20b425cd04d0fa5095
Base tag: release-candidate/6c8521a

Finding:
The canonical supabase/tests/test_rls_adversarial.sql is a psql script and cannot
execute via the Supabase db query endpoint. The validated runner copy produced
44 PASS / 0 FAIL but is not the committed formal test instrument.

Owner: Mustaf Sayed Saeed
Date: 2026-07-28
Approval reference: PACKAGE-L1-HARNESS-6C8521A

Authorized scope:
1. Create follow-up branch fix/package-l1-rls-harness from release-candidate/6c8521a.
2. Add committed executable suite supabase/tests/test_rls_adversarial_dbquery.sql,
   derived from the validated runner copy (44 checks, all security expectations
   preserved, BEGIN/ROLLBACK, no psql meta-commands).
3. Optional mechanics-only repair of the original psql suite (retained, not deleted).
4. Push branch, open draft PR, wait CI green, freeze new candidate tag, re-run
   committed suite against staging, record evidence.

Not authorized:
- changing expected PASS/FAIL outcomes, removing adversarial cases, weakening
  assertions, marking known vulns as expected failures
- modifying migrations / Edge Functions / Flutter / Android / secrets
- E2E payment tests, Paymob sandbox traffic
- merge to master, force push, deleting frozen tags, production activity,
  final release sign-off

Release verdict remains:
NO-GO
```

## Staging E2E authorization reissued after L.1 pass (2026-07-28)

Condition met: committed executable suite `supabase/tests/test_rls_adversarial_dbquery.sql`
passed 44/0 against post-030 staging on frozen candidate release-candidate/e9a6deb.

```text
STAGING E2E AUTHORIZATION — STAGING ONLY

Project: Al Batal Elite
Staging project: alxwvyflasewslinufqe

Authoritative staging candidate:
CANDIDATE_SHA = e9a6debbb3f807030bab698f8b92241e5b3526d4
SHORT_SHA = e9a6deb
FROZEN_TAG = release-candidate/e9a6deb

Candidate status:
Staging candidate only. Production candidacy NOT approved.
Git frozen for production remains NO-GO.

Owner: Mustaf Sayed Saeed
Date: 2026-07-28
Approval reference: STAGING-E2E-E9A6DEB-2026-07-28

Preconditions (all satisfied):
- Migration 028 applied.
- Migration 029 applied.
- Migration 030 applied.
- All five DB catalog checks PASS.
- test_029_security_grant_repairs.sql PASS.
- test_030_profiles_admin_escalation_fix.sql PASS.
- supabase/tests/test_rls_adversarial_dbquery.sql PASS with 44/0.
- RLS-ESC-001 remediated.
- Evidence recorded (docs/evidence/e9a6deb/RLS_ADVERSARIAL_EXECUTABLE_PASS.md).

Secret scope: only the seven ratified secret names; no values printed/logged/committed;
no secrets set, rotated, or removed.

Exclusions: no production project/credentials, no merge to master, no force push,
no frozen tag deletion, no source-code commits, no candidate-branch pushes beyond
docs evidence branch, no new migrations, no Edge Function deployments, no config.toml
changes, no Android build/release, no beta release, no final release sign-off.

Release verdict remains:
NO-GO
```

Note: this records the authorization only. Actual E2E test execution and the
docs-evidence-branch push are pending explicit owner go.
