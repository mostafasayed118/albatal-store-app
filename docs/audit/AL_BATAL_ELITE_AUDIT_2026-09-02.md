# Al Batal Elite — Current Project Assessment

**Assessment date:** 2026-09-02
**Repository:** `C:\flutter_projects\albatal_store`
**Assessment basis:** current working tree and current HEAD `9f32c52` (`docs: establish code review standards and PR template`)
**Scope:** features, architecture, Flutter/Dart code, tests, Supabase schema/RLS/RPCs/Edge Functions, configuration, CI/release controls, UI/UX, and existing project evidence.

> This is a source-and-configuration assessment. Historical evidence is explicitly labeled. Production readiness is not inferred from local tests or isolated staging evidence.

---

## 1. Executive summary

Al Batal Elite is a substantial Flutter fabric-commerce application with a coherent feature-first architecture and a serious server-side commerce foundation. The current repository contains approximately **159 Dart production files / 17,179 lines**, **50 Dart test files / 7,547 lines**, **52 SQL files / 9,358 lines**, and **16 Edge Function TypeScript files / 2,686 lines**. It is not a prototype: it includes customer shopping, authentication, local persistence, server-authoritative checkout, COD and Paymob flows, admin catalog operations, RLS policies, payment callback verification, onboarding, English/Arabic localization, RTL support, and a Material 3 design system.

The principal risk is not missing UI polish alone. It is **state and environment divergence**: customer-visible behavior, debug/release repositories, staging/production deployment, source documentation, and release evidence do not always describe the same system. Several important issues are already visible in current source: customer order status can be mutated locally, invalid product IDs can resolve to the wrong product, address data is discarded or incomplete, payment initiation is not atomically idempotent, an authenticated user can invoke the global expiry worker, and deployment scripts can target whichever Supabase project is linked.

### Severity summary

| Priority | Current assessment |
|---|---|
| **P0 / release-blocking** | 6 concrete correctness, payment, authorization, or environment-control risks require closure or explicit owner sign-off. |
| **P1 / this sprint** | 10 reliability, UX recovery, privacy, observability, scalability, and verification gaps should be addressed before broad rollout. |
| **P2 / next sprint** | 10 maintainability, accessibility, documentation, retention, reproducibility, and product-completeness improvements. |

### The five most important actions

1. **Freeze the release truth:** reconcile the current commit, signed candidate, staging evidence, production evidence, and deployment target before any production operation.
2. **Protect payment/order state:** make Paymob initiation atomic/idempotent, remove customer order mutation, enforce the order payment method, and complete missing address/identity validation.
3. **Close the expiry authorization boundary:** authenticated users must not be able to invoke a global state-mutating expiry function.
4. **Make environments explicit:** staging and production commands must require an explicit project reference and reject mismatches.
5. **Make failure states honest:** replace raw exceptions, fabricated emails, silent catalog errors, fake fallback products, and misleading order/payment labels with explicit states and localized recovery paths.

### Verification limitation

`flutter analyze` has passed cleanly in recent runs. The full Flutter suite passed **275/275** in the isolated review-standards worktree when localhost proxy variables were removed. A later clean merged-result run reached 271 tests before a command timeout, and the repository also contains current source-level failures identified below. Treat test evidence as commit- and environment-specific; do not use older `STATE.md` entries as proof for this HEAD unless the referenced SHA matches.

---

## 2. Existing features and main functionality

### Customer application

- Splash and persisted first-run onboarding.
- Home storefront with categories, search, recent queries, flash-sale presentation, product cards, wishlist actions, and cart badge.
- Catalog filtering by query/category/color/price, sorting, and lazy product grid.
- Product details with variants, stock, image gallery/zoom, size guide, related products, ratings, delivery/returns information, wishlist, and add-to-cart.
- Local cart and wishlist persistence through SharedPreferences.
- Address creation and saved-address selection.
- Checkout with order review, server-confirmed subtotal/shipping/total, idempotency key, and payment routing.
- Cash on Delivery confirmation and Paymob hosted checkout with server-side payment status watching.
- Order history with active/completed/cancelled tabs.
- Email/password sign-up, sign-in, password reset, email verification/session restore.
- Profile, settings, support, privacy, terms, shipping, and returns pages.
- English and Arabic localization with RTL-aware layout support.
- Emerald/Gold light theme and Charcoal/Slate dark theme.
- Guest browsing; however, cart and wishlist routes are currently authentication-gated despite local persistence.

### Backend and operational capabilities

- Supabase Auth and profile trigger/synchronization.
- Postgres catalog, user-owned data, orders, payments, notifications, analytics, flash sales, product images, and admin operations.
- RLS and explicit grants for user isolation and admin access.
- Server-authoritative checkout RPC with price/stock/shipping validation, order-item snapshots, idempotency, and guarded stock decrement.
- COD confirmation RPC and race-safe payment/order state machine.
- Paymob initiation and HMAC-verified callback Edge Functions.
- Scheduled expiry, analytics, retention, and notification jobs.
- Admin catalog RPCs for products, variants, and product images.
- Staging verification runners for RLS, races, COD, Paymob, and HTTP probes.

### Explicitly not complete

- Cloud synchronization for cart, wishlist, addresses, and local-first collections is planned but not wired (`README.md:32-40`).
- Catalog data has a local/mock fallback and is not uniformly server-authoritative across all modes.
- Production cutover evidence for migrations 031–033, function digests, secrets, cron, Realtime, PITR, and Paymob production smoke is incomplete (`docs/evidence/prod-cutover-031-033/VERIFICATION.md`).
- Notification email delivery is not actually implemented by the reviewed notification function; it records notification status.
- Admin image management still requires a real file-picker/upload UX rather than dummy image bytes.

---

## 3. Structure and architecture

### Repository structure

```text
lib/
  core/                 Domain entities, Money, errors, utilities
  features/
    auth/               Auth/profile data, domain, Cubit/pages
    addresses/          Local saved-address flow
    admin/              Admin pages/repositories/RPC operations
    payments/           Payment entities/service/Cubit/pages
    settings/           Theme/locale settings
    storefront/         Catalog, cart, wishlist, checkout, orders, details
    support/            Contact/support flows
    onboarding/         Splash and first-run onboarding
  shared/
    components/         App shell, buttons, feedback, Stitch primitives
    routing/            GoRouter configuration
    services/           DI, configuration, storage, logging, crash reporting
    theme/              Material 3 light/dark tokens
  generated/            Generated localization

test/                   Unit, Cubit, widget, contract, accessibility, golden tests
supabase/
  migrations/           Forward SQL migrations through 033
  functions/            Checkout, Paymob, expiry, notification Edge Functions
  tests/                RLS, race, payment, RPC, staging runners
config/                 Build-time client-safe environment templates
docs/                   Architecture, evidence, release, audit, and runbooks
.github/workflows/      CI, daily triage, Android release workflows
```

### Data flow

```text
Flutter Widget
  -> BlocBuilder / BlocListener
    -> Cubit or page orchestration
      -> domain repository/service contract
        -> local persistence, Supabase client/RPC, or Edge Function
          -> SharedPreferences / Postgres / Paymob
```

### Architectural strengths

- Feature-first separation is clear and discoverable.
- Repository contracts and `Result<T>` provide useful test seams.
- Server-authoritative checkout is the correct trust boundary.
- `Money` uses integer minor units, reducing rounding errors.
- Cubit states are generally immutable and Equatable-based.
- Dependency injection through GetIt is established.
- Supabase/provider access is mostly concentrated in data/services.

### Architectural risks

- Debug and release order repositories differ, making local behavior non-representative.
- Some presentation pages import Supabase configuration directly and fabricate customer identity.
- Admin pages bypass `AdminRepository` and use direct Supabase calls plus `setState`.
- Catalog state contains legacy and current filter representations plus an unnecessary timer.
- Error translation is split across data, Cubit, and widget layers.
- Local persisted data is not clearly scoped to a user and is not cleared on sign-out.

---

## 4. Prioritized findings and recommendations

### P0 — Resolve before production or broad rollout

#### P0.1 — Customer order status can be mutated from the customer UI

**Location:** `lib/features/storefront/presentation/widgets/order_card.dart:68-81`; `lib/features/storefront/presentation/cubit/orders_cubit.dart:115-132`

**Issue:** Active customer orders expose an “Advance Order” action calling `OrdersCubit.advance()`. The release repository does not provide a corresponding trusted server mutation, while debug/local behavior persists it.

**Impact:** Customers can fabricate fulfillment progress in the UI. Order history becomes untrustworthy and debug/release behavior diverges.

**Action:** Remove the customer-facing action and keep fulfillment transitions exclusively in the admin/server-authorized path. Add a regression widget test that customer order cards have no status-mutating control.

**Benefit:** Restores order-status integrity and removes an unsafe debug/release divergence.

**Dependencies:** Confirm the admin fulfillment state machine and remove the obsolete localization key after callers are gone.

#### P0.2 — Unknown product IDs can render and purchase the first catalog product

**Location:** `lib/features/storefront/presentation/cubit/product_details_cubit.dart:83-100`

**Issue:** If the single-product request fails, the fallback chooses `allProducts.first` when the requested ID is absent. Failure also has an empty branch that emits no terminal error state.

**Impact:** A stale/deep-linked/tampered route can show a different fabric and allow purchase of the wrong product.

**Action:** Add explicit `notFound` and `error` states. Never substitute an unrelated product. Add unknown-ID, transport-failure, and success tests.

**Benefit:** Prevents wrong-product purchases and makes routing/data failures recoverable.

**Dependencies:** Update details page rendering and localization; no backend change is required if the repository already supports a single-product lookup.

#### P0.3 — Address data is incomplete and country is discarded

**Location:** `lib/features/storefront/presentation/widgets/address_form.dart:35-57`; `lib/features/storefront/presentation/cubit/checkout_cubit.dart:146-154`

**Issue:** The form validates country but submits `country: ''`. There is no phone field in the address form/entity/snapshot, although COD fulfillment typically requires customer contact data.

**Impact:** Orders contain corrupted address data and COD delivery may lack a usable contact number.

**Action:** Agree the canonical address contract with backend/RPC owners. Add validated, localized phone input where required; preserve entered country in entity, local serialization, checkout snapshot, and backend tests.

**Benefit:** Makes delivery data reliable and avoids lost-field operational failures.

**Dependencies:** Backend snapshot schema/RPC acceptance must be confirmed before changing the client contract.

#### P0.4 — Paymob initiation is not atomically idempotent per order

**Location:** `supabase/functions/paymob-initiate/index.ts:197-285`; `supabase/migrations/006_payments_table.sql:8-18`

**Issue:** The function reads for a pending payment and later inserts a new row through the service-role client. There is no unique pending-payment constraint or order lock. Concurrent requests can create multiple internal/provider payment sessions.

**Impact:** Double taps, retries, or multiple app instances can generate duplicate Paymob sessions and ambiguous callbacks. The provider may receive more than one payment attempt for one order.

**Action:** Introduce an atomic reservation RPC or transaction that locks the order and reuses/creates one active payment row. Add a partial unique index for the intended active lifecycle, handle unique-conflict rereads, and add a two-client concurrency test.

**Benefit:** Prevents duplicate provider work and reduces financial reconciliation ambiguity.

**Dependencies:** Requires a new reviewed migration, Edge Function change, staging race evidence, and Paymob sandbox validation.

#### P0.5 — Global expiry worker is callable by every authenticated user

**Location:** `supabase/migrations/031_realtime_and_cron_fix.sql:63-80`

**Issue:** `batch_expire_pending_orders()` is `SECURITY DEFINER`, mutates all expired orders, and grants execution to `authenticated` even though it is intended for cron/service-role use.

**Impact:** Any signed-in user can trigger cancellation and stock restoration across customers’ orders.

**Action:** Revoke execution from `authenticated`; grant only to the scheduler/service role. Add a live negative test and verify the grant matrix after deployment.

**Benefit:** Restores the scheduler trust boundary and prevents unauthorized global mutations.

**Dependencies:** Requires migration review and staging/production grant verification.

#### P0.6 — Environment targeting and release evidence are unsafe/inconsistent

**Location:** `supabase/config.toml:14`; `scripts/deploy-staging.sh:25-49`; `README.md:127-142`; `docs/RELEASE_GATE.md:228-254`; `docs/evidence/prod-cutover-031-033/VERIFICATION.md:19-24`

**Issue:** The checked-in Supabase project ID is associated with production evidence, while staging configuration points to another project. Deployment scripts use `supabase link`, `--linked`, or omitted project references. Documentation still says “14 migrations” although the repository contains migrations through 033. Release evidence records GO while production cutover rows remain TBD.

**Impact:** Operators can apply staging operations to production or mistake isolated-staging evidence for production readiness.

**Action:** Require explicit `STAGING_PROJECT_REF` / `PRODUCTION_PROJECT_REF`, reject mismatched refs, pass `--project-ref` to every mutation, and separate staging acceptance from production cutover. Re-freeze the exact candidate SHA and complete production evidence before GO.

**Benefit:** Reduces the highest-blast-radius operational risk: deploying to the wrong environment or releasing from the wrong commit.

**Dependencies:** Owner-authorized Supabase project access, exact release candidate selection, protected CI environments, and dashboard evidence.

---

### P1 — Address in the current sprint

#### P1.1 — Enforce the canonical payment method before Paymob initiation

**Location:** `supabase/migrations/026_forward_repair_confirm_cod_payment_and_grants.sql:89-97`; `supabase/functions/paymob-initiate/index.ts:130-149`

**Issue:** Paymob initiation checks ownership and pending status but does not require the order payment method to be `paymob_card`.

**Impact:** A COD or unsupported order can be submitted to Paymob, making order/payment method state inconsistent.

**Action:** Add an allowlist in checkout and require `paymob_card` in Paymob initiation. Add negative tests.

#### P1.2 — Authenticated auth changes do not reliably refresh GoRouter redirects

**Location:** `lib/shared/routing/app_router.dart:34-85`

**Issue:** The router reads AuthCubit state in `redirect` but has no stream/state refresh bridge.

**Impact:** Sign-out, session expiry, or admin-role loss may not redirect until another navigation occurs.

**Action:** Connect GoRouter refresh to AuthCubit changes and test protected-route sign-out/session expiry/admin-role loss.

#### P1.3 — Checkout presentation bypasses the repository boundary and fabricates an email

**Location:** `lib/features/storefront/presentation/pages/checkout_page.dart:5-8,45-57`; `lib/features/payments/presentation/pages/payment_method_page.dart:57-61`

**Issue:** Presentation imports `supabase_config` and falls back to `customer@example.com`.

**Impact:** Provider-specific coupling harms testability; payment initiation can use fake customer identity.

**Action:** Inject a domain-facing session/customer identity abstraction and block payment when required identity is missing.

#### P1.4 — Sign-out does not clear or user-scope local cart, wishlist, and addresses

**Location:** `lib/features/auth/presentation/cubit/auth_cubit.dart:171-178`; `lib/features/storefront/data/storefront_persistence.dart:24-27`; `lib/features/addresses/data/local_address_repository.dart:10-14`

**Issue:** SharedPreferences keys are global and are not cleared on sign-out.

**Impact:** A different user on the same device may see prior user data.

**Action:** User-scope keys and clear account-local caches on sign-out/auth-user change. Add two-user sign-out/re-login tests.

#### P1.5 — Catalog failures are presented as empty results

**Location:** `lib/features/storefront/presentation/pages/catalog_page.dart:104-113`; `lib/features/storefront/presentation/cubit/catalog_cubit.dart:249-271`

**Issue:** The page checks only `state.visible.isEmpty`, not loading/error state.

**Impact:** Offline/server failures look like “no products” and have no retry path.

**Action:** Render explicit loading, error-with-retry, empty, and ready states; preserve cached data with a stale indicator where appropriate.

#### P1.6 — Payment pending/failure UX is transient, hardcoded, and vulnerable to repeat initiation

**Location:** `lib/features/payments/presentation/pages/payment_method_page.dart:73-125`

**Issue:** Awaiting verification immediately opens WebView; failure/timeout/cancel strings are hardcoded English; Pay Now is not disabled for every in-flight state.

**Impact:** Users may retry while a payment remains unresolved and Arabic users receive incomplete feedback.

**Action:** Add persistent pending/failed/timeout panels, disable all in-flight initiation, localize all messages, and provide “check orders”/retry actions.

#### P1.7 — Raw provider/database errors can reach UI and telemetry

**Location:** `lib/features/storefront/data/checkout_service.dart:69-75`; `lib/features/storefront/presentation/cubit/checkout_cubit.dart:142-176`; `lib/shared/services/logger.dart:54-65`; `supabase/functions/checkout/index.ts:76-84`

**Issue:** Exceptions are interpolated into errors/logs instead of being mapped to stable codes.

**Impact:** SQL/provider details or personal data may leak to users, logs, or Sentry.

**Action:** Centralize redaction and error mapping at boundaries; expose localized allowlisted messages and sanitized correlation IDs only.

#### P1.8 — Private avatar flow uses a public-URL API

**Location:** `lib/shared/services/storage_service.dart:42-48`; `supabase/migrations/005_storage_buckets.sql:9-14`

**Issue:** The bucket is private but the client requests a public URL.

**Impact:** Correct privacy settings cause avatar display failure; making the bucket public would weaken privacy.

**Action:** Use short-lived signed URLs or authenticated downloads and test cross-user access.

#### P1.9 — Expiry processing is serial and Paymob initiation can create duplicate upstream work

**Location:** `supabase/functions/cancel-expired-orders/index.ts:94-131`; `supabase/migrations/031_realtime_and_cron_fix.sql:60-87`

**Issue:** Expired orders are processed one at a time; batch wrapper has no bounded `SKIP LOCKED` strategy.

**Impact:** Expiry can fall behind during bursts and increase lock contention.

**Action:** Implement bounded database batches with `FOR UPDATE SKIP LOCKED`, measurable indexes, and scheduler metrics.

#### P1.10 — Debug and release order behavior are not representative

**Location:** `lib/shared/services/service_locator.dart:56-74`

**Issue:** Debug uses local order persistence while release uses Supabase orders.

**Impact:** Bugs in release mapping, authorization, and network failure handling are hidden during ordinary local testing.

**Action:** Use the same repository implementation in all modes with an explicit fake/mock only in tests, or provide a clearly documented offline development mode with contract parity.

---

### P2 — Next sprint / planned hardening

1. **Paginate catalog and order history.** Current full-collection reads are acceptable for nine seed products but will degrade with growth. Add cursors, page sizes, server-side filters, and `(user_id, placed_at DESC)` indexing.
2. **Remove the legacy one-second catalog timer.** `CatalogCubit` emits every second even without a valid sale (`lib/features/storefront/presentation/cubit/catalog_cubit.dart:223-237`). Isolate countdown state in a sale widget/Cubit.
3. **Compute visible catalog results once per transition.** Repeated filtering/sorting allocations compound with unrelated state changes.
4. **Batch checkout variant resolution after measuring cart sizes.** Preserve guarded stock updates and test 1/10/50/100 line carts.
5. **Fix `state_transitions` retention.** The scheduled job targets `audit_logs`, while actual transitions are stored in `state_transitions` (`supabase/migrations/031_realtime_and_cron_fix.sql:94-102`). Confirm retention policy before deletion/partitioning.
6. **Move admin reads into typed repository/Cubit boundaries.** Admin pages currently call Supabase directly and use `setState`.
7. **Centralize money, date, and localization formatting.** Current `Money.format()` and checkout labels are not fully locale-aware; preview shipping can diverge from server shipping.
8. **Allow guest cart access and preserve sign-in redirect.** This aligns routing with the documented guest-first conversion flow.
9. **Add order details, refresh, and explicit status/payment labels.** Current order cards collapse paid/processing states and label cancelled/completed cards as delivered.
10. **Complete accessibility/product honesty.** Add 48dp targets, semantic labels, text-scale tests, persistent announcements, real share behavior, and remove voice-search affordances until implemented.

---

## 5. Suggested implementation sequence

### Phase 0 — Release truth and containment

- Freeze the exact source SHA under review.
- Mark production as unverified until production evidence is complete.
- Replace linked-project deployment commands with explicit project-ref guards.
- Revoke authenticated expiry-wrapper execution.
- Remove customer order advancement and wrong-product fallback.

**Exit evidence:** source tests for affected flows, live grant probe, project-ref guard proof, signed candidate SHA, and updated release register.

### Phase 1 — Payment and checkout integrity

- Implement atomic Paymob payment reservation/idempotency.
- Enforce payment-method consistency.
- Complete address country/phone contract.
- Remove fabricated customer email and provider-specific presentation imports.
- Add concurrent initiation, process-restart idempotency, empty-cart, and invalid-address tests.

**Exit evidence:** 2-client initiation race, Paymob sandbox success/failure/replay, COD negative cases, address snapshot assertion, and safe error scan.

### Phase 2 — Honest recovery and representative environments

- Add catalog/orders loading/error/empty/retry/refresh states.
- Add persistent payment pending/timeout/failure UX and localization.
- User-scope local data and test sign-out/re-login isolation.
- Unify debug/release repository behavior.
- Add provider contract tests for checkout, auth, orders, payment, and storage.

**Exit evidence:** full test suite, `flutter analyze`, Arabic/RTL widget checks, provider contract suite, and two-user local-storage isolation test.

### Phase 3 — Scale and product completeness

- Add pagination and query/index measurement.
- Remove legacy timers and consolidate state.
- Add admin repository/Cubit boundaries and typed DTOs.
- Implement notification delivery or rename the function to reflect queuing.
- Add order details, account deletion, accessibility coverage, and real share/deep links.

**Exit evidence:** representative payload/frame/latency budgets, accessibility/text-scale tests, admin workflow tests, and documented operational runbooks.

---

## 6. What is already working well

- Clean, feature-first navigation and state ownership patterns are present.
- Checkout is server-authoritative and uses integer minor-unit money.
- Paymob HMAC callback verification and client URL allowlisting are strong foundations.
- RLS, race, COD, and Paymob isolated-staging evidence is materially better than the current product documentation suggests.
- Flutter static analysis is clean.
- Product catalog, image, flash-sale, admin RPC, and Realtime infrastructure has been built beyond the original seed app.
- English/Arabic, RTL, light/dark theme, onboarding, and Material 3 foundation are implemented.
- CI includes formatting, analyzer, tests, Deno contracts, secret scanning, and release-artifact checks, although several gates and version pins should be tightened.

---

## 7. Verification commands before shipping

Run from the exact release candidate, with no proxy interception of localhost Flutter test traffic:

```bash
# Client checks
flutter pub get
flutter analyze
NO_PROXY=localhost,127.0.0.1,::1 \
no_proxy=localhost,127.0.0.1,::1 \
HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= \
flutter test

dart format --set-exit-if-changed .

# Repository/config checks
git diff --check
# validate migration filenames are ordered and current
# validate all deployment commands include explicit project refs
# scan tracked and staged files for secrets

# Backend contract checks
# Run RLS adversarial suite: expected 44/44
# Run race suite: expected 53/53 or updated documented baseline
# Run COD suite: expected 14/14
# Run Paymob sandbox suite and forged-HMAC/amount-mismatch probes
# Verify grants for batch_expire_pending_orders and audit_transition
# Verify production/staging migration parity and Edge Function configuration

# Release checks
flutter build apk --release --dart-define-from-file=config/env.production.local.json
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
# confirm release certificate, package identity, debuggable=false, no .env, no server secrets
```

### Required live negative tests

- An authenticated non-admin cannot call `batch_expire_pending_orders()`.
- An authenticated user cannot call internal audit helpers.
- A second user cannot read another user’s avatar, orders, addresses, payments, or local-device data.
- A COD order cannot be sent to Paymob initiation.
- Two concurrent Paymob initiation requests return one canonical internal payment/provider session.
- An invalid product ID produces not-found, never another product.
- Sign-out followed by another login cannot expose the prior user’s local cart/wishlist/address data.

---

## 8. Evidence and interpretation notes

- `STATE.md` contains valuable historical work logs but includes entries from branches/worktrees that do not match current HEAD. Treat every claim as candidate-SHA-specific.
- `docs/UI_UX_AUDIT.md`, `docs/UI_UX_FIX_PLAN.md`, and `docs/release-readiness.md` contain useful prior intent but should not be treated as current truth without source verification.
- Isolated-staging evidence demonstrates behavior in that environment; it does not prove production deployment, production secrets, production Auth settings, production function digests, or production Paymob routing.
- Untracked files in the workspace were not included in this assessment or changed.
