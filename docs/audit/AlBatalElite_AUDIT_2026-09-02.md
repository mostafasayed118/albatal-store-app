# Al Batal Elite — Project Audit & Improvement Roadmap

**Date:** 2026-09-02
**Scope:** Full codebase review — Flutter client, Supabase backend, Edge Functions, migrations, CI, configuration
**Method:** Read-only static audit. Five parallel domain audits (backend, performance, security, architecture, UI/UX) followed by independent source verification of every high-severity claim.
**Standards applied:** `docs/code-review-standards.md` (L0–L3 risk, P0–P3 severity)

> **Verification status legend used throughout**
> `[V]` = independently verified against source by the reviewer
> `[R]` = reported by a domain audit agent, **not** independently re-verified — treat as high-probability, confirm before acting

---

## 1. Executive Summary

Al Batal Elite is a **substantially complete, better-engineered-than-typical premium e-commerce application**. The payment path in particular is unusually well hardened: server-authoritative checkout, canonical HMAC-SHA512 callback verification with constant-time comparison, a `Money` value object using integer minor units, and a data layer with **zero `throw` statements** (every error is mapped into a `Result` type). Those are the decisions most teams get wrong, and this codebase gets them right.

**Measured scale**

| Area | Files | LOC |
|---|---|---|
| `lib/` (Flutter) | 159 Dart | 17,179 |
| `test/` | 50 Dart | 7,547 |
| `supabase/migrations` | 52 SQL | 9,358 |
| `supabase/functions` | 16 TS | 2,686 |
| `docs/` | 50 MD | 11,902 |

**The three systemic weaknesses**, in order:

1. **Failure states are designed in the cubit but not rendered in the UI.** Six of the main screens define an `error` status; only three render it. The product-details screen has no error state at all and will spin forever on a failed load.
2. **The `admin` feature bypasses every architectural convention the rest of the codebase follows** — no `Result`, no `Money`, no domain models, direct `Supabase.instance.client` access from widgets, and zero tests.
3. **The release code path is never tested.** Dependency injection selects the orders repository by `kDebugMode`, so all 275 tests exercise the local `SharedPreferences` implementation while production ships the Supabase one.

None of these is catastrophic. All are fixable in weeks, not months. The recommendation is to treat **P0 items as release blockers** and sequence the rest.

---

## 2. What the Project Is

### 2.1 Product

A premium fabric-commerce mobile app for the Egyptian market (EN/AR, EGP). B2C storefront plus an admin console for catalogue and fulfilment.

### 2.2 Structure

Feature-first Clean Architecture — `presentation → domain → data`.

| Feature | Files | LOC | pres / domain / data |
|---|---|---|---|
| storefront | 73 | 6,078 | 57 / 7 / 9 |
| admin | 11 | 2,027 | 9 / **1** / 1 |
| auth | 11 | 1,130 | 6 / 3 / 2 |
| payments | 7 | 1,115 | 3 / 3 / 1 |
| onboarding | 6 | 549 | 4 / 1 / 1 |
| settings | 5 | 257 | 3 / 1 / 1 |
| addresses | 5 | 227 | 2 / 2 / 1 |
| support | 4 | 211 | 1 / 2 / 1 |

Plus `core/` (8 files, 336 LOC — clean), `shared/` (24 files, 1,869 LOC), `generated/l10n`.

**Stack:** Flutter 3.x / Dart 3.x, `flutter_bloc ^9.1.1`, `get_it ^9.2.1`, `go_router ^17.5.0`, `supabase_flutter ^2.8.4`, `sentry_flutter ^9.27.0`, `webview_flutter ^4.10.0`, `cached_network_image ^3.3.1`.

**Backend:** Supabase Postgres (33 migrations), Auth, RLS, Storage, Edge Functions (Deno/TS), Realtime, `pg_cron`.

### 2.3 Functionality — end-to-end journey status

| Step | Screen | Status |
|---|---|---|
| Browse (home) | `home_page.dart` | Complete — hero, chips, flash sale, grid |
| Browse (catalogue) | `catalog_page.dart` | Complete, **no error state** |
| Categories | `categories_page.dart` | Complete |
| Search | `stitch_search_bar.dart` | Exists; **mic button is a stub** (always toasts "coming soon") |
| Filters | `filter_sheet.dart` | **Complete** — category, colour, price range, sort, active-filter chips |
| Product detail | `details_page.dart` | Colour/length/qty selection present; **CRITICAL** infinite spinner on error |
| Cart + qty edit | `cart_page.dart` | Quantity stepper, swipe-to-dismiss with undo; **no error state** |
| Address CRUD | `addresses_page.dart` | Create/edit/delete/set-default |
| Checkout | `checkout_page.dart` | Server-confirmed totals, validation, idempotency |
| Payment | `payment_method_page.dart` | Paymob card (hosted WebView) + COD |
| Order confirmation | `order_success_page.dart` | Complete |
| Order history | `orders_page.dart` | 3 tabs; **no error state** |
| Order tracking | `status_progress.dart` | Visual tracker present (see F-05) |
| Wishlist | `wishlist_page.dart` | Complete, reachable from nav and profile |
| Admin | various | Dashboard, orders, inventory, catalogue — **3 pages unreachable** |

### 2.4 What is genuinely strong — preserve these

- **`Money` as integer minor units** (`core/entities/money.dart`) — no float rounding in the money path.
- **Zero `throw` in the entire `data/` layer.** All 30 `catch` blocks return `Failure(AppError(...))` with the raw exception retained as `cause`, never interpolated into user-facing text. `[R]`
- **Pure domain entities.** No `fromJson`/`toJson`/annotations anywhere in `domain/`. `[R]`
- **Server-authoritative checkout** + canonical HMAC-SHA512, constant-time comparison in the Paymob callback. `[R]`
- **RLS correctly scoped.** Orders expose **only** `orders_select_own` (SELECT) — no UPDATE/DELETE policy, so clients cannot mutate order state. `[V]`
- **Design-token discipline on colour.** ~99% of colours flow through `app_theme.dart`; only 4 hardcoded `Color(0x…)` outside the theme file. `[R]`
- **RTL readiness.** Zero `EdgeInsets.only(left:|right:)`; uses `EdgeInsetsDirectional`, `PositionedDirectional`, `AlignmentDirectional` throughout. Arabic will not structurally break layout. `[R]`
- **Full EN/AR parity** — 247 keys in both `.arb` files, zero missing. `[R]`
- **Centralised image loading** (`app_image.dart:46-53`) with both `placeholder` and `errorWidget`. Zero bare `Image.network`. `[R]`

---

## 3. Verified Findings

### F-01 — Product details can never leave the loading state `[V]` — CRITICAL

`lib/features/storefront/presentation/cubit/product_details_cubit.dart`

`DetailsState` (lines 7–44) has **no status or error field**. `loadProduct` swallows both failure paths:

```dart
// line 61
failure: (_) => null,
// line 100
failure: (_) {},
```

On failure **nothing is emitted**. `details_page.dart:41-46` renders a bare `CircularProgressIndicator` when `product == null`, producing a **permanent, unrecoverable spinner** with no error text and no retry.

**Compounding defect (line 88-89):** when the single-product fetch fails, the fallback scan silently substitutes a different product:

```dart
final product = allProducts.firstWhere((x) => x.id == id,
    orElse: () => allProducts.first);
```

A user following a deep link to product X can be shown product Y with no indication.

### F-02 — Router guard cannot react to auth changes `[V]` — HIGH

`lib/shared/routing/app_router.dart:34`

`appRouter` is a top-level `final GoRouter`. Its `redirect` reads `context.read<AuthCubit>().state` (line 38), but there is **no `refreshListenable` anywhere in `lib/`** (verified: zero grep matches). Nothing re-triggers `redirect` when `AuthCubit` emits, so sign-in and sign-out do **not** re-evaluate protected routes.

Practical consequence: after sign-in, a user redirected to `/sign-in?redirect=/checkout` may remain on the sign-in screen, and after sign-out a user can remain on an auth-gated screen until an unrelated navigation occurs.

Secondary: route paths are **triplicated** (public set lines 42–58, `authRequired` list 69–78, `GoRoute` definitions 86–159). Because the public set is prefix-matched, a typo silently flips a route between protected and public.

### F-03 — Admin feature bypasses every convention `[V]` — HIGH

- `features/admin/domain/repositories/admin_repository.dart:55,65` — `required double basePrice`, `double? priceOverride`. The database stores `base_price INTEGER` in minor units and `supabase_catalog_repository.dart:288` reads it as `int`. This is a **unit mismatch**, not a style issue: passing `149.99` into an integer-piastre column yields 149.
- The interface returns raw `Future<List<Map<String, dynamic>>>` / `Future<void>` — no `Result`, no domain entities. Error mapping is therefore forced into presentation (`admin_cubit.dart:86,98,112,124,136` each `catch (e)` and hardcode a message).
- `Supabase.instance.client` is called **directly from two pages** — `admin_image_manager_page.dart:39` and `admin_variant_editor_page.dart:37` — bypassing the repository entirely for image and variant writes.
- **Zero test coverage** for `AdminCubit` (0 references in `test/`) despite it handling orders, stock, and money.

### F-04 — Error states defined but not rendered `[V]` — HIGH

Cubits model failure correctly; screens ignore it. Measured across `lib/features/storefront/presentation/pages/` by grepping for status checks:

| Screen | Handles error? |
|---|---|
| `checkout_page.dart:58` | Yes |
| `home_page.dart:98` | Yes (with retry) |
| `categories_page.dart:25` | Yes |
| `catalog_page.dart` | **No** |
| `cart_page.dart` | **No** |
| `orders_page.dart:18` | **No** (handles `loading` only) |

`CartStatus.error` exists (`cart_cubit.dart:10`) but `cart_page.dart:22` branches only on `items.isEmpty` — **a failed cart load renders as "your cart is empty"**. Likewise `OrdersStatus.error` + `errorMessage` (orders_cubit.dart:23,28) are unrendered.

### F-05 — Order status "Advance" button misleads users `[V]` — MEDIUM (corrected)

`order_card.dart:77-81` exposes an "Advance order" button on active orders, calling `OrdersCubit.advance()`.

**Correction to the initial audit.** The UI audit flagged this as a data-integrity breach (a customer mutating their own order). **It is not.** Verified:
- `supabase_orders_repository.dart:52-58` — `writeOrders` is a deliberate **no-op**: *"Server-backed repository is read-only from the client side… writeOrders is a no-op here to satisfy the interface contract."*
- `002_rls_policies.sql:133-136` — the only orders policy is `orders_select_own` FOR SELECT. There is no UPDATE policy.

So the server cannot be corrupted. The real defect is **the UI displays a status that is not real**: the local cubit state advances to "Delivered" and reverts on the next fetch or app restart. A customer may believe their order shipped when it has not. Remove the button or gate it behind an admin role / debug flag.

### F-06 — Release code path is never tested `[V]` — HIGH

`lib/shared/services/service_locator.dart:72-74`

```dart
..registerLazySingleton<OrdersRepository>(() => kDebugMode
    ? LocalOrdersRepository(getIt<LocalStorefrontPersistence>())
    : SupabaseOrdersRepository())
```

Every one of the 275 tests runs in debug mode and therefore exercises `LocalOrdersRepository` (SharedPreferences). `SupabaseOrdersRepository` — the implementation that ships — has **zero test references**. The same `kDebugMode` pattern risk exists wherever debug/release behaviour diverges.

### F-07 — Promo banner text is effectively invisible `[V]` — HIGH

`lib/features/storefront/presentation/widgets/promo_banner.dart:32`

Eyebrow text uses `scheme.secondary.withValues(alpha: .9)` (gold `#904D00`) on a gradient from `scheme.primary` (`#003527`) to `primary@75%`.

Computed WCAG contrast: **≈2.1:1 at gradient start, degrading toward ≈1.7:1** — against a 4.5:1 requirement for normal text (3:1 for large). The headline "New Silk Collection" is effectively unreadable. This is the app's primary merchandising surface.

Related: the out-of-stock state of `add_to_cart_button.dart:31,33` computes to **≈2.09:1** `[R]`, so "Out of stock" — the single most important conversion-blocking message — is also barely legible.

### F-08 — Repository hygiene `[V]` — LOW (trivial fix)

A directory literally named `C:` sits inside the project root, containing **614 untracked files** — an artifact of a worktree/creation command that used an absolute Windows path (`C:\flutter_projects\albatal_store\C:\flutter_projects\albatal_store_wt_supabase_high_fixes\…`).

It is **not git-tracked** (`git ls-files` returns 0), so it does not pollute the repository contents. It does pollute every grep, glob, LOC count, and IDE search — including the metrics in this report, which were filtered to exclude it. Delete it.

### F-09 — Accessibility is effectively absent `[R]` — HIGH

Across all of `lib/`: **1** `Semantics(` widget (in a file with zero importers), **0** `semanticLabel`, **0** `Tooltip`, **0** `MergeSemantics`.

Touch targets below the 48×48dp Material minimum:
1. `stitch_product_grid_card.dart:60-84` — wishlist heart, **30×30dp**, on every product card.
2. `add_to_cart_button.dart:26` — `Size.fromHeight(40)`, the **primary purchase CTA** (also violates DESIGN.md's own 50px minimum).
3. `checkout_page.dart:160,167` — **40px** "Proceed to Payment".

Text scaling is unhandled — no `MediaQuery.textScaler` anywhere, combined with hardcoded heights around text (`promo_banner.dart:17` = 180, `add_to_cart_button.dart:26` = 72, `checkout_page.dart:160` = 72, `details_page.dart:99` = 200, `image_gallery.dart:29` = 300). Large system fonts will clip.

### F-10 — Two divergent `Product` mappers `[R]` — HIGH

`supabase_catalog_repository.dart:284-340` (Postgres rows) vs `storefront_persistence.dart:159-173` (local JSON cache). The persistence mapper **omits `images`, `sizes`, `colors`, `stock`, `rating`, `reviewCount`**.

A cart restored from local storage therefore holds materially different products than the same cart fetched from the network — silently. Two sources of truth for one entity.

### F-11 through F-16 — Reported, not independently verified `[R]`

| ID | Finding | Severity | Source |
|---|---|---|---|
| F-11 | `031_realtime_and_cron_fix.sql:63-80` — `batch_expire_pending_orders()` is `SECURITY DEFINER` with `EXECUTE` granted to `authenticated`; any signed-in user can trigger order expiry | HIGH | backend |
| F-12 | `025_race_safe_state_machine.sql` — lock-order inversion: callback locks payment→order, expiry locks order→payment. Deadlock risk under concurrent load | HIGH | backend |
| F-13 | `paymob-initiate/index.ts:130-149,197-285` — non-atomic read-then-insert. Concurrent taps create duplicate payment intents; no payment-method enforcement | HIGH | backend |
| F-14 | `supabase/config.toml:14` targets project `alxwvyflasewslinufqe`, identified as **production** in release evidence, while `config/env.staging.json:2` targets `zvpjngdgbpnkkqrorkul`. Staging deploy scripts operate against the linked (possibly production) project | HIGH | security |
| F-15 | `android/app/build.gradle.kts:20-39,61-87` + `.github/workflows/ci.yml:306-314` — release signing is **not fail-closed**; CI only *warns* on a debug-signed APK | HIGH | security |
| F-16 | Legacy 1-second timer rebuilds the entire catalogue/home (`catalog_cubit.dart:223-237`, `flash_sale_ticker.dart:46-58`, `home_page.dart:91-119`) | HIGH | performance |

Additional `[R]` items: sign-out does not clear cart/wishlist/address `SharedPreferences` (MEDIUM); `send-order-notification/index.ts:141-150` inserts `status: "sent"` with no email provider call (MEDIUM); product-image rows use `USING (true)` and a public storage bucket (MEDIUM); `storage_service.dart:46-60` calls `getPublicUrl()` on the private `avatars` bucket (MEDIUM); raw exception text reaching logs/Sentry (MEDIUM); ~30 customer-facing hardcoded English strings in the checkout and address forms (HIGH); home search placeholder stays English in Arabic (HIGH).

---

## 4. Prioritized Improvement Roadmap

Sequenced by risk-adjusted value. P0 = release blockers.

### P0 — Release blockers

**P0-1. Fix the product-details dead-end (F-01)**
- **Rationale:** A permanent spinner on the highest-intent screen in the app is a direct conversion loss and the single most likely source of 1-star reviews. It is also the cheapest fix on this list.
- **Action:** Add `status` + `errorMessage` to `DetailsState`; emit a failure state at `product_details_cubit.dart:61` and `:100`; render an error view with retry in `details_page.dart`. Remove the `orElse: () => allProducts.first` fallback — an unknown id must produce an error, never a different product.
- **Benefit:** Eliminates an unrecoverable state; prevents customers being shown the wrong product.
- **Dependency:** None. Independent of all other work.

**P0-2. Resolve environment targeting before any further deployment (F-14)**
- **Rationale:** If a staging deploy script targets the linked production project, every subsequent recommendation on this list is being validated against the wrong database. This blocks and outranks everything backend-related.
- **Action:** Pin every `supabase` CLI invocation to an explicit `--project-ref`; require `--project-ref` in deploy scripts; add a pre-deploy assert that fails when the target is production outside a release tag. Add the prod ref to a denylist.
- **Benefit:** Removes the possibility of running migrations or seeding against production by accident.
- **Risk:** Deploy scripts must be updated in the same change or CI breaks. **Requires human review per `AGENTS.md`** (CI/CD modification).

**P0-3. Verify and fix the release-signing gate (F-15)**
- **Rationale:** A debug-signed APK cannot be published to the Play Store and, worse, a warn-only gate means a signing misconfiguration reaches the artifact stage silently.
- **Action:** Make the CI signing check fail the build rather than warn. Fail closed in `build.gradle.kts` when release signing config is absent.
- **Dependency:** Requires keystore secrets in CI. **Requires human review per `AGENTS.md`.**

**P0-4. Make Paymob initiation idempotent (F-13)**
- **Rationale:** Non-atomic read-then-insert under concurrency creates duplicate payment intents and duplicate orders. This is a money bug with a direct financial-reconciliation cost.
- **Action:** Move initiation into a single transactional Postgres RPC or use a unique constraint on `(order_id, attempt)` with `ON CONFLICT DO NOTHING`; return the existing intent when one is already pending. Enforce allowed payment methods server-side.
- **Benefit:** Removes duplicate-charge and orphaned-intent classes of bug entirely.
- **Dependency:** Requires a new migration — **human review required per `AGENTS.md`**. Coordinate with P0-2 (must land on the correct project).

### P1 — Correctness and trust

**P1-1. Render error states on all six main screens (F-04)**
- **Rationale:** "Your cart is empty" when the cart actually failed to load destroys trust silently and generates support tickets that are hard to diagnose.
- **Action:** Handle `error` in `catalog_page.dart`, `cart_page.dart`, `orders_page.dart` using the existing `FeedbackView` component, each with a retry action. Fix `addresses_page.dart:22` (`Text(s.errorMessage!)` null-assert) and dispose its four `TextEditingController`s (`:64-67`).
- **Benefit:** Consistent, recoverable failure UX; removes a crash risk.
- **Dependency:** Partially overlaps P0-1 — do them in one pass.

**P1-2. Add `refreshListenable` to the router (F-02)**
- **Rationale:** Auth-gated navigation that does not react to auth changes is a class of bug that reproduces intermittently and is expensive to diagnose later.
- **Action:** Pass `refreshListenable: GoRouterRefreshStream(authCubit.stream)`; consolidate the triplicated route lists into one source of truth.
- **Benefit:** Reactive, correct auth gating; eliminates silent route-protection drift.
- **Dependency:** Minor refactor of `app_router.dart`. Coordinate with P1-3 if `AuthCubit` lifecycle changes.

**P1-3. Test the release code path (F-06)**
- **Rationale:** Shipping an implementation that no test has ever executed is the highest-leverage testing gap in the project.
- **Action:** Replace the `kDebugMode` branch with an explicit injectable environment flag; add contract tests covering `SupabaseOrdersRepository` against a mocked `SupabaseClient` or a local Supabase instance.
- **Benefit:** The 275-test suite starts protecting what actually ships.
- **Gap:** Requires a Supabase test harness; no such infrastructure exists yet.

**P1-4. Close the RLS and locking gaps (F-11, F-12)**
- **Rationale:** A `SECURITY DEFINER` expiry function executable by any authenticated user lets a customer expire orders — including other users' orders, depending on the function body. Lock-order inversion will deadlock under real concurrency, and deadlocks surface as payment-callback timeouts, i.e. lost revenue.
- **Action:** Revoke `EXECUTE` from `authenticated` on `batch_expire_pending_orders()`; invoke it only via `pg_cron` with a service role. Normalise lock acquisition order across callback and expiry paths.
- **Dependency:** New migration — **human review required**. Confirm the deadlock empirically before restructuring, since the fix has real blast radius.

**P1-5. Unify the `Product` mappers (F-10)**
- **Rationale:** Divergent mappers produce state-dependent product data, which manifests as "my cart changed after restarting the app" — a bug that is nearly impossible to reproduce from a bug report.
- **Action:** Extract one `ProductMapper` used by both the network and persistence paths; add a round-trip test asserting a persisted product equals the fetched one.
- **Dependency:** Touches cart persistence — test the migration of existing local data.

### P2 — Quality, accessibility, and the admin feature

**P2-1. Accessibility baseline (F-09)**
- **Rationale:** One `Semantics` widget in 17k LOC, sub-48px touch targets on the primary purchase CTA, and no text-scaling support. This is both a quality issue and an increasing store-review / compliance risk.
- **Action:** Add `semanticLabel` to icon-only controls; raise the wishlist heart to ≥48dp and the CTA to DESIGN.md's 50px; replace fixed heights around text with `MediaQuery.textScaler`-aware constraints.
- **Benefit:** Materially better experience for users with large fonts or motor impairments.
- **Gap:** No golden/accessibility test infrastructure exists; consider adding `flutter_test` a11y assertions.

**P2-2. Bring `admin` into conformance (F-03)**
- **Rationale:** Admin is where the money, stock, and fulfilment logic lives, and it is the one feature with no `Result`, no `Money`, direct DB access from widgets, and zero tests.
- **Action:** Convert `AdminRepository` to `Result`-returning domain models; switch `double` prices to `Money`; move the two `Supabase.instance.client` calls behind the repository; add `AdminCubit` tests.
- **Benefit:** Removes the unit-mismatch class of bug (149.99 → 149) and makes admin testable.
- **Dependency:** Largest single item on this list. Split into (a) `Money` conversion — high value, small diff; (b) `Result` refactor; (c) tests. Sequence (a) first.

**P2-3. Fix the contrast failures (F-07)**
- **Rationale:** The promo banner is the app's main merchandising surface and its eyebrow text is unreadable; "Out of stock" at ≈2.09:1 is worse.
- **Action:** Use `onPrimary` or a lightened gold for text on the primary gradient; darken the out-of-stock state's text. Note that `app_button.dart:30-36` is already correct — update `DESIGN.md`'s `button-accent` token, which specifies `#FFFFFF` on `#D97706` (3.19:1, fails AA).
- **Benefit:** Immediate legibility improvement on high-impact surfaces.

**P2-4. Complete localization of the checkout path (F-09 / UI)**
- **Rationale:** ~30 hardcoded English strings sit in the checkout and address forms — the exact point where a user abandons if confused. The home search placeholder also stays English in Arabic.
- **Action:** Extract remaining literals into `app_en.arb`/`app_ar.arb`; replace the hardcoded `'Jan'…'Dec'` month list in `order_card.dart:102-116` with `intl` date formatting; pass `hintText` from `home_page.dart:127-130`.
- **Benefit:** Removes the last friction in the AR purchase path.

**P2-5. Remove the "Advance order" button (F-05)**
- **Rationale:** The UI asserts a fulfilment state the backend does not hold. Low data risk, real trust risk.
- **Action:** Delete `order_card.dart:73-83`, or gate it behind an admin role.
- **Benefit:** Order status stops lying to customers.

**P2-6. Retire the 1-second catalogue timer (F-16)**
- **Rationale:** Rebuilding the entire catalogue and home tree every second is the dominant battery/frame cost in the app.
- **Action:** Drive the flash-sale countdown from a single `ValueNotifier`-scoped widget, or tick only when a flash sale is actually active.
- **Benefit:** Measurable battery and jank improvement on mid-range Android devices, which is the Egyptian market's dominant hardware.

### P3 — Housekeeping

- **P3-1.** Delete the nested `C:` directory (614 untracked files) `[V]` — five minutes, unblocks clean tooling.
- **P3-2.** Connect or delete the three unreachable admin pages (`admin_product_edit_page.dart`, `admin_variant_editor_page.dart`, `admin_image_manager_page.dart`) — none is registered in `app_router.dart:136-147`.
- **P3-3.** Replace the fake mic button (`stitch_search_bar.dart:71-78`) with either voice search or no button.
- **P3-4.** Consolidate three near-identical empty/error views (`empty_state_view.dart`, `feedback_view.dart`, `catalog_empty_state.dart`).
- **P3-5.** Remove five unused widgets (zero importers): `bottom_action_button`, `catalog_search_bar`, `category_grid`, `menu_list_tile`, `payment_section`.
- **P3-6.** Move `checkout_service.dart:74`'s raw `$e` interpolation into the standard static-message pattern used everywhere else; reconcile `payment.dart:14-33`'s parallel `PaymentSuccess`/`Failed`/`Pending` types with `Result<T>`.
- **P3-7.** Migrate the 35 flat files in `test/` into a `test/features/` structure mirroring `lib/features/`.

---

## 5. Verification Methodology & Confidence

**Independently verified by the reviewer** (opened and read the source): F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-08. Contrast ratios in F-07 were computed from `app_theme.dart` hex values using the WCAG relative-luminance formula.

**Not independently verified** (accepted from domain agents): F-09 through F-16 and all `[R]` items. These rest on agent source reading with file:line citations, but the reviewer did not re-open each file. **Confirm before acting.**

**Explicit gaps in this audit:**
- **No runtime verification.** No `flutter run`, no device, no emulator. All overflow, text-scaling, and RTL claims are inferred from code structure, not observed.
- **Analyzer and tests were not executed during this audit.** Prior runs (isolated worktree) reported 275/275 passing and `flutter analyze` clean, but that was before these findings and on a different branch state.
- **Test coverage claims rest on identifier grep**, not `flutter test --coverage`. A test may exercise a unit indirectly without naming the type.
- **Contrast for derived colours** (e.g. Flutter's implicit `onSurfaceVariant`) was computed against plausible M3 defaults, not resolved at runtime. The out-of-stock figure stays a failure across all candidates tested.
- **Not examined:** `al-batal-elite-spec-kit/`, golden/regression test integrity, `pubspec.yaml` dependency hygiene, the 12 admin page bodies beyond targeted greps.
- **One architecture subagent returned empty output** and was re-dispatched; the re-run produced the F-03/F-10/§2.2 material.

**Bottom line.** The architectural foundations — layering, immutability, cubit discipline, the `Result` error contract, server-authoritative checkout — are genuinely strong and should be preserved. The debt is concentrated and addressable: **the admin feature, unrendered error states, and untested release paths.** Fixing P0 is roughly one to two weeks; P1 adds another two to three. None of it requires re-architecture.
