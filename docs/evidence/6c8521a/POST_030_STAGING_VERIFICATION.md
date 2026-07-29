# Post-030 Staging Verification — Candidate 6c8521a

- **Project:** Al Batal Elite
- **Staging project:** alxwvyflasewslinufqe
- **Candidate SHA:** 6c8521a90f4600f6038bcf20b425cd04d0fa5095
- **Frozen tag:** release-candidate/6c8521a
- **Branch:** fix/package-l-rls-escalation
- **Date:** 2026-07-28
- **Approval reference:** PACKAGE-L3-APPLY-030-6C8521A

## Migration application

- `supabase db push --dry-run` → only `030_fix_profiles_admin_escalation.sql` pending.
- `supabase db push` → migration 030 applied. Finished.

## Post-030 consolidated verification (`scripts/_pkgL/post_030_verify.sql`)

| Check | Expected | Result |
|---|---|---|
| Migration ledger high_water | 030 | **030** ✅ |
| Unsafe policy `profiles_update_own` count | 0 | **0** ✅ |
| `profiles_update_own_safe` present, WITH CHECK not null | 1 row, not null | **present, with_check_not_null=true** ✅ |
| UPDATE policies on `profiles` with null WITH CHECK | 0 | **0** ✅ |
| `payments` INSERT policies (own/authenticated_own) | 0 | **0** ✅ |
| anon/public write grants on core tables | 0 | **0** ✅ |
| RLS-enabled core tables | 10 | **10** ✅ |
| RPC EXECUTE matrix (6 fns) | anon=false everywhere; matrix per post-029 | **anon=false everywhere; matrix intact** ✅ |

RPC matrix (anon / authenticated / service_role EXECUTE):

| Function | anon | authenticated | service_role |
|---|---|---|---|
| confirm_cod_payment | false | true | true |
| decrement_stock | false | false | true |
| expire_pending_order | false | false | true |
| increment_stock | false | false | true |
| process_paymob_callback | false | false | true |
| set_payment_provider_order_id | false | true | true |

## test_030 (`supabase/tests/test_030_profiles_admin_escalation_fix.sql`)

Confirms `profiles_update_own` absent and `profiles_update_own_safe` retained with the
`is_admin` guard (WITH CHECK not null). Assertions covered in full by the consolidated
query above.

## RLS adversarial suite

- **Canonical `supabase/tests/test_rls_adversarial.sql`:** cannot execute via the
  Supabase `db query` endpoint — fails on psql runner mechanics with
  `ERROR: 42601 syntax error at or near "\"` at `\set ECHO on` (line 38). This is a
  runner-mechanics defect, not a security finding.
- **Transaction-framed runner copy `scripts/run_rls_adversarial_dbquery.sql`**
  (BEGIN…ROLLBACK; no seed data persists) executed against post-030 staging:

  ```json
  { "failed": 0, "failures": null, "passed": 44, "total": 44 }
  ```

  Pre-030 baseline was 41 PASS / 3 FAIL (tests 3.7 / 3.8 / 3.9 = RLS-ESC-001).
  Post-030: **44 PASS / 0 FAIL**.

## Verdict

- **RLS-ESC-001: REMEDIATED** (DB-proven via consolidated verification + adversarial
  runner copy 0 FAIL).
- **Canonical adversarial suite: NOT YET EXECUTABLE** via db-query runner (psql
  mechanics). Per the owner decision tree this is a runner-mechanics-only failure and
  triggers a Package L.1 harness repair (mechanics only, no expectation changes, no test
  deletions) on a follow-up branch since the candidate is already frozen.

### Gate status

- E2E: **NOT AUTHORIZED** — formal precondition requires the canonical
  `test_rls_adversarial.sql` to run 0 FAIL; that awaits Package L.1.
- RELEASE: **NO-GO**.
- `STAGING-E2E-6C8521A-2026-07-28`: **NOT RECORDED**.

### Not authorized / not performed

E2E payment tests, Paymob sandbox traffic, Edge Function deployment, secret changes,
merge to master, force push, production activity.
