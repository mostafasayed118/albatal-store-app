# Loop State — Al Batal Elite

Last run: 2026-08-23T16:15:00Z

## New — 2026-08-23 (later)

### PR #8 conflict reconciliation + Stitch emulator smoke (L1 evidence run)

**Why:** PR #8 (`fix/l2-remediation-package` → `master`) reported CONFLICTING.
`origin/master` carried PR #3 (fix/di-sources) whose changes the branch had
mirrored independently and then evolved past — duplicate history, two real
conflicts.

**Resolution (merge commit `716a9e5`):**
- Kept `CrashReportingService` at `shared/services/`; deleted master's
  byte-identical `core/services/` copy (diff was CRLF-only). All live
  callsites (`main.dart`, `sentry_crash_reporting_service.dart`, tests)
  import the shared path.
- Kept branch's DSN-conditional Sentry/NoOp DI registration — supersedes
  master's stale "NoOp until sentry_flutter is approved" state
  (`sentry_flutter ^9.0.0` is in pubspec).
- Verified all 5 PR #3 files accounted for: orders repository identical to
  master; checkout test intentionally uses the newer
  `memory_storefront_persistence` helper; scrub test identical except import
  path matching kept location.

**Verification this run:**
| Check | Result |
|-------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **243 passed, 0 failed** |
| Working tree | clean (generated registrant side effects restored) |

**Stitch reskin visual smoke (Android emulator, staging env):** Home screen
(hero banner, category chips, flash-sale countdown, populated grid from
staging) and Categories screen verified rendering in the emerald/gold Stitch
palette. Evidence: `docs/evidence/stitch-smoke-2026-08-23/{home,categories}.png`.

**Branch:** merge pushed; PR #8 conflict status clears on CI re-run.
**Merge into `master` remains human-gated per AGENTS.md.**

---

## New — 2026-08-23

### Record reconciliation + live staging re-verification (L1 evidence run)

**Why:** STATE.md and RELEASE_GATE.md were stale (last updated 2026-07-28,
still recording RLS adversarial as FAIL). Git history, tags, and evidence
folders showed substantial completed work. This run reconciled the record
against reality and re-verified live staging state. No source code changes.

**Reconciled — work completed since the 2026-07-28 entry but unrecorded:**
1. **RLS-ESC-001 FIXED** — migration 030 dropped the redundant
   `profiles_update_own` policy. Post-030 staging verification: adversarial
   suite **44/44 PASS** (was 41/44). Evidence:
   `docs/evidence/6c8521a/POST_030_STAGING_VERIFICATION.md` (candidate
   `6c8521a`, tag `release-candidate/6c8521a`, approval
   `PACKAGE-L3-APPLY-030-6C8521A`).
2. **Stitch UI reskin COMPLETE** — all phases committed (`1bf7db3` tokens →
   `7802a53` checkout "phase 5 FINAL") per
   `docs/superpowers/plans/2026-08-22-stitch-implementation-plan.md`; plan
   checkboxes now ticked with a completion banner.
3. **Android release APK proof** — evidence at
   `docs/evidence/eebcc4d/RELEASE_APK_PROOF.md` (78MB, v2 signed, no `.env`,
   243 tests). Commit `2506cbd`.

**Local verification this run (2026-08-23):**
| Check | Result |
|-------|--------|
| `flutter test` | **243 passed, 0 failed** |
| `flutter analyze` | **No issues found** (pre-existing url_launcher/Sentry infos were fixed by audit batch `2af4c84`) |
| Working tree | clean (generated registrant side effects restored to HEAD) |

**Live staging re-verification this run (read-only / negative probes only):**
| Check | Result |
|-------|--------|
| Migration parity (`supabase migration list --linked`) | local/remote in sync through **030** |
| Edge Functions | all 5 ACTIVE, redeployed 2026-08-23 00:43 UTC |
| `paymob-callback` JWT-gate drift (July B1) | **RESOLVED** — forged-HMAC probe now returns `{"message":"Invalid signature"}` (function HMAC layer), not the platform `UNAUTHORIZED_NO_AUTH_HEADER` gate; `verify_jwt=false` is live |
| `PAYMOB_IFRAME_ID` secret (July B2) | **RESOLVED** — now present in staging secrets (names-only check) |

**Release gate impact:** RLS adversarial row and Android artifact evidence
links updated in `docs/RELEASE_GATE.md`. Overall verdict remains **NO-GO**
pending COD E2E, Paymob sandbox E2E, race-condition, Sentry, and four-party
sign-off evidence, plus owner designation of a post-merge candidate SHA.

**Open — owner decisions required (environment isolation,
`docs/ENVIRONMENT_ISOLATION_PLAN.md`):** no second Supabase project exists
yet (verified via `supabase projects list`; only `alxwvyflasewslinufqe` is
linked). Pending: (1) approve Option A separate projects, (2) which project
becomes production, (3) Paymob second integration, (4) Supabase plan tier.

**Branch:** `fix/l2-remediation-package` — 40+ commits ahead of `master`,
pushed to origin; PR to `master` created this run (see git). Merge remains
human-gated per AGENTS.md.

---

## New — 2026-07-28

### Package K3 — Migration 029 applied to staging; RLS adversarial FAIL (L2, authorized)

**Authorization:** `PACKAGE-K3-APPLY-029-B74D326` (owner: Mustaf Sayed Saeed).
Staging candidate designated `b74d32653462d555213ac171b12f0f4b7cded7ad`
(tag `release-candidate/b74d326`), superseding `fee90bb2`. Applied migration 029
from a clean worktree at the frozen tag via `supabase db push` (dry-run confirmed
only 029 pending). Evidence: `docs/evidence/b74d326/STAGING_SNAPSHOT_POST_K.md`.

**DB catalog: PASS** — ledger high-water 029; payments INSERT policies absent;
anon/public write grants 30→0; all 9 RPC grants match target matrix; RLS enabled
on all 10 tables. `test_029_security_grant_repairs.sql` PASS.

**RLS adversarial: FAIL (3/44).** `test_rls_adversarial.sql` had never been run;
a runner copy (`scripts/run_rls_adversarial_dbquery.sql` via
`scripts/transform_rls_suite.ps1`) exposed 3 harness defects (reserved `desc`
param; service_role seeding of auth.users; narrow `check_violation` handlers) —
fixed in the runner copy only; committed suite unchanged. After fixes: 41 PASS,
3 FAIL.

**FINDING RLS-ESC-001 (confirmed, real): profiles admin self-escalation.**
`profiles` has two permissive UPDATE policies — `profiles_update_own` (from 002,
WITH CHECK null) and `profiles_update_own_safe` (WITH CHECK guarding is_admin).
Permissive policies OR together and a null WITH CHECK falls back to USING, so
setting `is_admin=true` still passes `profiles_update_own`'s check
(`auth.uid()=id`). The redundant policy defeats the escalation guard. Tests
3.8/3.9 cascade from 3.7 in the shared transaction (once admin, admin-only
functions stop raising). Migration 003 added the safe policy but never dropped
the old one; no migration through 029 drops it. Independent of 029's grant scope.

**Recommended remediation (owner authorization required — NOT applied):** a new
migration dropping the redundant `profiles_update_own`, then re-run the
adversarial suite (expect 3.7/3.8/3.9 to pass).

**E2E NOT authorized** — post-K is not ALL-PASS, so `STAGING-E2E-B74D326-2026-07-28`
is **not recorded**. No secret changes, no Edge Function deploy, no source/
migration commits. Release verdict remains **NO-GO**.

---

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


