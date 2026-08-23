# Staging Acceptance Test Plan — Al Batal Elite

> **Status:** DRAFT — supersedes `docs/acceptance-checklist.md` for staging
> sign-off. All existing functional cases from the prior checklist are
> retained (Sections 1–8) and re-issued with stable IDs. New security and
> production-readiness gates are added in Sections 9–13.
>
> **Launch rule:** Every **P0** and **P1** case MUST be `PASS` before
> production sign-off. `P2`/`P3` are required for GA but are not
> hard launch blockers (document exceptions in the sign-off section).

## Test Environment

- **Staging Supabase project**: `alxwvyflasewslinufqe` (URL from
  `config/env.staging.local.json`)
- **Production Supabase project**: separate project ref (must NOT equal
  staging ref — see TC-OPS-04)
- **Test devices**: Android (physical), iOS (physical/simulator)
- **Test accounts**: Customer (`test@test.com`), Admin (`admin@test.com`),
  Anonymous (no session)
- **Build artifact**: `build/app/outputs/flutter-apk/app-release.apk`
  built with `--dart-define-from-file=config/env.staging.local.json`

## Priority Legend

| Level | Meaning |
|-------|---------|
| **P0** | Blocker. Secrets leak, auth bypass, data exposure, or broken
            launch gate. Launch is forbidden while any P0 is `FAIL` or
            `UNVERIFIED`. |
| **P1** | Critical. Major functionality or security control broken.
            Sign-off requires explicit waiver with justification. |
| **P2** | High. Important functionality degraded. Fix before GA. |
| **P3** | Medium. Polish / edge cases. Track for fast-follow. |

## Evidence Requirements

Each row's **Evidence** column MUST record a concrete artifact before
`PASS` is granted. Acceptable forms:

- **Binary scan**: command + 0-match output (e.g. `unzip -l … | grep`)
- **SQL query**: exact query + row count / returned value
- **HTTP probe**: `curl` request + status code + redacted body
- **Config review**: file path + relevant line snippet
- **CI run**: workflow URL + green check
- **Signed report**: path to a generated report under `docs/evidence/`

A blank `Actual`/`Evidence` cell means `UNVERIFIED`, which counts as
`FAIL` for P0/P1.

---

## 1. Authentication

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-AUTH-01 | P2 | Sign up with valid email | Account created, verification email sent | | | |
| TC-AUTH-02 | P2 | Sign in with correct credentials | Session restored, redirected to home | | | |
| TC-AUTH-03 | P2 | Sign in with wrong password | Error message shown | | | |
| TC-AUTH-04 | P3 | Forgot password | Reset email sent | | | |
| TC-AUTH-05 | P3 | Reset password | New password works | | | |
| TC-AUTH-06 | P2 | Sign out | Session cleared, redirected to home | | | |
| TC-AUTH-07 | P2 | Relaunch app with active session | Session restored automatically | | | |
| TC-AUTH-08 | P3 | Arabic sign-in UI | RTL layout, Arabic strings | | | |

## 2. Product Discovery (Catalog)

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-CAT-01 | P2 | Browse catalog | Products load with images | | | |
| TC-CAT-02 | P2 | Search "silk" | Silk products shown | | | |
| TC-CAT-03 | P2 | Filter by category "Velvet" | Only velvet products shown | | | |
| TC-CAT-04 | P3 | Filter by price range | Products within range shown | | | |
| TC-CAT-05 | P3 | Sort by price low→high | Correct order | | | |
| TC-CAT-06 | P2 | Product details page | Name, price, stock, variants shown | | | |
| TC-CAT-07 | P2 | Out-of-stock variant | Add to cart disabled | | | |
| TC-CAT-08 | P3 | Related products | Same category products shown | | | |

## 3. Cart & Wishlist

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-CART-01 | P2 | Add to cart (guest) | Item stored locally | | | |
| TC-CART-02 | P2 | Add to cart (signed in) | Item stored locally on the device | | | |
| TC-CART-03 | P2 | Update quantity | Total recalculated | | | |
| TC-CART-04 | P2 | Remove from cart | Item removed | | | |
| TC-CART-05 | P3 | Add to wishlist (signed in) | Product saved locally on the device | | | |
| TC-CART-06 | P3 | Move to cart from wishlist | Item added, removed from wishlist | | | |

## 4. Checkout

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-CHK-01 | P1 | Checkout without address | Validation error shown | | | |
| TC-CHK-02 | P1 | Add new address | Address saved and selected | | | |
| TC-CHK-03 | P2 | Select existing address | Address shown in review | | | |
| TC-CHK-04 | P2 | Shipping fee (Cairo) | 50 EGY | | | |
| TC-CHK-05 | P2 | Free shipping (>500 EGY) | 0 EGY shipping | | | |
| TC-CHK-06 | P2 | Select payment method | Method highlighted | | | |
| TC-CHK-07 | P1 | Place order (COD) | Order created, cart cleared | | | |

## 5. Payments

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-PAY-01 | P0 | Paymob card success | Payment completed, order confirmed | | | |
| TC-PAY-02 | P1 | Paymob card decline | Error shown, stock restored | | | |
| TC-PAY-03 | P1 | Duplicate Paymob callback | No duplicate order created | | | |

## 6. Admin

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-ADM-01 | P2 | Admin dashboard (admin user) | Stats and actions shown | | | |
| TC-ADM-02 | P1 | Admin dashboard (non-admin) | Access denied | | | |
| TC-ADM-03 | P2 | View order queue | All orders listed | | | |
| TC-ADM-04 | P3 | Filter orders by status | Correct filter applied | | | |
| TC-ADM-05 | P1 | Update order status | Status changed, notification sent | | | |
| TC-ADM-06 | P2 | Add tracking number | Tracking saved | | | |
| TC-ADM-07 | P2 | Low stock alert | Low stock products shown | | | |

## 7. Localization

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-L10N-01 | P3 | English UI | All strings in English | | | |
| TC-L10N-02 | P3 | Arabic UI | All strings in Arabic | | | |
| TC-L10N-03 | P3 | Arabic RTL | Layout mirrors correctly | | | |
| TC-L10N-04 | P3 | Switch language | UI updates immediately | | | |

## 8. Edge Cases

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-EDGE-01 | P3 | Slow network | Loading states shown | | | |
| TC-EDGE-02 | P3 | No network | Error states with retry | | | |
| TC-EDGE-03 | P3 | Empty cart checkout | Validation error | | | |
| TC-EDGE-04 | P2 | Concurrent stock update | Stock integrity maintained | | | |

---

## 9. Security — Secrets & Artifact Integrity

> These cases verify that no server-only secret is shipped inside the
> Flutter artifact. Build with
> `flutter build apk --release --dart-define-from-file=config/env.staging.local.json`
> before running. Extract the APK (`unzip -o app-release.apk -d apk-out`)
> and scan recursively.

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-SEC-01 | P0 | Flutter APK does not contain `.env` | No file named `.env` in extracted APK tree | | `find apk-out -name '.env' \| wc -l` → 0 | |
| TC-SEC-02 | P0 | Flutter APK does not contain `PAYMOB_` secrets | No `PAYMOB_API_KEY`, `PAYMOB_HMAC_SECRET`, `PAYMOB_INTEGRATION_ID`, or `PAYMOB_IFRAME_ID` values; literal token `PAYMOB_` only allowed in docstring comments (release AOT strips these) | | `grep -rao 'PAYMOB_[A-Z_]*' apk-out \| sort -u` → only docstring/comment matches, no real values; confirm no `sk_live`/`sk_test` patterns | |
| TC-SEC-03 | P0 | Flutter APK does not contain `SUPABASE_SERVICE_ROLE_KEY` | The service-role key is never compiled into the client. Only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN` may appear. | | `grep -ra 'SUPABASE_SERVICE_ROLE_KEY\|service_role\|eyJ.*eyJ' apk-out` → no service-role JWT; `String.fromEnvironment` audit in `lib/shared/services/env_config.dart` confirms only client-safe vars | |
| TC-SEC-04 | P0 | Release APK is not debug-signed | `app-release.apk` is signed with the production release key, v2/v3 scheme, NOT the Android debug cert | | `apksigner verify --print-certs app-release.apk` → `Verified using v2 scheme (JAR signing)`; subject DN is NOT `CN=Android Debug` | |

## 10. Security — Database, Migrations & RPC Grants

> Run against the **staging** Supabase project via SQL Editor or
> `supabase db query --linked`. Migration reconciliation (STATE.md P1)
> must be resolved before TC-SEC-05 can pass.

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-SEC-05 | P0 | Migration 015+ is applied | `supabase_migrations.schema_migrations` contains versions 001 through at least 015, and `018_confirm_cod_payment.sql`/`019_harden_rpc_and_payments_authorization.sql` are the on-disk versions actually applied (no slot drift). `confirm_cod_payment(UUID)` exists in `pg_proc`. | | `SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;` → ≥19 rows, 015–019 present; `SELECT proname FROM pg_proc WHERE proname='confirm_cod_payment';` → 1 row | |
| TC-SEC-06 | P0 | `process_paymob_callback` is service_role only | The RPC is executable only by `service_role` (PostgREST service key), not by `anon` or `authenticated`. | | `SELECT proname, proconfig, prosecdef FROM pg_proc WHERE proname='process_paymob_callback';` + grant check: `\df+ process_paymob_callback` shows grant only to `service_role`; attempt with anon JWT → 403/`permission_denied` | |
| TC-SEC-07 | P1 | `confirm_cod_payment` is authenticated only | The RPC is executable by `authenticated` and NOT by `anon`. Non-owner users get `not_owner` (or equivalent) error. | | `\df+ confirm_cod_payment` → grant to `authenticated`, no grant to `anon`; anon call → 401/403 | |
| TC-SEC-08 | P1 | `create_checkout_order` is authenticated only | RPC grants to `authenticated` only; `anon` cannot create orders. | | `\df+ create_checkout_order` → no `anon` grant; anon POST → 401 | |
| TC-SEC-09 | P1 | `update_order_status` is authenticated only | RPC grants to `authenticated` (or admin-gated) only; `anon` cannot change status. | | `\df+ update_order_status` → no `anon` grant; anon POST → 401; non-admin escalation covered by TC-SEC-14 | |
| TC-SEC-10 | P0 | `payments` table does not allow client INSERT | No `INSERT` privilege on `payments` for `anon` or `authenticated`. RLS policy does not permit client-side payment row creation. Default-deny. | | `SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name='payments' AND privilege_type='INSERT';` → no rows for `anon`/`authenticated`; direct INSERT with anon JWT → 42501 | |

## 11. Security — Network, CORS & Paymob Callback Integrity

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-SEC-11 | P0 | CORS is not `"*"` in production | Staging/production Supabase config and Edge Function CORS headers do not use wildcard origin. Authenticated endpoints reflect the allow-list only. | | `supabase projects api-key --project-ref <prod>` + `curl -sI -H 'Origin: https://evil.example' <api-url>` → `Access-Control-Allow-Origin` is NOT `*` (or absent); review `supabase/config.toml` `[auth.external]` and Edge Function `cors` headers | |
| TC-SEC-12 | P0 | Paymob invalid HMAC is rejected | A forged callback with `hmac` field that does not match `HMAC_SHA512(sorted_qs, PAYMOB_HMAC_SECRET)` returns HTTP 401/403 and creates no payment row. `paymob-callback` must run with `verify_jwt=false` (HMAC is the auth, not JWT). | | `curl -X POST <callback-url> -d 'amount_cents=100&hmac=FORGED'` → 401/403; `SELECT count(*) FROM payments WHERE provider_order_id='<probe-id>';` → 0; `supabase functions list` shows `paymob-callback` with `Verify JWT: false` | |
| TC-SEC-13 | P0 | Paymob amount mismatch is rejected | A callback whose `amount_cents` does not match the stored order total is rejected as `amount_mismatch`; no payment marked `success`, no order transitioned to paid. | | `supabase db execute --linked supabase/tests/test_paymob_callback.sql` → amount_mismatch scenario PASS; `SELECT status FROM payments WHERE provider_order_id='<mismatch-id>';` ≠ `success` | |

## 12. Security — Authorization & Row-Level Security

> Run the full adversarial RLS suite:
> `supabase db execute --linked supabase/tests/test_rls_adversarial.sql`
> All 44 tests must pass. Evidence E1–E9 in
> `supabase/tests/test_rls_adversarial_results.md` must be collected.

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-SEC-14 | P0 | Non-admin cannot call admin RPCs | `update_order_status`, `get_low_stock_products`, and any admin-gated RPCs reject non-admin users. Self-escalation of `profiles.is_admin` is blocked by RLS/trigger. IDOR on `get_order_details` is blocked. | | RLS suite Section 3 (9 tests) all PASS; `\df+ update_order_status` shows admin check; non-admin `SELECT * FROM get_low_stock_products()` → 42501/empty | |
| TC-SEC-15 | P0 | Non-owner cannot read other user's orders | User A `SELECT * FROM orders WHERE user_id='<user-B-uuid>'` returns 0 rows. Same for `order_items`, `addresses`, `cart_items`, `wishlists`, `payments`. | | RLS suite Section 2 (7 negative tests) all PASS; 0 rows returned for cross-user reads | |
| TC-SEC-16 | P0 | Anonymous user cannot read private tables | `anon` role `SELECT` on `profiles`, `orders`, `order_items`, `addresses`, `cart_items`, `wishlists`, `payments`, `notifications`, `analytics`, `error_logs` returns 0 rows (or 42501). Public catalog (`products`, `categories`, `product_variants`, `product_images`) remains readable. | | RLS suite Section 1 (14 tests) all PASS; `anon` JWT `SELECT count(*) FROM orders;` → 0 | |

## 13. Production Readiness & Operations

| ID | Priority | Test Case | Expected | Actual | Evidence | Pass |
|----|----------|-----------|----------|--------|----------|------|
| TC-OPS-01 | P1 | CI runs on `master` | The primary CI workflow triggers on pushes/PRs to `master` (and `main` if present). Lint + `flutter analyze` + `flutter test` all green on the latest `master` commit. | | `.github/workflows/*.yml` shows `on: push: branches: [master]`; latest run URL with green status; branch protection requires CI pass before merge | |
| TC-OPS-02 | P0 | Secret scan passes | An automated secret scan (e.g. `gitleaks`, `trufflehog`, or `git-secrets`) over the repo and the release APK reports 0 findings for real secret values. | | `gitleaks detect --source . --report-path docs/evidence/gitleaks.json` → 0 findings (or all findings are false positives in `.env.example` placeholders, explicitly triaged); APK scan from TC-SEC-01/02/03 corroborates | |
| TC-OPS-03 | P1 | Crash reporting is not NoOp in production | The production build registers a real `CrashReportingService` (Sentry or equivalent) — NOT `NoOpCrashReportingService`. Sentry DSN is configured via `--dart-define`. The `scrubContext` path strips PII before send. | | `lib/shared/services/service_locator.dart` review → production branch registers Sentry-backed service when `SENTRY_DSN` is non-empty; `flutter build apk --release --dart-define-from-file=config/env.production.local.json` → DSN present; `test/crash_reporting_scrub_test.dart` PASS | |
| TC-OPS-04 | P0 | Staging and production Supabase projects are separated | The staging project ref (`alxwvyflasewslinufqe`) and production project ref are DIFFERENT. Production secrets are NOT staging secrets. No shared service-role key. | | `config/env.staging.local.json` `SUPABASE_URL` ≠ `config/env.production.local.json` `SUPABASE_URL`; `supabase projects list` shows two distinct projects; service-role keys differ (verified by length/prefix only, values not printed) | |

---

## Sign-Off

> No row may be marked `PASS` until its **Evidence** cell contains a
> concrete artifact (command output, URL, file path, or report). A blank
> `Actual`/`Evidence` cell is treated as `UNVERIFIED`, which is a `FAIL`
> for P0 and P1 cases.

### Roll-up Summary

| Section | P0 | P0 PASS | P0 FAIL | P1 | P1 PASS | P1 FAIL |
|---------|----|---------|---------|----|---------|---------|
| 1. Authentication | 0 | — | — | 0 | — | — |
| 2. Catalog | 0 | — | — | 0 | — | — |
| 3. Cart & Wishlist | 0 | — | — | 0 | — | — |
| 4. Checkout | 0 | — | — | 3 | — | — |
| 5. Payments | 1 | — | — | 2 | — | — |
| 6. Admin | 0 | — | — | 2 | — | — |
| 7. Localization | 0 | — | — | 0 | — | — |
| 8. Edge Cases | 0 | — | — | 0 | — | — |
| 9. Secrets & Artifact | 4 | — | — | 0 | — | — |
| 10. Database & RPCs | 3 | — | — | 3 | — | — |
| 11. Network & Callbacks | 3 | — | — | 0 | — | — |
| 12. Authorization / RLS | 3 | — | — | 0 | — | — |
| 13. Production Readiness | 1 | — | — | 3 | — | — |
| **TOTAL** | **15** | — | — | **13** | — | — |

### Launch Decision

- [ ] **GO** — All P0 and P1 cases `PASS`. Waivers (if any) attached.
- [ ] **NO-GO** — One or more P0/P1 cases `FAIL` or `UNVERIFIED`.
       Blocking IDs: ______________________________

### Approvers

| Role | Name | Signature / Commit SHA | Date |
|------|------|------------------------|------|
| QA Lead | | | |
| Security Lead | | | |
| Engineering Lead | | | |
| Product Owner | | | |

### Waivers & Exceptions

| ID | Justification | Approved by | Expiry |
|----|---------------|-------------|--------|
| | | | |

### Evidence Index

| Ref | Artifact | Path / URL |
|-----|----------|------------|
| E1 | APK `.env` scan output | `docs/evidence/apk-env-scan.txt` |
| E2 | APK `PAYMOB_` scan output | `docs/evidence/apk-paymob-scan.txt` |
| E3 | APK service-role scan output | `docs/evidence/apk-svcrole-scan.txt` |
| E4 | `apksigner verify` output | `docs/evidence/apksigner.txt` |
| E5 | `schema_migrations` query result | `docs/evidence/migrations.txt` |
| E6 | RPC grant dump (`\df+`) | `docs/evidence/rpc-grants.txt` |
| E7 | Adversarial RLS suite results | `supabase/tests/test_rls_adversarial_results.md` |
| E8 | Paymob callback probe (HMAC + mismatch) | `docs/evidence/paymob-callback-probe.txt` |
| E9 | Secret scan report | `docs/evidence/gitleaks.json` |
| E10 | CI run on `master` | `<workflow URL>` |
| E11 | Staging vs production project refs | `docs/evidence/project-refs.txt` |
