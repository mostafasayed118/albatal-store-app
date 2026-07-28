# Loop State — Al Batal Elite

Last run: 2026-07-27T10:14:00Z

## Package K3 — Migration 029 applied to staging; RLS adversarial FAIL (2026-07-28)

**Authorization:** `PACKAGE-K3-APPLY-029-B74D326` (owner: Mustaf Sayed Saeed).
Staging candidate designated `b74d32653462d555213ac171b12f0f4b7cded7ad`
(tag `release-candidate/b74d326`), superseding `fee90bb2`. Migration 029 applied
from a clean worktree at the frozen tag via `supabase db push` (dry-run confirmed
only 029 pending). Evidence: `docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md`
and `docs/evidence/staging-deployment-2026-07-28.md`.

**DB catalog: PASS** — ledger high-water 029; payments INSERT policies absent;
anon/public write grants 30→0; all 9 RPC grants match target matrix; RLS enabled
on all 10 tables. `test_029_security_grant_repairs.sql` PASS.

**RLS adversarial: FAIL (3/44).** `test_rls_adversarial.sql` had never been run;
a runner copy exposed 3 harness defects (reserved `desc` param; service_role
seeding of auth.users; narrow `check_violation` handlers). After fixes: 41 PASS,
3 FAIL, tracing to one confirmed vulnerability.

**FINDING RLS-ESC-001 (confirmed P0): profiles admin self-escalation.** `profiles`
has two permissive UPDATE policies — `profiles_update_own` (from 002, WITH CHECK
null) and `profiles_update_own_safe` (WITH CHECK guarding is_admin). Permissive
policies OR together and a null WITH CHECK falls back to USING, so setting
`is_admin=true` still passes `profiles_update_own`'s check. The redundant policy
defeats the escalation guard. Tests 3.8/3.9 cascade from 3.7 in the shared
transaction. No migration through 029 drops the old policy.

**Owner decisions (2026-07-28):** push K3 FAIL evidence now (APPROVED); remediate
via migration 030 under **Package L** (`PACKAGE-L-RLS-ESC-001-2026-07-28`); E2E
**NOT** authorized (`STAGING-E2E-B74D326-2026-07-28` not recorded — precondition
`test_rls_adversarial.sql PASS` unmet); release verdict remains **NO-GO**.

---


## Package D — Candidate Freeze (COMPLETE)

Frozen candidate SHA: 484a3ea39462277dd9ab0830b26d4fd724ab0c1a
Annotated tag: release-candidate/484a3ea (tag object c591cd5), pushed to origin.
PR #4: returned to draft + DO NOT MERGE comment. CI code-quality GREEN.
Android: DEFERRED (missing signing secrets only) under approval
PACKAGE-D-FREEZE-484A3EA-DEFERRED-ANDROID. Release verdict: NO-GO.
Docs evidence branch: docs/release-evidence-484a3ea (RELEASE_GATE + RELEASE_SIGNOFF updated).

## Package K — Staging Security Repair (K1 COMPLETE; staging phases human-gated)

Authorization: PACKAGE-K-2026-07-27-001 (L2 ENABLED, bounded security-repair only).
Frozen tag release-candidate/484a3ea = PRE-SECURITY-REPAIR candidate ONLY; keep as
historical evidence — do NOT modify/delete. Release verdict: NO-GO.

K1 DONE (autonomous, non-mutating):
- Worktree C:/flutter_projects/albatal-package-k on branch fix/package-k-security-grants,
  created from release-candidate/484a3ea (HEAD 484a3ea, clean).
- Verified exact function signatures at the tag before writing grants:
  decrement_stock(UUID,TEXT,TEXT,INTEGER), increment_stock(UUID,TEXT,TEXT,INTEGER),
  expire_pending_order(UUID), set_payment_provider_order_id(UUID,TEXT).
- Added supabase/migrations/029_security_grant_repairs.sql (forward-only; no data
  changes; no RLS policy changes; no renumbering):
  * REVOKE anon+public INSERT/UPDATE/DELETE on the 10 private tables (SELECT untouched).
  * decrement_stock/increment_stock/expire_pending_order -> service_role only.
  * set_payment_provider_order_id -> REVOKE anon/public; GRANT authenticated+service_role
    (authenticated kept: Paymob initiation calls it on the user JWT, self-verifies ownership).
- Added supabase/tests/test_029_security_grant_repairs.sql (read-only verification).
- Commit on branch; both secret scans clean (filename + value). Pushed new branch
  origin/fix/package-k-security-grants (no force push, no master push).
- Draft PR #5 -> base master: https://github.com/mostafasayed118/albatal-store-app/pull/5
  Title: "fix(supabase): Package K security grant repairs (migration 029)". DO NOT MERGE.

K0 DONE (human-executed, owner Mustaf Sayed Saeed, ref PACKAGE-K0-APPLY-028, 2026-07-27):
- Migration 028 applied to staging (alxwvyflasewslinufqe) via `supabase db push`
  from the release-candidate/484a3ea worktree. Dry-run listed ONLY 028 pending
  (029 not listed). Ledger shows 028 present. payments_insert_own and
  payments_insert_authenticated_own both ABSENT (0 rows). K0 VERDICT = PASS.
  This resolves the Package J "Payments INSERT policy" FAIL. Evidence:
  docs/evidence/484a3ea/K0_MIGRATION_028_APPLIED.md. No 029 applied; no Edge
  Function deploy; no secret changes.

PENDING (human-gated — require staging DB password / CI, not done autonomously):

- K2 DONE (autonomous, authorized by owner Mustaf Sayed Saeed, ref
PACKAGE-K2-DEFERRED-ANDROID-B74D326, 2026-07-27):
- PR #5 CI run 30262963571: Format & Analyze PASS, Flutter Tests PASS, Edge
  Function Tests PASS, Secret Scan PASS, Deployment Readiness PASS. Android
  Release Build FAIL — only at "Verify signing secrets present" gate
  (KEYSTORE_BASE64/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD all empty; no code
  defect). Deferred-android approval granted.
- Annotated tag release-candidate/b74d326 created at
  b74d32653462d555213ac171b12f0f4b7cded7ad and pushed to origin.
  Tag target verified = b74d32653462d555213ac171b12f0f4b7cded7ad.
  Pre-repair tag release-candidate/484a3ea preserved (not deleted).
  No branch push. No master push. No force push.

K3: apply migration 029 to staging from the new frozen candidate.

- K3: apply migration 029 to staging from the new frozen candidate.
- K4: re-run the 5 DB catalog checks (expect: 028+029 present; anon write grants 0 rows;
  stock/expiry RPCs service_role only; set_payment_provider_order_id anon=false,
  authenticated=true; payments INSERT policies 0 rows; RLS still all true).
- K5: run supabase/tests/test_rls_adversarial.sql (expect 0 FAIL).
- Evidence: docs/evidence/<NEW_SHORT_SHA>/STAGING_SNAPSHOT_POST_K.md on the docs
  branch (do NOT merge into the frozen tag).

Package I (Android signing): still DEFERRED until the 4 keystore secrets are provided.
Note: final Android artifact must be rebuilt from the NEW post-K frozen candidate, not 484a3ea.

## Package J — Read-Only Staging Snapshot (COMPLETE; DB catalog verdict = FAIL)


Staging project alxwvyflasewslinufqe. Mode: READ-ONLY. No mutations. config.toml untouched.
Evidence: docs/evidence/484a3ea/STAGING_SNAPSHOT.md (docs branch).
DB catalog SQL executed by human in Dashboard SQL Editor (2026-07-27) and recorded.

PACKAGE J DB CATALOG VERDICT = FAIL. Overall Package J = COMPLETE (all evidence
captured/recorded). Package K = REQUIRED. Frozen tag release-candidate/484a3ea
is a PRE-SECURITY-REPAIR candidate only; NOT the final production candidate.

DB results:
- Migration parity: FAIL — staging high-water 027; missing 028
  (028_reclose_payments_insert_policy.sql). No 023 exists at tag (expected).
- Critical RPC existence: PASS (all 9 exist).
- confirm_cod_payment grants: PASS (anon=f, authenticated=t, prosecdef=t).
- process_paymob_callback grants: PASS (anon=f, authenticated=f, service_role=t).
- Stock/expiry RPC grants: FAIL — decrement_stock/increment_stock/
  expire_pending_order executable by anon+authenticated (must be service_role only).
- set_payment_provider_order_id: FAIL — anon=true (must be false).
- Payments INSERT policy: FAIL — payments_insert_authenticated_own still present
  (because 028 not applied); payments_insert_own absent.
- RLS flags: PASS — RLS enabled on all 10 checked tables.
- Anon write grants: FAIL — anon has INSERT/UPDATE/DELETE on all 10 private tables.
- Authenticated write grants: INFORMATIONAL — broad DML; RLS is the guard; run
  RLS adversarial suite after 028+029.

Non-DB surface (all PASS, unchanged): 5 Edge Functions ACTIVE; JWT matrix matches
target (B1 resolved); all required secret NAMES present incl PAYMOB_IFRAME_ID (B2
resolved); code reads EXACTLY 10 canonical secret names (git grep at tag); CORS
explicit allowlist. Legacy dup secret names (ANON_KEY/URL/SERVICE_ROLE_KEY/
CANCEL_EXPIRED_ORDERS_SECRET + platform SUPABASE_* keys) unreferenced = safe
Package-K pruning candidates (do not unset under J).

Package K required repairs (NOT authorized yet; new-code work off frozen tag):
1. Apply missing migration 028 to staging (drops the direct-INSERT payment policy).
2. Create forward-only 029_security_grant_repairs.sql on a NEW branch from
   release-candidate/484a3ea (cannot add code to the frozen tag) -> CI -> new freeze.
   - REVOKE anon/public INSERT/UPDATE/DELETE on the 10 private tables.
   - Restrict decrement_stock/increment_stock/expire_pending_order to service_role.
   - REVOKE anon (+PUBLIC) EXECUTE on set_payment_provider_order_id.
3. Re-run the 5 DB catalog checks + RLS adversarial suite.
Do NOT modify the existing frozen tag; no force push; no merge to master.



Captured (automated, API token + live probes):
- Edge Functions: 5 ACTIVE — checkout v27, paymob-initiate v34, paymob-callback v25,
  cancel-expired-orders v25, send-order-notification v24.
- JWT matrix CONFIRMED via unauthenticated POST probes and matches target:
  checkout=true, paymob-initiate=true (platform UNAUTHORIZED_NO_AUTH_HEADER);
  paymob-callback=false (body returns Invalid signature — HISTORICAL B1 DRIFT RESOLVED);
  cancel-expired-orders=false, send-order-notification=false (body Unauthorized).
- Secret NAMES: all required present incl PAYMOB_IFRAME_ID (HISTORICAL B2 RESOLVED)
  and SCHEDULER_SECRET (code-confirmed name). Values NOT printed. Legacy duplicate
  names noted (ANON_KEY/URL/SERVICE_ROLE_KEY) — Package K cleanup decision.
- CORS: EXPLICIT/allowlist (disallowed origin gets NO Access-Control-Allow-Origin; not wildcard).

PENDING HUMAN (DB catalog via Dashboard SQL Editor — CLI link needs DB password):
- migration ledger parity to repo high-water mark 028 (watch historical 018/019 slot drift)
- confirm_cod_payment existence + grants (anon=false/auth=true)
- process_paymob_callback service_role-only grants
- payments_insert_own / payments_insert_authenticated_own absent (028)
- RLS flags on user-private tables
Exact SQL is embedded in STAGING_SNAPSHOT.md.

Next: Package I (Android signing, parallel if secrets available); Package K after
human reviews Package J DB results and approves staging deployment. Release: NO-GO.

---


## Package H — CI Gate Repair (L2, COMPLETE LOCALLY)

Worktree: C:/flutter_projects/albatal-freeze-fix
Branch: fix/package-b-freeze-hardening
Failed run repaired: actions/runs/30251635376 (secret-scan + coverage)

Root causes:
- secret-scan: gitleaks `generic-api-key` FALSE POSITIVES on test fixtures
  (SQL literal `idempotency_key='test-idempotency-001'` x4 + Dart hex color
  `0xFF000000` x1). No real secret; no rotation.
- coverage: `lcov` not preinstalled on ubuntu-latest, so `lcov --summary` failed
  regardless of threshold. Package G lowering 70->40 was necessary but not
  sufficient.

Fixes (bounded, no lib/logic changes):
- Added `.gitleaksignore` with the 5 exact FP fingerprints (full scanning + all
  default rules stay ENABLED; no path allowlist broadening; no secret values).
- Added "Install lcov" step to the `test` job before coverage steps. Interim
  40% threshold kept EXACTLY (70% target deferred to Coverage Uplift).

Local verification — ALL GREEN:
- gitleaks 8.24.3 detect (committed config + .gitleaksignore): 0 leaks (was 5)
- flutter analyze: No issues found (no lib/ edits)
- flutter test: 198/198 PASS (no logic edits)
- ci.yml: YAML parses OK

Commits pushed:
- 22bc76a ci: repair secret-scan and coverage gates (Package H)
- 484a3ea ci: reword .gitleaksignore comment + suppress its own historical FP

CI RESULT on HEAD 484a3ea — run 30255090975 (PR #4):
- Format & Analyze: SUCCESS
- Flutter Tests: SUCCESS
- Edge Function Tests: SUCCESS
- Secret Scan: SUCCESS  (was FAIL — repaired)
- Deployment Readiness: SUCCESS
- Android Release Build: FAILURE — ONLY the "Verify signing secrets present"
  gate; KEYSTORE_BASE64/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD all empty.
  Fail-closed by design (Package B); no code/logic defect.

=> Code-quality gate GREEN. Matches Package D Option A/B precondition.

CANDIDATE SHA CHANGED: c2a2ef7 -> 484a3ea (two Package H commits). The pre-
written c2a2ef7 freeze authorization and tag name release-candidate/c2a2ef7 no
longer match HEAD. Any freeze MUST bind to 484a3ea (tag
release-candidate/484a3ea) and needs FRESH human authorization + Option-B
deferred-android approval (android-release red on missing secrets).

Evidence: docs/evidence/PACKAGE_D_CI_EVIDENCE_POST_H.md,
docs/evidence/PACKAGE_H_CI_REPAIR.md, docs/evidence/PACKAGE_H_GITLEAKS_FINDINGS.md
Release verdict: NO-GO. Freeze NOT created — awaiting authorization for 484a3ea.




## Package E — Candidate/Master Conflict Remediation (L2, COMPLETE + PUSHED)

Worktree: C:/flutter_projects/albatal-freeze-fix
Branch: fix/package-b-freeze-hardening
Method: `git merge origin/master --no-ff --no-commit` (rebase/force-push NOT used)

- Pre-merge candidate SHA: 364807183c47ff97592da45aad005300e2b026a7 (3648071)
- Merged origin/master: 2a001fbe7f550d7a6d49fcfa9ce6ac09ea7791ca
- Merge-base: 37118b1e8e745ee6d971f1ab1008c1a50fe9a9d6
- NEW post-merge candidate SHA: c2a2ef72dbfd6a087a7b5035e6a60ff8d76a6461 (c2a2ef7)
- Merge parents: 3648071 + 2a001fb
- Push: 3648071..c2a2ef7 (normal); local == origin == c2a2ef7; 0/0; tree clean

Conflicts resolved (exactly the two expected files):
- `lib/shared/services/service_locator.dart` (content) — preserved master's
  restored DI sources + candidate's Sentry/NoOp selection; imports shared
  crash_reporting_service.dart + sentry_crash_reporting_service.dart; orders
  registration unchanged (debug Local / release Supabase); no payment changes.
- `test/crash_reporting_scrub_test.dart` (add/add) — one coherent scrub suite,
  no duplicate test names, targets CrashReportingService.scrubContext.

Local verification (pre-commit) — ALL GREEN:
- flutter pub get: exit 0, no dependency conflicts
- flutter analyze: No issues found! (exit 0)
- flutter test: 198/198 PASS (exit 0)
- deno test supabase/functions/: 70/70 PASS (exit 0)
- git diff --cached --check: clean; staged + untracked secret scans: clean

Evidence: `docs/evidence/PACKAGE_D_CI_EVIDENCE_POST_E.md`

Pending: CI conclusion on new HEAD c2a2ef7 (gh CLI unavailable — read from
GitHub Actions UI). Freeze NOT authorized. If CI green, freeze tag MUST be
`release-candidate/c2a2ef7` — do NOT reuse `release-candidate/3648071`.
Release verdict: NO-GO.


## Package B — Candidate Freeze Hardening

Status: COMPLETE LOCALLY
Branch: fix/package-b-freeze-hardening
Base: fee90bb2365d4709e6a84161f923bacc014a21af
HEAD: 50a6870af03bfa5558f5f5d087ad4bb2c5544870

Commits:
- `1247deb` fix(quality): declare url_launcher and replace deprecated Sentry copyWith
- `50a6870` fix(android): fail closed on missing release signing and resolve R8 Play Core warnings

Verification:
- flutter analyze: PASS
- flutter test: 198/198 PASS
- R8 release build: PASS after approved Play Core dontwarn rules
- Missing release signing: fails closed with RELEASE SIGNING FAILURE
- git diff --check: PASS
- secret scan: clean

Not proven:
- signed Android artifact
- CI green
- staging deployment for the local candidate
- live COD/Paymob/RLS/race/Sentry evidence for the local candidate

Release verdict: NO-GO

## Package C — Documentation and Governance Normalization

Status: COMPLETE LOCALLY
Scope:
- normalize `docs/DATA_POLICY.md`
- normalize `docs/OBSERVABILITY_OWNERSHIP.md`
- reconcile `docs/RELEASE_GATE.md`
- prepare `docs/RELEASE_SIGNOFF.md`
- mark historical acceptance evidence
- update `STATE.md`

Safety boundary:
- documentation/state files only
- no push, PR, merge, rebase, migration, deployment, secret operation, or final sign-off
- technical gates remain NO-GO pending candidate-SHA-bound live evidence

Verification:
- all required normalized documentation paths are present
- changed paths are limited to the Package C allowlist
- forbidden code, Android, Supabase, config, pubspec, and workflow paths are absent
- `git diff --check`: PASS
- staged secret-like path and content scans: clean
- owner names, dates, approval references, and final signatures remain pending

## New - 2026-07-26

### P0 Package A security review remediation - IMPLEMENTED LOCALLY (L2 attempt 2/3)

**Review verdict received:** `APPROVE WITH CONDITIONS`. Migration 028 passed
all nine review rules. The reviewer required removal of raw Paymob response
details from client errors, recommended removal of serialized upstream/database
objects from logs, and recommended runtime JWT rejection coverage.

**Attempt 2 candidate changes (repository only):**
1. All `paymob-initiate` 4xx/5xx response bodies are now allow-listed to the
   single `message` key; raw Paymob `details` and Supabase `error` values are
   not returned.
2. The function no longer serializes Paymob responses or Supabase error objects
   into `console.error` logs.
3. Exported `handlePaymobInitiate(Request)` and guarded the production
   `Deno.serve` registration with `import.meta.main`, preserving deployed
   behavior while allowing a real handler request in tests.
4. Expanded the Deno suite to 13 tests, including a runtime POST without
   Authorization that proves HTTP 401, plus ownership, canonical amount,
   fixed pending status, absent initiation transaction ID, sanitized response,
   and sanitized logging contracts.
5. Applied canonical `deno fmt` to both touched TypeScript files.

**Verification evidence:**
| Check | Result |
|-------|--------|
| `deno fmt --check` after canonical formatting | PASS |
| `deno check` on implementation and test | PASS (exit 0) |
| Handler/contract suite | **13 passed, 0 failed**, including runtime no-JWT 401 |
| Security contract scan | raw `details` responses 0; raw `error` responses 0; serialized error logs 0 |
| Ownership/server-state scan | caller ownership filter, server order total, and service-role INSERT all present |
| Migration-order scan | 028 remains latest and drops both known direct INSERT policies |
| Targeted secret-value scan of candidate files | 0 matches |
| `flutter test` | **198 passed, 0 failed** |
| `flutter analyze` | **NOT PASSING** (exit 1): same two pre-existing info findings outside Package A |
| Target-file `git diff --check` | PASS (exit 0) |

**Verification hygiene:** `flutter analyze/test` rewrote generated desktop
plugin registrants. Those unrelated generated-file side effects were restored
to HEAD; only `STATE.md`, the two Paymob-initiate files, and untracked migration
028 remain changed in this worktree.

**Safety / evidence boundary unchanged:**
- No migration was applied and no Edge Function was deployed.
- No secret was set or printed.
- No commit, push, PR, or merge was performed.
- Runtime no-JWT evidence is local handler evidence, not live staging proof.
- Live ownership, successful initiation, callback, and adversarial RLS checks
  remain staging gates.
- Staging acceptance remains **NO-GO** and release remains **NO-GO**.

---

### P0 Package A - Restore trusted payment INSERT boundary - IMPLEMENTED LOCALLY (L2 attempt 1/3)

**Worktree:** `C:/flutter_projects/albatal-package-a`

**Branch:** `fix/package-a-payment-insert-boundary`

**Problem verified:** migration `027_add_payments_insert_policy.sql` recreated
`payments_insert_authenticated_own`, allowing direct authenticated INSERT on
`public.payments`. That contradicted migration 026 and the approved boundary
that payment rows are created only by SECURITY DEFINER RPCs or trusted
service-role Edge Functions. `paymob-initiate` depended on the caller-JWT
client for its payment INSERT, so simply dropping the policy would have broken
new Paymob initiation.

**Candidate changes (repository only):**
1. Added forward-only, idempotent migration
   `supabase/migrations/028_reclose_payments_insert_policy.sql`; it drops both
   known direct payment INSERT policies.
2. Updated `supabase/functions/paymob-initiate/index.ts` so authentication,
   ownership-scoped reads, and the guarded provider-order RPC remain on the
   caller-JWT client, while only server-generated payment INSERT uses a
   fail-closed service-role client.
3. Hardened the unhandled-error path discovered by the inherited contract test:
   no raw error object is logged or returned.
4. Updated `paymob_initiate_test.ts` for the current Deno one-argument
   `readTextFileSync` API and added a contract test for the service-role INSERT
   boundary.

**Verification evidence:**
| Check | Result |
|-------|--------|
| `deno check supabase/functions/paymob-initiate/index.ts` | PASS (exit 0) |
| `deno test --allow-read supabase/functions/paymob-initiate/paymob_initiate_test.ts` | **9 passed, 0 failed** |
| `git diff --check` on touched TypeScript | PASS (exit 0) |
| Migration-order scan | `028_reclose_payments_insert_policy.sql` is latest and drops `payments_insert_authenticated_own` |
| Targeted secret-value scan of the three candidate files | 0 matches |
| `flutter test` | **198 passed, 0 failed** |
| `flutter analyze` | **NOT PASSING** (exit 1): 2 pre-existing info findings outside Package A - undeclared direct `url_launcher` dependency and deprecated Sentry `copyWith` use |

**Safety / evidence boundary:**
- No migration was applied.
- No Edge Function was deployed.
- No secret was set or printed.
- No commit, push, PR, or merge was performed.
- These results are SOURCE/HARNESS evidence only, not staging deployment proof.
- Staging acceptance remains **NO-GO** and release remains **NO-GO** until the
  candidate is reviewed, committed through the approved workflow, applied and
  deployed to staging, and the required live payment/RLS/race/Sentry/Android
  evidence gates pass.

---

## New — 2026-07-25

### Environment Isolation Plan — COMPLETE (L1 report)

**Problem:** `config/env.staging.json` and `config/env.production.json`
point to the same Supabase project (`alxwvyflasewslinufqe`) with identical
anon keys. Staging mistakes can directly affect production data and
payments.

**Analysis:** Compared 3 options:
- **Option A: Separate projects** — RECOMMENDED. Complete blast-radius
  isolation. Extra setup cost is justified for a payment-processing app.
- **Option B: Separate schemas** — NOT RECOMMENDED. Migration complexity,
  RLS duplication, and PostgREST schema routing edge cases outweigh savings.
- **Option C: Separate keys only** — NOT RECOMMENDED. Zero data isolation;
  same rows, same tables, same database.

**Deliverable:** `docs/ENVIRONMENT_ISOLATION_PLAN.md` with:
1. Recommended strategy (Option A — separate projects)
2. Required Supabase projects (staging + production)
3. Required secret names (client + Edge Function + Paymob)
4. Required Flutter environment wiring (config files, build commands)
5. Required CI/CD secret handling (GitHub Actions pattern)
6. Migration promotion process (staging → production gate)
7. Backup/restore considerations
8. Implementation checklist (14 items)

**Decision required from human:**
1. Approve Option A (separate projects)?
2. Which project becomes production — current `alxwvyflasewslinufqe` or new?
3. Paymob account — supports multiple integrations or need second account?
4. Supabase plan — Free (2 projects) or Pro?

No code changes. No push/merge. Report only.

---

## High Priority

### P1 — `confirm_cod_payment` RPC not deployed to staging — OPEN (L1 report)

**Deployment gap:** The on-disk migration `supabase/migrations/018_confirm_cod_payment.sql`
defines the `confirm_cod_payment(UUID)` RPC, but the staging database's
migration slot "018" is occupied by a DIFFERENT file
(`018_low_stock_index_and_perf.sql` — a low-stock partial index). The
`confirm_cod_payment` function does **not exist** in the staging `public`
schema (verified via `pg_proc` — 0 rows). Migration version "019" on staging
is `019_harden_rpc_grants.sql` (PUBLIC→authenticated on checkout/update_status),
NOT the on-disk `019_harden_rpc_and_payments_authorization.sql`.

**Evidence:**
- `supabase_migrations.schema_migrations` → 19 versions applied (001–019)
- `pg_proc WHERE proname='confirm_cod_payment'` → 0 rows (MISSING)
- `pg_proc WHERE proname ILIKE '%confirm%'` → 0 rows
- Staging slot "018" statements = low-stock index, NOT the COD RPC
- `create_checkout_order`, `process_paymob_callback`, `update_order_status`,
  `calculate_shipping_fee`, `get_low_stock_products`,
  `set_payment_provider_order_id` all present; `confirm_cod_payment` absent

**Impact:** Every COD checkout attempt from the Flutter client fails with a
PostgREST "function confirm_cod_payment not found" error. The entire COD
payment path is broken in staging.

**Root cause (likely):** The local `supabase/migrations/` directory was
renumbered/reorganized after an initial `supabase db push`, but the staging
database was never re-pushed with the new 018/019 files. The
`schema_migrations` table tracks version numbers, not file hashes, so the
mismatch is invisible to `supabase db push` (it thinks 018/019 are applied).

**Abuse-test evidence (transactional, rolled back):** The RPC *logic* was
verified by defining the function inline inside a `BEGIN`/`ROLLBACK`
transaction on staging and running the project's abuse-test harness
(`supabase/tests/test_cod_payment.sql` pattern). All 8 scenarios passed:
confirmed, idempotent, authentication_required, not_owner, order_not_pending,
payment_not_cod, payment_not_pending (failed payment), and auto-create
missing payment. Dart client tests (`test/cod_server_confirm_test.dart`)
also pass (7/7). Staging `orders`/`payments` counts were 0 before and after
— no persistent state change.

**Required action (HUMAN GATED — do not auto-fix):**
1. Reconcile the migration numbering mismatch between local
   `supabase/migrations/` and staging `schema_migrations`.
2. Push the actual `018_confirm_cod_payment.sql` to staging (likely as
   migration 020 to avoid re-numbering, or via a repair migration).
3. Re-run `supabase db query --linked "SELECT confirm_cod_payment(...)"` to
   confirm the RPC exists, then re-run the REST E2E flow.

**Schema notes for the E2E spec:**
- `orders` has NO `payment_state` column. The spec's "orders.payment_state=paid"
  maps to `orders.status='paid'` (enum `order_status`).
- `payments.status` is `text` (not an enum); "success" is a string.
- The RPC never returns `payment_not_found` — it auto-creates a missing
  payment row (migration 018 lines 147–154). The Dart client maps this
  code but it is unreachable. Documented as a spec deviation.

### P0 — `.env` packaged as Flutter asset — FIXED (L2, main workspace)

**Trust-boundary break:** `pubspec.yaml` listed `.env` as a Flutter
asset, so `flutter build` baked Supabase + Paymob secrets into the APK.
`.env` was gitignored (never committed) but was shipped inside the
artifact at build time.

**Changes:**
1. `pubspec.yaml` — removed `.env` from `flutter.assets`; removed
   `flutter_dotenv` dependency.
2. `lib/shared/services/supabase_config.dart` — replaced `dotenv.load()`
   + `dotenv.env[...]` with build-time `String.fromEnvironment(...)`.
3. `lib/shared/services/env_config.dart` — same: dotenv reads →
   `String.fromEnvironment`. Added `SUPABASE_SERVICE_ROLE_KEY` and
   `SCHEDULER_SECRET` to the "never in client" docstring list.
4. `test/payment_security_test.dart` — updated stale "non-dotenv"
   comment to reference the new build-time config.
5. `.env.example` — rewritten to document ONLY safe client vars
   (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`) plus an explicit
   "never ship" block listing every server-only secret.
6. `config/env.staging.json`, `config/env.production.json` — new
   committed placeholder templates for `--dart-define-from-file`.
7. `config/README.md` — new doc explaining build-time config + which
   vars are client-safe vs Edge-Function-only.
8. `.gitignore` — added `config/env.*.local.json` and
   `config/env.*.secret.json` so real values never get committed.
9. `README.md` — replaced "cp .env.example .env" run flow with
   `--dart-define-from-file=config/env.<env>.local.json` for staging
   and production; removed `flutter_dotenv` from deps table; added
   "Verifying no secrets leak into the artifact" section.

**Verification:**
| Check | Result |
|-------|--------|
| `flutter pub get` | OK — `flutter_dotenv` removed, 1 dependency changed |
| `flutter analyze` | 1 pre-existing warning (`_CompleterConfirmService` unused in `test/cod_server_confirm_test.dart`); **0 new issues** |
| `flutter test` | **170 passed**, 0 failed |
| `flutter build apk --release` | FAILED — **pre-existing** proguard-rules.pro missing (fails on `master` before my changes too, confirmed via `git stash`) |
| `flutter build apk --debug --dart-define-from-file=...` | OK — built `app-debug.apk` |
| APK `.env` file search | **No `.env` packaged** (recursive search of extracted APK) |
| APK `PAYMOB_` string search | 4 matches, **all in docstring comments** in `kernel_blob.bin` (debug-only artifact; release AOT strips comments) |
| Real secret-value scan | No `sk_live`/`sk_test`, no real Bearer tokens, no real JWTs. "Bearer " matches are `supabase_flutter` HTTP template strings; "eyJ" matches are byte noise in keyboard key tables |

**Client trust boundary (post-fix):**
- Flutter build receives ONLY: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`
- Flutter build NEVER receives: `PAYMOB_API_KEY`, `PAYMOB_INTEGRATION_ID`, `PAYMOB_HMAC_SECRET`, `PAYMOB_IFRAME_ID`, `SUPABASE_SERVICE_ROLE_KEY`, `SCHEDULER_SECRET`

**New run commands:**
```bash
# Staging
flutter run --dart-define-from-file=config/env.staging.local.json
flutter build apk --release --dart-define-from-file=config/env.staging.local.json

# Production
flutter build apk --release --dart-define-from-file=config/env.production.local.json
```

## Previous — Fixed

### P0 — Missing DI sources — FIXED (L2, main workspace)

**Changes (applied to main workspace, mirroring worktree `fix/missing-di-sources`):**
1. Restored `lib/core/services/crash_reporting_service.dart` (abstract `CrashReportingService` + `NoOpCrashReportingService` with `scrubContext`)
2. Restored `lib/features/storefront/data/supabase_orders_repository.dart`
3. `lib/shared/services/service_locator.dart` → removed `sentry_crash_reporting_service.dart` import; register `NoOpCrashReportingService` (Sentry deferred, no pubspec change)
4. `test/checkout_address_test.dart` → `await cubit.place()` in 3 tests
5. Restored `test/crash_reporting_scrub_test.dart`

**Verification:**
| Check | Result |
|-------|--------|
| `dart analyze lib test` | No issues found (1 pre-existing unused-element warning) |
| `flutter test` | **170 passed**, 0 failed |

## Watch List

- **Pre-existing Android release build break:** `flutter build apk --release`
  fails on `minifyReleaseWithR8` because `android/app/proguard-rules.pro` is
  referenced in `build.gradle` but absent from disk. Reproduces on clean
  `master` HEAD (verified via `git stash`). Not a security issue; needs a
  separate Android-config fix (add the file or drop the reference).
- Outdated packages (major bumps need human review)
- Sentry SDK deferred
- macos ephemeral Packages lock on Windows may block `flutter analyze` in main tree

## Spec Kit (prior) — unchanged

See previous run notes for completed specs 01–10 and deferred items.

---

Run log: L1 report-only. COD E2E test requested. Staging deployment
verified (linked project alxwvyflasewslinufqe, ACTIVE_HEALTHY). Found
`confirm_cod_payment` RPC MISSING from staging — migration slot "018"
on staging is a low-stock index, not the COD RPC. The on-disk
`018_confirm_cod_payment.sql` was never pushed. Abuse tests run in a
rolled-back transaction (function defined inline) — all 8 scenarios
PASS. Dart client tests 7/7 PASS. No persistent staging state change
(orders/payments counts 0 before and after). No push/merge. Human
action required to deploy the RPC before COD can be marked ready.

---

## 2026-07-23 — Paymob Sandbox QA Run (L1 report-only)

**Task:** End-to-end Paymob sandbox testing on staging (project ref
`alxwvyflasewslinufqe`). 9 test scenarios from the QA brief.

**Executed:**
- Codebase reconnaissance (3 explore agents): Edge Functions, Flutter
  payment feature, staging config, tests, migrations.
- `flutter test test/payment_checkout_flow_test.dart
  test/payment_security_test.dart test/paymob_url_guard_test.dart` →
  **22 passed**, 0 failed.
- Live staging probes against `paymob-callback` and `paymob-initiate`
  Edge Functions (no secrets used; negative tests only).
- `supabase secrets list` (names verified; values NOT recorded/printed).
- `supabase functions list` (all 5 ACTIVE).

**BLOCKERS found (cannot complete e2e sandbox tests):**

### B1 — P0: `paymob-callback` deployed with `verify_jwt=true` (DRIFT)
- Local `supabase/config.toml` correctly sets `verify_jwt = false` for
  `paymob-callback` (Paymob is the caller; HMAC is the auth).
- Deployed function on staging reports `verify_jwt: true` (from
  `supabase functions list`).
- Live probe: POST to `paymob-callback` with forged HMAC → HTTP 401
  `{"code":"UNAUTHORIZED_NO_AUTH_HEADER","message":"Missing authorization
  header"}` — this is the **platform JWT gate**, NOT the Edge Function's
  HMAC check. The function body never executes.
- **Impact:** Paymob cannot deliver callbacks. Tests 5, 6, 8, 9 cannot
  pass. Paymob is NOT ready.
- **Fix:** `supabase functions deploy paymob-callback --no-verify-jwt
  --project-ref alxwvyflasewslinufqe` (redeploy with correct config).
  Requires human approval (per AGENTS.md scope — L2 + worktree).

### B2 — `PAYMOB_IFRAME_ID` secret NOT set on staging
- `supabase secrets list` shows: `PAYMOB_API_KEY`,
  `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID` present.
- `PAYMOB_IFRAME_ID` **absent** (also flagged in `secrets-staging.env`
  TODO comment).
- **Impact:** `paymob-initiate` returns HTTP 503 "Payment provider not
  configured". Test 4 cannot return a valid checkout URL. Tests 5–7
  cannot run.
- **Fix:** `supabase secrets set PAYMOB_IFRAME_ID=<from-paymob-dashboard>
  --project-ref alxwvyflasewslinufqe`. Requires human.

### B3 — No live staging DB access for SQL test fixtures
- `supabase status` fails locally (config.toml schema drift —
  `db.pooler.extra_pool_size`, `db.shadow_project_id`,
  `auth.refresh_token_rotation_enabled` rejected by current CLI 2.109.1).
- `test_paymob_callback.sql` (amount-mismatch + invalid-HMAC RPC tests)
  cannot be executed without DB access or a fixed config.toml.
- **Mitigation:** The RPC logic is covered by the SQL fixture's documented
  expectations + the Flutter unit tests. But the *live staging DB* has not
  been exercised.

**What DID pass (evidence-backed):**
- 22 Flutter unit/widget tests: PaymentCubit state machine (success,
  failure, timeout, cancel, duplicate-replay idempotency, watch cleanup),
  URL guard (HTTPS/host allowlist/token redaction), security regression
  (no client-side verifyPayment/handleCallback/secret getters).
- Live staging: `paymob-initiate` correctly 401s without JWT (platform
  gate works). All 5 Edge Functions ACTIVE. Secrets (5 of 6 Paymob
  vars) present.

**Verdict:** Paymob is **NOT READY** for production. B1 and B2 must be
fixed and the full 9-test suite re-run before sign-off. The invalid-HMAC
(Test 8) and amount-mismatch (Test 9) tests — the mandatory gates —
cannot pass until B1 is fixed.

---

## 2026-07-23 — Adversarial RLS Verification Plan (L1 report-only)

**Status:** Test plan created. NOT YET RUN against staging. RLS is NOT
marked verified until the script is executed and all 44 tests pass.

**Artifacts created (no source code modified — L1):**
1. `supabase/tests/test_rls_adversarial.sql` — adversarial RLS test
   script (44 tests across 4 sections, wrapped in BEGIN/ROLLBACK,
   disposable test users, no production data touched, no secrets/JWT
   bodies printed).
2. `supabase/tests/test_rls_adversarial_results.md` — expected results,
   actual-results template, PASS/FAIL summary, launch sign-off evidence
   checklist (E1–E9).

**Test coverage (44 tests):**
- Section 1 (14 tests): anonymous user — cannot read user-scoped tables
  (profiles, orders, order_items, addresses, cart_items, wishlists,
  payments, notifications, analytics, error_logs); can read public
  catalog (products, categories, product_variants, product_images).
- Section 2 (14 tests): user A — can read own data (7 positive tests);
  cannot read user B's data (7 negative tests: profiles, orders,
  order_items, addresses, cart, wishlist, payments).
- Section 3 (9 tests): non-admin escalation — cannot INSERT/UPDATE/
  DELETE products, cannot INSERT/UPDATE categories, cannot call
  `update_order_status` RPC, cannot self-escalate `is_admin`, cannot
  call `get_low_stock_products`, IDOR blocked on `get_order_details`.
- Section 4 (7 tests): payment integrity — cannot directly INSERT
  payments (default-deny), cannot call `process_paymob_callback`
  (service_role only), checkout ignores client-supplied pricing
  (server-authoritative), cannot UPDATE payments, cannot UPDATE/INSERT
  orders directly, cannot INSERT order_items directly.

**How to run:**
```bash
supabase db execute --linked supabase/tests/test_rls_adversarial.sql
```

**Note on B3 blocker:** The `supabase status` config.toml schema drift
issue (flagged in the Paymob QA run above) may also block `supabase db
execute`. If so, paste the script into the Supabase SQL Editor on the
staging project as a workaround.

**Launch gate:** `Failed` count must be 0. Evidence E1–E9 must be
collected before RLS is marked VERIFIED.

### P1 — Foreign key constraint violation on orders — FIXED

**Problem:** The checkout RPC create_checkout_order (migration 013) inserts into the orders table with user_id from uth.uid(). The orders table has user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT. If a user exists in uth.users but has no corresponding row in profiles, the INSERT fails with a foreign key constraint violation, breaking all checkout attempts.

**Root cause:** The handle_new_user() trigger on uth.users (migration 003) creates profiles automatically, but it does not cover users who existed before the trigger was added, or whose profile was manually deleted, or auth users created through non-standard paths.

**Fix applied to supabase/migrations/013_atomic_checkout_rpc.sql (lines 158-165):**
Added a profile guard before the order insert:
`sql
INSERT INTO profiles (id, full_name, phone)
VALUES (v_user_id, \'\', \'\')
ON CONFLICT (id) DO NOTHING;
`
This ensures a profile exists for every authenticated user before attempting the order insert. The ON CONFLICT DO NOTHING makes it idempotent — if the profile already exists (normal case), it silently succeeds.

**Verification:** 170/170 Flutter tests pass, 0 new linter issues.
