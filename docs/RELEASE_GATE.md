# RELEASE_GATE.md — Governance and Release Gate

**Project:** Al Batal Elite  
**Review date:** 2026-07-26  
**Current verdict:** **NO-GO**  
**Staging candidate SHA:** `b74d32653462d555213ac171b12f0f4b7cded7ad` (tag `release-candidate/b74d326`, branch `fix/package-k-security-grants`; designation ref `STAGING-CANDIDATE-B74D326-2026-07-28`; supersedes `fee90bb2365d4709e6a84161f923bacc014a21af`)  
**Production candidate SHA:** `fc0b2a2` — PR #8 merged to `master` 2026-08-23T14:16:01Z; CI run `32644307832` all 7 jobs GREEN at HEAD `ff0bbcf`; Git frozen for production: **YES**
**Phase 0 planning status:** **APPROVED FOR PLANNING AND CONTROLLED EXECUTION**  
**Approval reference:** `PHASE0-ALBATAL-2026-07-26-001`  
**Phase 0 approver:** Mustafa Sayed — Solo Owner  
**Decision-owner status:** **APPROVED — SOLO OWNER MODEL**

## Named approver placeholders

Named people, signatures, and dates are required. Role placeholders alone do
not constitute approval.

| Gate | Required approver role | Approver name | Signature / approval reference | Date | Status |
|---|---|---|---|---|---|
| Product | Product Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| Engineering | Engineering Lead | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| QA | QA Lead | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |
| Security | Security Owner | Mustafa Sayed | `PHASE0-ALBATAL-2026-07-26-001` | 2026-07-26 | APPROVED |

## Phase 0 authorization boundary

The referenced approval authorizes controlled remediation planning and
verification only. It does not authorize production deployment, public launch,
Paymob production-key cutover, beta release, or migration promotion to
production. The release candidate SHA remains pending until a clean PR and green
CI produce a frozen candidate.

## Current release status

| Area | Status | Required condition |
|---|---|---|
| Phase 0 planning | AUTHORIZED | Scoped authorization `PHASE0-ALBATAL-2026-07-26-001` |
| Phase 0 decision ownership | COMPLETE | All nine decisions approved by Mustafa Sayed under the documented solo-owner model |
| Staging acceptance | NO-GO | Live database, security, COD, Paymob, and observability evidence |
| Android release | NO-GO | Verified signed artifact tied to the candidate SHA |
| Production release | NO-GO | All technical gates and all four approvals complete |

## Technical gates

| Gate | Status | Required evidence | Evidence reference |
|---|---|---|---|
| Decisions approved | PASS | Nine approved decisions with named solo owner and date | `docs/DECISIONS.md` |
| Git frozen | **PASS** (2026-08-23) | Clean reviewed candidate, immutable SHA, green CI | Merge commit `fc0b2a2` (PR #8, conflict-free, verifier sub-agent SAFE); CI `32644307832` = 7/7 green incl. signed Android build |
| Migration parity | VERIFIED (staging, 2026-07-28) | No unresolved repository/staging drift | `docs/MIGRATION_PARITY.md`, `docs/evidence/staging-deployment-2026-07-28.md` (provenance reconciliation §Post-Remediation Review) |
| RPC grants | VERIFIED (staging, 2026-07-28, post-029) | Raw staging grant queries for all 9 critical RPCs | All 9 RPCs match target matrix after migration 029 applied; anon/public table DML grants 30→0 (`docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md` Checks 3–4; `test_029_security_grant_repairs.sql` PASS) |
| Edge Functions | VERIFIED (staging, 2026-07-28) | Function list/auth settings tied to candidate SHA | `docs/evidence/staging-deployment-2026-07-28.md` (Phase 3 + §Governance Closure Addendum: ezbr_sha256 bundle digests, git blob + SHA-256 source digests at `fee90bb2`) |
| Secrets | VERIFIED (staging, 2026-07-28) | Names-only inventory; values never recorded | `docs/evidence/staging-deployment-2026-07-28.md` (§Secret Scope Disposition; names only, no values) |
| CORS | PASS (scoped) | Allowed and disallowed origin probes | Test 1 (approved origin) = **N/A — mobile-only scope, no approved web origin**; Test 2 (disallowed origin) = PASS, `docs/evidence/staging-deployment-2026-07-28.md` (Phase 4) |
| COD E2E | NO-GO | Flutter flow plus order/payment/stock evidence | `[LINK REQUIRED]` |
| Paymob sandbox E2E | NO-GO | Initiation, success, decline, cancel/retry, duplicate, mismatch, late callback | `[LINK REQUIRED]` |
| RLS adversarial | VERIFIED (staging, post-030, 2026-07-28) | Required anonymous, IDOR, admin, and payment-denial tests pass live | **44/44 PASS** after migration 030 dropped the redundant `profiles_update_own` policy (fixes RLS-ESC-001; was 41/44): `docs/evidence/6c8521a/POST_030_STAGING_VERIFICATION.md` |
| Race conditions | NO-GO | Concurrent state/stock tests pass exactly once | `[LINK REQUIRED]` |
| Sentry | NO-GO | Controlled staging event with scrubbed context | `[LINK REQUIRED]` |
| Android signed artifact | NO-GO (evidence exists, re-tie pending) | Signature, package, debuggable, checksum, provenance | `docs/evidence/eebcc4d/RELEASE_APK_PROOF.md` (78MB, v2 signed, no `.env`, 243 tests); tied to `eebcc4d` — must be re-tied to the final designated candidate SHA |
| Release sign-off | NO-GO | Four signatures in `docs/RELEASE_SIGNOFF.md` | `docs/RELEASE_SIGNOFF.md` |

## Independent post-remediation review — 2026-07-28

An independent, isolated review (MiMo v2.5 release-safety prompt, executed by a
read-only subagent against the repository and sanitized deployment evidence)
returned **no Critical or High findings**. Two Medium and three Low findings
were recorded in `docs/evidence/staging-deployment-2026-07-28.md`
(§Independent Review) for follow-up; none block staging.

Scope of this section — what is verified:

- **Migration provenance:** the six migrations {022, 024, 025, 026, 027, 028}
  present in the staging ledger were content-verified (MD5 after whitespace
  normalization) against the committed files at `fee90bb2`; ledger names match
  filenames; no NULL/empty ledger rows (no manual history insertion); 27↔27
  local/remote parity via `supabase migration list --linked`. Open finding:
  the exact timestamp/session of the prior `db push` is undocumented in repo
  governance records (ledger has no timestamp column; `STATE.md` predates it).
- **Secret scope:** names-only inventory reconciled; approved 4 present;
  extra 3 `PAYMOB_*` secrets are code-required (disposition table in evidence
  file); legacy/duplicate names flagged for authorized-operator disposition.
  No values were read or recorded.
- **CORS:** approved-origin Test 1 = N/A (mobile-only scope, operator-waived);
  disallowed-origin Test 2 retained and PASS.

### Governance closure addendum — 2026-07-28 (same day, follow-up)

- **Candidate-SHA tie:** deployment evidence tied to
  `fee90bb2365d4709e6a84161f923bacc014a21af` — working-tree parity proven
  (empty `git diff` for `supabase/functions`), per-file git blob + SHA-256
  source digests recorded, and platform `ezbr_sha256` bundle digests captured
  for all five live functions (see evidence §Governance Closure Addendum,
  including the stated bundle-rebuild limitation).
- **Secret scope ratified (owner, 2026-07-28):** approved staging scope is now
  **7 names** — the original 4 plus `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`,
  `PAYMOB_INTEGRATION_ID`. The 4 legacy/platform-adjacent names remain
  unchanged pending separately approved fallback/platform-injection analysis.
- **Retained gap:** the undocumented timing of the prior migration push stays
  on record as an open governance gap; it is not converted to a pass.

### E2E authorization HALT — 2026-07-28

The draft authorization `STAGING-E2E-FEE90BB2-2026-07-28` was **NOT recorded**:
its own consistency check failed. `fee90bb2` is superseded by
`b74d32653462d555213ac171b12f0f4b7cded7ad` (tag `release-candidate/b74d326`,
branch `fix/package-k-security-grants`, adds migration
`029_security_grant_repairs.sql`), and live read-only checks show 029's
repairs are **required but not applied**: anon INSERT/UPDATE/DELETE grants on
all 10 private tables (30 rows), and anon/authenticated EXECUTE on
`decrement_stock`, `increment_stock`, `expire_pending_order`, plus anon on
`set_payment_provider_order_id`. Full record:
`docs/evidence/staging-deployment-2026-07-28.md` (§E2E Authorization HALT
Record). Consequently the RPC-grants row above is scoped to the four checkout
RPCs only; the wider grant surface is FAIL until 029 is applied and verified.
E2E remains **NO-GO** pending: owner designation of `b74d326` as candidate,
authorized application of 029, post-Package-K DB catalog PASS, and a reissued
authorization referencing `b74d326` and the exact ratified seven-name secret
scope.

### Candidate designation + K3 authorization — 2026-07-28

- **Designation recorded** (`STAGING-CANDIDATE-B74D326-2026-07-28`):
  authoritative staging candidate is `b74d32653462d555213ac171b12f0f4b7cded7ad`
  (tag `release-candidate/b74d326`); `fee90bb2` superseded and must not be
  used for E2E; production candidacy NOT approved. Full text in
  `docs/evidence/staging-deployment-2026-07-28.md` (§Candidate Designation).
- **K3 authorized** (`PACKAGE-K3-APPLY-029-B74D326`): apply migration 029 to
  staging from the frozen tag via `supabase db push`, followed by the five
  post-K DB catalog checks and the 029/RLS-adversarial SQL suites; evidence
  in `docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md`; docs-only commit and
  push on the docs evidence branch. E2E, Paymob traffic, Edge Function
  deployment, and secret changes remain excluded.
- The corrected E2E authorization (`STAGING-E2E-B74D326-2026-07-28`) is to be
  recorded **only after** post-K ALL-PASS.

### K3 execution result — 2026-07-28 (post-029)

- Migration 029 **APPLIED** to staging from the frozen tag (dry-run confirmed
  only 029 pending). Evidence: `docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md`.
- **DB catalog: PASS** — all five checks (ledger high-water 029; payments INSERT
  policies absent; anon/public write grants 30→0; all 9 RPC grants match target;
  RLS enabled on all 10 tables). `test_029_security_grant_repairs.sql` PASS.
- **RLS adversarial: FAIL** — 41/44 PASS; 3 FAIL trace to a single confirmed
  vulnerability **RLS-ESC-001** (profiles admin self-escalation): the redundant
  `profiles_update_own` policy (created in 002, WITH CHECK null) is OR-combined
  with `profiles_update_own_safe` and defeats its `is_admin` guard. This is an
  RLS-policy defect independent of 029's grant repairs; migration 029 was never
  intended to fix it.
- **E2E NOT authorized.** Post-K is **not** ALL-PASS, so
  `STAGING-E2E-B74D326-2026-07-28` is **not recorded**. Remediation (a new
  migration dropping the redundant policy, then re-run of the adversarial suite)
  requires separate owner authorization. Overall verdict remains **NO-GO**.

Explicit non-approval: this review does **not** authorize E2E payment tests
(COD or Paymob), Android release, production deployment, traffic, commits, or
pushes. **Staging E2E remains BLOCKED** until the owner records the exact
scoped authorization text (staging-only, project `alxwvyflasewslinufqe`,
approved candidate SHA, approved 7-name secret scope; no production
traffic/secrets, commits, pushes, Android release build, unrelated
deployments, or customer traffic). Overall verdict remains **NO-GO**.

## Record reconciliation — 2026-08-23

Read-only re-verification run; no source changes. Reconciles this register
with work completed after the 2026-07-28 entries:

- **RLS adversarial: now VERIFIED** — migration 030 (candidate `6c8521a`,
  tag `release-candidate/6c8521a`, approval `PACKAGE-L3-APPLY-030-6C8521A`)
  dropped the redundant `profiles_update_own` policy; adversarial suite
  **44/44 PASS** on staging (`docs/evidence/6c8521a/POST_030_STAGING_VERIFICATION.md`).
  The K3 §"RLS adversarial FAIL" entry above is superseded.
- **July Paymob blockers resolved live:** `paymob-callback` forged-HMAC probe
  now reaches the function's own HMAC layer (`{"message":"Invalid signature"}`)
  instead of the platform JWT gate — `verify_jwt=false` is deployed correctly;
  `PAYMOB_IFRAME_ID` secret is now present (names-only check).
- **Edge Functions:** all 5 ACTIVE, redeployed 2026-08-23 00:43 UTC.
- **Migration parity:** local/remote in sync through 030.
- **Local evidence:** `flutter test` 243/243 PASS; `flutter analyze` 0 issues.
- **Candidate lineage note:** staging candidates `b74d326` → `6c8521a` →
  `eebcc4d` (APK proof) all precede the current `fix/l2-remediation-package`
  branch state. A fresh post-merge candidate designation is required before
  E2E authorization can be reissued.

## T0 Production Cutover Addendum — 2026-08-24 (031–033, owner-gated dry-run)

**Scope:** T0 hardened production cutover for migrations `031_realtime_and_cron_fix`,
`032_flash_sales_and_product_images`, `033_admin_catalog_rpcs` onto production
project `alxwvyflasewslinufqe`. Evidence scaffold: `docs/evidence/prod-cutover-031-033/VERIFICATION.md`.
Actual prod `supabase db push` / `functions deploy` / `secrets set` is **owner-gated** and was **not**
executed in this `docs(release)` commit — this addendum records the dry-run checklist and reserves
`TBD prod` slots for live output.

**Plan ref:** `docs/superpowers/plans/2026-08-24-backend-platform-plan.md` Task 10 Steps 2–3.
**Branch:** `feat/backend-platform-t0-t1` base `f38753d`. Staging pre-condition through `030_batch_checkout_variants.sql`
verified (RLS 44/44, Paymob F1–F4 21/21 incl. live auto-callback `521080502`) — see §Record reconciliation and §Isolated-staging E2E.

| Item | Dry-run check (replayable without prod mutation) | Live prod check (owner terminal, `TBD prod` until run) | Status |
|------|---------------------------------------------------|--------------------------------------------------------|--------|
| Backup / PITR | `supabase/config.toml:14` `project_id="alxwvyflasewslinufqe"` + dashboard PITR panel exists | Dashboard screenshot: PITR enabled + last backup `completed` | `PENDING owner-gated` — see VERIFICATION.md §1 |
| `db push --dry-run` | Local `supabase/migrations` pending = `031,032,033` (001–030 parity) | `supabase db push --dry-run --project-ref alxwvyflasewslinufqe` lists exactly `031,032,033` | `TBD prod` — VERIFICATION.md §2 |
| Edge Functions | `supabase/config.toml` `verify_jwt` matrix 5 functions pinned; local digests staged | `supabase functions list --project-ref alxwvyflasewslinufqe` → 5 `ACTIVE`, `verify_jwt` per matrix (`paymob-callback=false`, `cancel-expired-orders=false`, `send-order-notification=false`, `checkout=true`, `paymob-initiate=true`) + `ezbr_sha256` pinned | `TBD prod` — VERIFICATION.md §3 + §9 |
| Realtime publication | `[realtime] enabled=true` local | `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime'` → `payments` count `1`; `ALTER TABLE payments REPLICA IDENTITY FULL` (`relreplident='f'`) | `TBD prod` — VERIFICATION.md §4 |
| Cron | 031 schedules 4 jobs (`cancel-expired-every-5m` `*/5 * * * *` + rollups/retention) | `SELECT * FROM cron.job WHERE jobname='cancel-expired-every-5m'` → `1` active | `TBD prod` — VERIFICATION.md §5 |
| Secrets (names-only) | `config/env.production.json` stays `REPLACE_WITH_*` placeholders in git; real values in `env.production.local.json` (gitignored) + Edge secrets | `supabase secrets list --project-ref alxwvyflasewslinufqe` → 7 names: `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID`, `PAYMOB_IFRAME_ID`, `CORS_ALLOWED_ORIGINS`, `SCHEDULER_SECRET`, `NOTIFICATIONS_INTERNAL_KEY` (values never logged) | `TBD prod` — VERIFICATION.md §6 |
| REST smoke (anon) | — | `curl -H "apikey: $PROD_ANON" https://alxwvyflasewslinufqe.supabase.co/rest/v1/products?select=id&limit=1 | jq length` → HTTP 200 JSON array | `TBD prod` — VERIFICATION.md §7 |
| Paymob live smoke | Staging live `521080502` APPROVED precedent | `TODO owner-gated` — live card approval flips `payments→success`/`orders→paid` without manual replay; HMAC 20-field canonical verified | `TODO owner-gated` — VERIFICATION.md §8 |

**Digests:** `ezbr_sha256` bundle digests are `TBD prod` in VERIFICATION.md §9 until the owner deploys functions; git blob / SHA-256 source digests for `_shared/cors.ts`, `_shared/secrets.ts`, and the five function entrypoints are scaffolded there as `TBD prod` placeholders (no secret values).

**Verdict for this addendum:** `DRY-RUN SCAFFOLD LANDED`. Production cutover remains **NO-GO / owner-gated** until the owner fills the `TBD prod` rows in `docs/evidence/prod-cutover-031-033/VERIFICATION.md` and re-runs the four gates above with live evidence. This docs-only commit does not authorize or perform any prod push.


## Approval rule

The project remains **NO-GO** if any gate is `UNKNOWN`, `PENDING`, or `FAIL`, or
if any required approver signature is missing. Local tests and rolled-back SQL
harnesses support engineering confidence but do not replace live staging proof.

The authoritative Phase 0 register is `docs/DECISIONS.md`. It must remain
**RECOMMENDED APPROVAL — PENDING HUMAN SIGNATURE** until the human signature
record is completed. Use `docs/RELEASE_SIGNOFF.md` for final release evidence
and the four-party decision.

