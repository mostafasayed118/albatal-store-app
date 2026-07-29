# RLS Adversarial Executable Suite — Post-Package-L1

- **Project:** Al Batal Elite
- **Candidate SHA:** e9a6debbb3f807030bab698f8b92241e5b3526d4
- **Short SHA:** e9a6deb
- **Frozen tag:** release-candidate/e9a6deb
- **Base candidate:** 6c8521a90f4600f6038bcf20b425cd04d0fa5095 (release-candidate/6c8521a)
- **Branch:** fix/package-l1-rls-harness
- **PR:** https://github.com/mostafasayed118/albatal-store-app/pull/7 (draft, base master)
- **CI run:** https://github.com/mostafasayed118/albatal-store-app/actions/runs/30393923756
- **CI verdict:** GREEN WITH DEFERRED ANDROID
- **Staging project:** alxwvyflasewslinufqe
- **Date:** 2026-07-28
- **Approval reference:** PACKAGE-L1-HARNESS-6C8521A

## Staging migration state

high_water: 030 (verified via `SELECT max(version) FROM supabase_migrations.schema_migrations`)

## Executed suite

`supabase/tests/test_rls_adversarial_dbquery.sql`

- Committed executable instrument (this candidate), byte-identical to the validated
  runner copy `scripts/run_rls_adversarial_dbquery.sql` (equivalence diff empty).
- No psql meta-commands; BEGIN…ROLLBACK framed (seed data discarded); 44 adversarial
  checks; no security expectations weakened.

## Result

```json
{ "failed": 0, "failures": null, "passed": 44, "total": 44 }
```

**44 PASS / 0 FAIL.** (Pre-030 baseline: 41 PASS / 3 FAIL on tests 3.7/3.8/3.9.)

## RLS-ESC-001 status

REMEDIATED.

## CI check summary (PR #7)

| Check | Result |
|---|---|
| Setup & Cache | green |
| Format & Analyze | green |
| Flutter Tests | green |
| Edge Function Tests | green |
| Secret Scan | green |
| Deployment Readiness | green |
| Android Release Build | failed only at "Verify signing secrets present" (deferred) |

## E2E precondition

SATISFIED — committed executable adversarial suite passes 44/0 against post-030 staging.

## Gate status

- RELEASE: **NO-GO**.
- Production: NOT AUTHORIZED. Frozen tags preserved: 484a3ea, b74d326, 6c8521a, e9a6deb.
