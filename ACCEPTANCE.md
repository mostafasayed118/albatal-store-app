# ACCEPTANCE.md — Al Batal Elite Launch Sign-off

> **Project:** Al Batal Elite
> **Document:** Final launch acceptance checklist
> **Date:** 2026-07-25
> **Rule:** No item is marked complete unless evidence exists in the repository.

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | **PASS** — evidence verified in repo |
| ⚠️ | **UNVERIFIED** — mechanism exists but no run/deployment evidence |
| ❌ | **FAIL / NOT DONE** — missing or broken |
| N/A | Not applicable |

---

## 1. Git and CI

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1.1 | master clean | ❌ | `git status` shows 11 modified + 6 untracked files (config.toml, migrations 019-021, scripts/, tests/, gitleaks.toml). Working tree must be committed before release. |
| 1.2 | CI runs on master | ✅ | `.github/workflows/ci.yml` triggers on `push` and `pull_request` to `master`. |
| 1.3 | CI green | ⚠️ | CI config is complete (analyze, test, deno-test, secret-scan, deploy-check, android-release jobs). No run evidence available from this environment — verify on GitHub Actions. |
| 1.4 | secret scan passes | ✅ | `secret-scan` job runs gitleaks (full history) + custom high-risk patterns (PAYMOB_, SERVICE_ROLE, JWT, keystore blobs). Config: `.github/gitleaks.toml`. |
| 1.5 | no tracked secrets | ✅ | `git ls-files` returns no `.env`, no keystore/`.jks`, no `key.properties`, no `google-services.json`. `.gitignore` covers `.env`, `*.keystore`, `*.jks`, `key.properties`. |
| 1.6 | no tracked keystore | ✅ | Confirmed via `git ls-files` — zero matches for `*.keystore` / `*.jks`. CI decodes `KEYSTORE_BASE64` from GitHub Secrets at build time. |

**Section verdict: BLOCKED** — master is dirty (1.1). Commit pending changes before sign-off.

---

## 2. Supabase Staging

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 2.1 | config.toml committed | ❌ | `supabase/config.toml` exists but is **untracked** (`?? supabase/config.toml` in git status). Must be committed. File is safe: no secrets, project_id is a public identifier. |
| 2.2 | migrations applied | ⚠️ | 21 migration files exist (`001_` … `021_`). No evidence they have been applied to the staging project (`alxwvyflasewslinufqe`). Run `supabase db push` and capture output. |
| 2.3 | test SQL not in migration path | ✅ | `test_*.sql` files were deleted from `supabase/migrations/` and relocated to `supabase/tests/`. Migration path contains only `0xx_*.sql` production migrations. |
| 2.4 | Edge Functions deployed | ⚠️ | 5 functions exist in repo (`checkout`, `paymob-initiate`, `paymob-callback`, `cancel-expired-orders`, `send-order-notification`). No deployment evidence. Run `supabase functions list` against staging. |
| 2.5 | staging secrets configured safely | ⚠️ | `.env.example` documents the secret boundary (PAYMOB_*, SERVICE_ROLE, SCHEDULER_SECRET must live in Edge Function env / Vault only). No evidence these were actually set via `supabase secrets set`. |
| 2.6 | Flutter connects to staging | ⚠️ | `config/env.staging.json` template exists; `env_config.dart` + `supabase_config.dart` wire `--dart-define-from-file`. No live connection test evidence against staging URL. |

**Section verdict: BLOCKED** — config.toml uncommitted (2.1); deployment + connection unverified (2.2, 2.4, 2.5, 2.6).

---

## 3. Security

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 3.1 | .env not packaged in APK | ✅ | `.env.example` states: "the Flutter app no longer reads a `.env` file at runtime and `.env` is NOT packaged as an asset." Build uses `--dart-define-from-file=config/env.<env>.json`. `.gitignore` excludes `.env`. |
| 3.2 | no Paymob secrets in client | ✅ | `.env.example` documents PAYMOB_API_KEY, PAYMOB_INTEGRATION_ID, PAYMOB_HMAC_SECRET, PAYMOB_IFRAME_ID as Edge-Function-only. CI `secret-scan` job rejects any `PAYMOB_` assignment with a 16+ char value in source. |
| 3.3 | no service_role in client | ✅ | CI `secret-scan` job explicitly rejects `SUPABASE_SERVICE_ROLE_KEY` assignments in client source files. `.env.example` marks it server-only. |
| 3.4 | RPC grants verified | ✅ | Migration `017_authorize_rpcs.sql` + `019_harden_rpc_and_payments_authorization.sql` harden RPC grants. Test file `supabase/tests/test_019_rpc_payments_hardening.sql` + `test_rpc_authorization.sql` exist. |
| 3.5 | payments client INSERT removed | ✅ | Checkout is atomic server-side RPC (`013_atomic_checkout_rpc.sql`). `015_payments_update_and_stock_hardening.sql` + `019` removed direct client INSERT to payments. Client goes through `checkout` Edge Function → RPC. |
| 3.6 | RLS negative tests pass | ⚠️ | `supabase/tests/test_rls_adversarial.sql` + `test_rls_adversarial_results.md` exist. Results file present but must be re-run against current staging schema to confirm green. |
| 3.7 | CORS allowlist configured | ⚠️ | `supabase/functions/_shared/cors.ts` reads `CORS_ALLOWED_ORIGINS` env var — but **defaults to `*`**. The allowlist mechanism exists; the env var MUST be set in staging to a strict origin list. Verify via `supabase secrets list`. |

**Section verdict: BLOCKED** — RLS negative tests need re-run (3.6); CORS default `*` must be overridden in staging (3.7).

---

## 4. Payments

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 4.1 | Paymob sandbox success | ⚠️ | No evidence of a live Paymob sandbox success transaction against staging. `paymob-initiate` + `paymob-callback` functions exist; must run end-to-end against Paymob sandbox and capture txn id. |
| 4.2 | Paymob sandbox decline | ⚠️ | No evidence. Run a declined-card test transaction in sandbox. |
| 4.3 | Paymob cancel | ⚠️ | No evidence. Run a user-cancel flow on the Paymob iframe and confirm order returns to `pending` / is cancelled. |
| 4.4 | invalid HMAC rejected | ✅ | `hmac_test.ts` tests `verifyHmac` rejects invalid signature (line 97). `paymob-callback/index.ts:100-107` returns HTTP 401 on HMAC failure. |
| 4.5 | amount mismatch rejected | ✅ | `paymob-callback/index.ts:145-151` delegates to `process_paymob_callback` RPC with `p_amount_cents`. RPC returns `amount_mismatch` code → HTTP 400 (line 179). |
| 4.6 | COD confirm success | ✅ | `test/cod_server_confirm_test.dart` line 107: "COD server-confirmed path" — stubs `confirmCodPayment` returning success, asserts `PaymentStatus.success` + server-issued txn id. |
| 4.7 | COD idempotency | ✅ | `test/cod_server_confirm_test.dart` line 190: "COD duplicate confirmation is idempotent via server" — second confirm returns `already_confirmed`, no duplicate success. |
| 4.8 | COD abuse cases rejected | ✅ | `test/cod_server_confirm_test.dart` line 138: "emits failed with server error on COD rejection" — server returns `order_not_pending` → `PaymentStatus.failed`. `test/payment_security_test.dart` line 98 confirms COD calls `confirmCodPayment`, not client-only success. |

**Section verdict: BLOCKED** — live Paymob sandbox flows unverified (4.1, 4.2, 4.3). Unit/integration tests for HMAC, amount mismatch, COD all green.

---

## 5. Orders

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 5.1 | release build uses SupabaseOrdersRepository | ✅ | `lib/shared/services/service_locator.dart:65-67`: `kDebugMode ? LocalOrdersRepository(...) : SupabaseOrdersRepository()`. Release builds (kDebugMode=false) use the Supabase-backed repository. |
| 5.2 | orders page renders staging order | ⚠️ | `SupabaseOrdersRepository` exists (`lib/features/storefront/data/supabase_orders_repository.dart`). `orders_cubit_test.dart` tests against a mock/local repo only. No integration test fetching a real staging order. Run app in release mode against staging and verify. |
| 5.3 | address snapshot renders correctly | ✅ | `test/checkout_address_test.dart` line 97: "place() stores the selected address on the order" — asserts recipient, line, city, country, id preserved. `test/checkout_cubit_test.dart:302` "address snapshot includes all required fields". |
| 5.4 | empty state works | ✅ | `test/orders_cubit_test.dart` asserts `state.completed` and `state.active` are empty initially. `test/checkout_page_test.dart:88` "checkout page shows empty address state" — finds `'No addresses saved yet'`. |

**Section verdict: BLOCKED** — staging order rendering unverified (5.2).

---

## 6. Android Release

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 6.1 | release APK signed | ⚠️ | `android/app/build.gradle.kts` defines a `release` signing config reading from `key.properties`. CI `android-release` job decodes `KEYSTORE_BASE64` from GitHub Secrets. No local `key.properties` present and no build artifact evidence. Run `flutter build apk --release` with signing secrets and verify. |
| 6.2 | not debug-signed | ⚠️ | CI job includes a "Verify APK is not debug-signed" step checking `debuggable=true`. Build.gradle falls back to debug signing **only** if `key.properties` is absent (local dev). No run evidence. |
| 6.3 | package name com.albatal.elite | ✅ | `android/app/build.gradle.kts`: `applicationId = "com.albatal.elite"`, `namespace = "com.albatal.elite"`. CI job rejects `com.example.*` packages. |
| 6.4 | debuggable=false | ✅ | `android/app/src/main/AndroidManifest.xml` does **not** set `android:debuggable`. Flutter release builds default `debuggable=false`. `isMinifyEnabled = true`, `isShrinkResources = true` enabled in release build type. |
| 6.5 | uploaded to Play internal testing | ❌ | No evidence of Play Console upload. Requires a signed release APK (6.1) and manual/CI upload to Play Console internal testing track. |

**Section verdict: BLOCKED** — no signed artifact evidence (6.1, 6.2); Play upload not done (6.5).

---

## 7. Observability

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 7.1 | crash reporting active | ❌ | `lib/core/services/crash_reporting_service.dart` ships only `NoOpCrashReportingService`. `service_locator.dart:70-72` registers the NoOp. `pubspec.yaml` has **no** `sentry_flutter` / `firebase_crashlytics` dependency. Crash reporting is NOT active. |
| 7.2 | test crash appears in dashboard | ❌ | No crash reporter is configured — no dashboard exists. Blocked by 7.1. |
| 7.3 | PII scrubbing passes | ✅ | `test/crash_reporting_scrub_test.dart` verifies `scrubContext` redacts `token`, `secret`, `card`, `cvv`, `authorization`, `address`, `email`, `phone`, `password` → `[REDACTED]`. Non-sensitive keys preserved. Scrubbing logic is ready; it just has no downstream reporter to feed. |

**Section verdict: BLOCKED** — crash reporting not wired (7.1, 7.2). PII scrubbing logic is correct (7.3) but inert until a provider is added.

---

## 8. Data Policy

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 8.1 | DATA_POLICY.md committed | ❌ | Glob for `**/DATA_POLICY.md` returns no files. Document does not exist in the repository. |
| 8.2 | cart/wishlist/addresses decision documented | ❌ | Without DATA_POLICY.md, the local-vs-server storage decision for cart, wishlist, and addresses is not documented. Code shows cart/wishlist use `LocalStorefrontPersistence` (SharedPreferences) and addresses use `LocalAddressRepository` — but this is undocumented. |

**Section verdict: BLOCKED** — DATA_POLICY.md must be authored and committed.

---

## 9. Sign-off

| Role | Name | Decision | Date |
|------|------|----------|------|
| Product | | ⛔ **HOLD** — pending DATA_POLICY.md (§8), staging order render (§5.2), Play upload (§6.5) | |
| Engineering | | ⛔ **HOLD** — master dirty (§1.1), config.toml uncommitted (§2.1), crash reporter missing (§7.1) | |
| QA | | ⛔ **HOLD** — Paymob sandbox flows unverified (§4.1-4.3), RLS negative tests need re-run (§3.6) | |
| Security | | ⛔ **HOLD** — CORS default `*` must be locked (§3.7), staging secrets unverified (§2.5) | |

---

## Release Readiness Summary

| Section | Items Pass | Items Blocked | Verdict |
|---------|-----------|--------------|---------|
| 1. Git and CI | 4/6 | 2 | BLOCKED |
| 2. Supabase Staging | 2/6 | 4 | BLOCKED |
| 3. Security | 5/7 | 2 | BLOCKED |
| 4. Payments | 5/8 | 3 | BLOCKED |
| 5. Orders | 3/4 | 1 | BLOCKED |
| 6. Android Release | 2/5 | 3 | BLOCKED |
| 7. Observability | 1/3 | 2 | BLOCKED |
| 8. Data Policy | 0/2 | 2 | BLOCKED |
| **Total** | **22/41** | **19** | **🚫 NOT READY FOR LAUNCH** |

## Critical Path to Launch (ordered)

1. **Commit working tree** — stage config.toml, migrations 019-021, scripts/, tests/, gitleaks.toml (§1.1, §2.1).
2. **Author DATA_POLICY.md** — document cart/wishlist/addresses local-storage decision (§8).
3. **Apply migrations + deploy functions to staging** — `supabase db push` + `supabase functions deploy` for all 5 functions; capture output (§2.2, §2.4).
4. **Set staging secrets** — `supabase secrets set PAYMOB_*=... SCHEDULER_SECRET=... CORS_ALLOWED_ORIGINS=https://staging.albatal.app` (§2.5, §3.7).
5. **Verify Flutter→staging connection** — build with `--dart-define-from-file=config/env.staging.json`, confirm orders page renders a seeded staging order (§2.6, §5.2).
6. **Run Paymob sandbox suite** — success, decline, cancel; capture txn ids (§4.1-4.3).
7. **Re-run RLS adversarial tests** against staging schema (§3.6).
8. **Add crash reporting** — approve + add `sentry_flutter` to pubspec, wire `SentryCrashReportingService`, run test crash (§7.1, §7.2).
9. **Build + sign release APK** — run CI `android-release` job with signing secrets, verify non-debug-signed artifact (§6.1, §6.2).
10. **Upload to Play internal testing** (§6.5).

> This document is a living checklist. Re-run each verification and flip status to ✅ only when fresh evidence is captured. No item may be marked complete on intent alone.
