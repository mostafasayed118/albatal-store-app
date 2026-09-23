# Al Batal Elite — Code Quality Audit (2026-09-21)

- **Dimension:** Code quality — smells, duplication, dead code, style consistency, anti-patterns
- **Scope:** `lib/` (266 hand-written `.dart` files, 29,769 LOC) + `analysis_options.yaml`. `lib/generated/` contents skipped.
- **Baseline:** [2026-09-15/05-reaudit.md](../2026-09-15/05-reaudit.md) — Code Quality 7.5 → 9.5 → **10.0** (v2, after `48462d9` pinned `http`)
- **Tree:** `master` @ `ef91836` (merge of `bed0d1c` + `3d78b0c`; commit message claims "1044/1044")
- **Method:** fresh gates (analyzer / formatter / test suite), then full-tree mechanical scans — declaration-reference tracing across `lib/` + `test/` (dead symbols), Equatable `props` completeness (fields vs props diff over all 42 subclasses), duplicate-block hashing (10-line normalized windows across files), commented-out-code runs, `catch`/`on Exception` census (93 sites), non-null-assertion census (26), long-method measurement, magic-number scan, asset/font reconciliation vs `pubspec.yaml`. Every finding below was reproduced by opening the file.

---

## Gate results (re-run fresh on `ef91836`, 2026-09-21)

| Gate | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze` | ✅ **`No issues found!`** (105.4s, exit 0) — the clean-analyze claim **holds** |
| Formatter | `dart format --output=none --set-exit-if-changed lib` | ❌ **exit 1 — 8 of 269 files would be reformatted** — the format-clean claim **does NOT hold** |
| Tests | `flutter test` | ⚠️ **could not be executed in this environment** — 0 passed, 177 failed to load with `Unable to connect to flutter_tester process: WebSocketException: Invalid WebSocket upgrade request`. `1044/1044` is therefore **not independently re-verified** |

Stale snapshot `analysis_before.txt` (42 lines) is a bare `pub get` log with zero findings — consistent with today's clean analyzer, but it is not an analyzer report and cannot corroborate anything.

Unformatted files (all 8):

```
lib/features/admin/presentation/pages/admin_customers_page.dart
lib/features/storefront/data/supabase_coupons_repository.dart
lib/features/storefront/presentation/catalog_sort_label.dart
lib/features/storefront/presentation/pages/home_page.dart
lib/features/storefront/presentation/widgets/catalog_sort_bar.dart
lib/shared/components/app_lock_gate.dart
lib/shared/services/oauth_service.dart
lib/shared/services/storage_service.dart
```

## Baseline-claim verification

| Claim from 05-reaudit.md | Verified today | Evidence |
|---|---|---|
| "analyze clean" | ✅ **Reproduced** | `flutter analyze` → `No issues found!` |
| "424 files format-clean" (v2 harness) | ❌ **Not reproducible** | `dart format --set-exit-if-changed lib` exits 1 on 8 files. `git diff bed0d1c HEAD -- <file>` is **empty** for all 8, so this is not caused by post-`bed0d1c` edits: either the prior gate was not run with `--set-exit-if-changed`, or a toolchain change re-classified these files. Either way the claim cannot be reproduced on this tree |
| "safe-parse accessors consolidated into `core/utils` (c0f2d3e)" | ✅ **No regression** | `lib/core/utils/safe_parse.dart` is the only definition; grep for re-declared `_safeString`/`_optStr`/`_optInt` across `lib/` finds only `logger.dart:139 _safeErrorSummary` (different concern) |
| "drop dead Money helpers" (`3d78b0c`) | ⚠️ **Partially regressed** | `AdminReview` (`product_review.dart:33`) is dead — see CQ-05 |
| 42 `Equatable` subclasses | ✅ **All correct** | 42/42 declare `props`; 0 omit a declared field. The two `_m` memo fields (`catalog_state.dart:32`, `orders_cubit.dart:36`) are *deliberately* excluded and documented as such |

---

## HIGH — `WishlistStatus.error` is emitted but no UI consumes it: a failed wishlist load renders as "nothing saved yet"

**Location:** `lib/features/storefront/presentation/pages/wishlist_page.dart:64-96` | **Issue:** The page's `BlocBuilder<WishlistCubit, WishlistState>` branches only on `ws.products.isEmpty` — it never reads `ws.status`. Meanwhile the cubit emits `WishlistStatus.error` on two paths (`wishlist_cubit.dart:97` in `restore()`, `wishlist_cubit.dart:189` in `_persist`). A grep for `WishlistStatus.error` across `lib/` **and** `test/` returns only those two emission sites: no page, widget, or test ever branches on it. | **Impact:** When `restore()` fails (storage/network failure), `products` stays empty, so `wishlist_page.dart:72-83` renders the *empty-state* view — `l.wishlistEmptyTitle` / "explore categories". A user whose saved items failed to load is told they have saved nothing, with no error and no retry. This is the one state in the app that is silently converted into a different, wrong meaning. | **Fix:** Add the missing branch before the empty check:

```dart
if (ws.status == WishlistStatus.error) {
  return FeedbackView(
    type: FeedbackViewType.error,
    body: failureText(context.l10n,
        code: ws.errorCode, message: ws.errorMessage,
        fallback: context.l10n.errorTitle),
    onAction: () => context.read<WishlistCubit>().restore(force: true),
  );
}
```

and give `WishlistState` an `errorCode` field (`wishlist_cubit.dart:188-191` currently sets only the English `errorMessage`).

## HIGH — Raw casts sit inside an `on Exception` boundary in the new coupons repository; a malformed RPC payload throws `TypeError`, which that clause structurally cannot catch

**Location:** `lib/features/storefront/data/supabase_coupons_repository.dart:33` (`rows as List<dynamic>? ?? const []`), `:37` (`list.first as Map<String, dynamic>`), `:56` (`on Exception catch (e, st)`) | **Issue:** `validate()` hand-rolls its own try/catch instead of using the project's `Result.guard` (`lib/core/error/result.dart:28-39`), whose doc comment states the convention explicitly ("Local repositories delegate their try/catch boundaries here"). `Result.guard` uses a bare `catch (e, st)`, which catches `Error` too; `on Exception catch` does **not** — `TypeError`/`CastError` extend `Error`, not `Exception`. So the two raw casts at `:33`/`:37` are exactly the failure mode the enclosing clause cannot handle. The mapper behind them is already total (`coupon_mapper.dart:17-26` uses `safeString`/`safeInt`), so the *only* unguarded step is these two casts. | **Impact:** If the RPC ever returns a JSON object/scalar rather than a table (return-shape change, a PostgREST error envelope, or a future `RETURNS json` signature — the function is `RETURNS TABLE` today, `supabase/migrations/056_coupons.sql:45`), the cast throws a `TypeError` that escapes `validate()` and propagates to `checkout_cubit.dart:164`, which awaits it with no try/catch. The user's "Apply coupon" tap then does nothing at all (no state change, no failure emitted, no message) and an unhandled async error reaches Sentry. The same `on Exception catch` shape appears at 18 sites in `lib/` (`supabase_catalog_repository.dart:163,222,281`, `supabase_orders_repository.dart:66`, `supabase_reviews_repository.dart:45,120`, `notification_service.dart:82,111,139`, …) — the coupons repository is the one where an unguarded decode cast is inside the boundary. | **Fix:** two lines — replace `:33-37` with

```dart
final row = (rows as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .firstOrNull;
if (row == null) return const Failure(AppError(kCouponInvalid));
```

and change `:56` to a bare `catch (e, st)` (or wrap the whole body in `Result.guard(() async {...}, 'Failed to validate coupon', code: kCouponInvalid)`), so a decode `Error` becomes a `Failure` like every other repository.

## HIGH — Customer-facing English copy survives the l10n arc on the empty-cart path and is rendered verbatim to Arabic users

**Location:** `lib/features/storefront/presentation/cubit/checkout_cubit.dart:215-219` (`errorMessage: 'Your cart is empty.'`, **no `errorCode`**), rendered at `lib/features/storefront/presentation/pages/checkout_page.dart:82-99` | **Issue:** The l10n arc (`9619cd6`, `783df22`, `56317cb`, PR #80) replaced app-authored English with failure codes threaded to `failureText`. This path was missed: `failureText` (`lib/shared/l10n/failure_copy.dart:74-85`) resolves precedence as *known code → localized*, else *`message` verbatim*, else *fallback*. With `errorCode == null` the second rule wins and the raw English literal is returned and shown in a floating snackbar (`checkout_page.dart:97-99`). | **Impact:** An Arabic-locale user who empties the cart while on the checkout screen reads "Your cart is empty." — English in the one customer-facing flow the l10n arc was specifically created to clean up. The surrounding comment at `checkout_page.dart:91-93` asserts "uncoded ones are server-authored and pass through verbatim", but this message is **app-authored**, so the invariant the comment relies on is violated. | **Fix:** add a code and an ARB key, mirroring the neighbouring sites:

```dart
// checkout_cubit.dart:215
emit(state.copyWith(
  status: CheckoutStatus.error,
  errorMessage: 'Your cart is empty.',
  errorCode: kCheckoutCartEmpty,          // new const in failure_codes.dart
  idempotencyKey: state.idempotencyKey,
));
```

then add `kCheckoutCartEmpty => l10n.checkoutCartEmpty` to `failure_copy.dart:18-62` and the key to both ARBs. The `test/l10n/failure_copy_test.dart` pin will fail until the ARB entry exists, which is the intended guard.

## MEDIUM — Three `errorMessage` state fields are written by cubits and read by no widget; one is additionally pinned by three test assertions

**Location:** `lib/features/storefront/presentation/cubit/product_details_cubit.dart:157,166`; `lib/features/storefront/presentation/cubit/cart_cubit.dart:181`; `lib/features/storefront/presentation/cubit/wishlist_cubit.dart:98,190` | **Issue:** A full census of `.errorMessage` reads in `lib/` (excluding cubit/state definitions) lists 18 consumer files — and **none** of them is `details_page.dart`, `cart_page.dart`, or `wishlist_page.dart`. `details_page.dart:141` enters the `DetailsStatus.error` branch and renders a generic `FeedbackView(type: error)`; `cart_page.dart:34-39` does the same. So `'Unable to load product details.'` (`product_details_cubit.dart:157,166`), `'Cart may not be saved: …'` (`cart_cubit.dart:181`) and `'Wishlist may not be saved: …'` (`wishlist_cubit.dart:190`) are computed and discarded. Worse, the first of these is *asserted* by three tests (`test/features/storefront/presentation/cubit/catalog_offline_test.dart:169,197`, `test/features/storefront/presentation/pages/product_detail_test.dart:251`), so the suite pins dead state and would fail if someone correctly deleted the field. | **Impact:** English literals that the l10n sweep believed it had removed are still in the tree, and the dead fields give a false impression that the error text reaches the user. The test assertions actively protect the dead code. | **Fix:** wire the fields to the surfaces that already exist (`details_page.dart:141` and `cart_page.dart:34` should pass `body: failureText(l10n, code: s.errorCode, message: s.errorMessage, fallback: l10n.errorTitle)` and gain an `errorCode`), or delete `errorMessage` from `DetailsState`/`CartState`/`WishlistState` and update the three assertions. Do not leave them as write-only fields.

## MEDIUM — `AdminReview` is dead code

**Location:** `lib/features/storefront/domain/entities/product_review.dart:32-57` | **Issue:** `grep -rn '\bAdminReview\b' lib test` returns **only** the declaration and its own constructor/props lines — no reader, no test, no export. The admin moderation queue does not use it: `admin_reviews_cubit.dart:10` defines `typedef PendingReview = ({String id, String product, String text, int rating})` and the cubit holds `List<PendingReview>` (`:21,29`). `AdminReview` is a leftover from an earlier modelling attempt, in the same file as the live `ProductReview`. | **Impact:** A contributor reading `product_review.dart` will assume `AdminReview` is the admin-queue entity and wire new code to it, duplicating `PendingReview`. It is the one genuinely dead declaration left in `lib/` (the full-tree reference scan found 12 candidates; 11 are false positives — interfaces implemented in-file, extensions used implicitly, entry points — and this is the only real one). | **Fix:** delete `product_review.dart:32-57`. Nothing imports it.

## MEDIUM — The `dart format` gate is red on 8 files, and the local toolchain disagrees with the CI pin

**Location:** the 8 paths listed in the gate table | **Issue:** `dart format --output=none --set-exit-if-changed lib` exits 1 with 8 files "Changed". `git diff bed0d1c HEAD -- <each file>` is empty, so the content is unchanged since before the last audit — the divergence is formatting, not logic. The local toolchain is **Flutter 3.48.0-1.0.pre-57 / Dart 3.12.2**, while `.github/workflows/ci.yml:25` pins **`flutter-version: "3.47.x"`**. The formatter's opinion differs on exactly the constructs in these files (e.g. `catalog_sort_label.dart:12` wants `String catalogSortLabel(...) => switch (sort) {` on one line; `storage_service.dart:157-160` wants the three-part `assert` condition on one line). | **Impact:** A red gate that the project's own harness reported as green — the format claim can no longer be used as a merge signal. Because CI and the dev machine run different formatter versions, one of them will always be red for a contributor who runs the other: a format-only PR is unmergeable-green or unmergeable-red depending on which toolchain is used. | **Fix:** run `dart format lib test` once on the current toolchain and commit the result; then align `.github/workflows/ci.yml:25,51,81,238` to the dev version (or pin the dev version with an `.fvmrc` / `flutter-version` file) so the two stop drifting. Do not add a format gate to CI until they match.

## MEDIUM — 24 methods exceed 100 lines; the largest `build()` is 257 lines

**Location:** `lib/features/storefront/presentation/pages/home_page.dart:67-323` (257 lines, verified by brace matching), `lib/features/payments/presentation/pages/payment_method_page.dart:61-282` (222), `lib/features/payments/presentation/pages/instapay_instructions_page.dart:227` (202), `lib/features/storefront/presentation/pages/details_page.dart:98` (197), `lib/features/storefront/presentation/pages/checkout_page.dart:65` (189) | **Issue:** A full-tree scan for methods ≥100 lines returns 24 hits, of which 21 are `build()`. `home_page.dart`'s build is almost entirely widget composition (AppBar → search bar → recent-query chips → hero carousel → category chips → flash-sale sliver → grid), so the length itself is mostly mechanical — but lines `133-138` do compute view-layer business logic (flash-sale product resolution with a `visible.first` fallback), which belongs on `CatalogState` next to the existing `findProductById` and `featuredProducts` getters. | **Impact:** The 257-line method cannot be reviewed as a unit; any diff to the home screen touches a scroll region no reviewer can hold in view, and the flash-sale fallback rule is only testable through the widget. | **Fix:** extract `_HomeHeader`, `_RecentQueries`, `_FlashSaleSliver`, `_ProductGridSliver` as private widgets in the same file (no behaviour change), and move the flash-product resolution to `CatalogState` as `Product? get flashProduct`, mirroring `featuredProducts` (`catalog_state.dart`). Then `build()` composes five named widgets.

## MEDIUM — Three duplication clusters: catalog state-branching (×2), the auth failure listener (×3), the admin error surface (×10)

**Location:** `lib/features/storefront/presentation/pages/catalog_page.dart:89-101` ↔ `lib/features/storefront/presentation/pages/home_page.dart:108-127`; `lib/features/auth/presentation/pages/sign_in_page.dart:68-78` ↔ `lib/features/auth/presentation/pages/forgot_password_page.dart:39-49` ↔ `lib/features/auth/presentation/pages/reset_password_page.dart:42-52`; `lib/features/admin/presentation/pages/admin_dashboard_page.dart:49-58` ↔ `admin_inventory_page.dart:84-95` ↔ `admin_orders_page.dart:99-108` (same shape also at `admin_coupons_page.dart:58-59`, `admin_customers_page.dart:126-127`, `admin_reviews_page.dart:52-53`, `admin_sales_dashboard_page.dart:72-73`, and the admin product/variant/image pages) | **Issue:** A normalized 10-line-window duplicate scan across files returns 51 clusters; the three above are the substantive ones. The catalog pair is byte-identical logic (`loading → CatalogSkeleton`, `error + isOffline → OfflineCatalogView`, `error → FeedbackView`) — `catalog_page.dart:90` even carries the comment "Shared with HomePage", but only the `buildWhen` predicate is actually shared, not the view logic. The auth trio is the same `BlocConsumer` listener calling `showFloatingError(context, failureText(...))` with the same four arguments. The admin block is the same `FeedbackView(type: error, body: failureText(code:, message:, fallback: l10n.errorTitle), onAction: …)` repeated with only the retry callback differing. | **Impact:** Three independent copy sites for each rule means three places to change when the rule changes — and the auth comment at `forgot_password_page.dart:41` ("see sign_in_page.dart") already documents that a maintainer must remember the other copies. Divergence has already happened once in this area: `checkout_page.dart:93-98` special-cases `kCheckoutFailedCode` with its own branch instead of adding a code to `failure_copy.dart`. | **Fix:** extract three helpers: `Widget catalogBody(CatalogState s, CatalogCubit cubit)` (used by both storefront pages), `void showAuthFailure(BuildContext, AuthState)` for the auth listener, and `Widget adminFailureView(AdminState s, VoidCallback onRetry)` (used by the ~10 admin pages). Each is a pure move with no behaviour change; `failureText` already exists as the single source of copy.

## MEDIUM — `PendingOrder.status` is a raw `String` while `OrderStatus` is an enum in `core`, forcing a string comparison in the domain

**Location:** `lib/features/storefront/domain/entities/pending_order.dart:23,35` (`this.status = 'pending'`, `final String status`); `lib/features/storefront/domain/usecases/place_checkout_order_usecase.dart:102` (`if (value.status == 'pending')`); `lib/features/storefront/data/checkout_service.dart:122` (`safeString(data, 'status', fallback: 'pending')`) | **Issue:** `lib/core/entities/order.dart:17-27` already defines `enum OrderStatus { pending, placed, paid, processing, shipped, delivered, cancelled, refunded, expired }`, and the admin side has a third representation (`AdminOrderStatus`). The checkout path introduces a fourth: an untyped string on `PendingOrder` that is parsed from the wire as text and compared with a string literal in a usecase. | **Impact:** A typo (`'pendig'`) or a server value that is not in the enum fails silently — `== 'pending'` is simply false, with no analyzer help, unlike a `switch` over an enum. The domain layer, which is otherwise the most typed part of the codebase, is the layer doing untyped comparison. | **Fix:** type the field as `OrderStatus` and parse once at the boundary — `status: OrderStatus.values.firstWhere((s) => s.name == raw, orElse: () => OrderStatus.pending)` inside `checkout_service.dart:122`, or add `OrderStatus.fromName(String?)` next to the enum (the admin side already has this pattern: `AdminOrderStatus.fromName`, used at `admin_mappers.dart:32`).

## LOW — `WishlistPage.build` performs a side effect instead of reacting to cubit state

**Location:** `lib/features/storefront/presentation/pages/wishlist_page.dart:66-71` | **Issue:** Inside `BlocBuilder`'s `builder`, the code reads `context.read<WishlistCubit>()` and `context.read<CatalogCubit>()` and schedules `resolveProducts(...)` in `addPostFrameCallback` whenever `products.isEmpty && ids.isNotEmpty`. Rebuild-time mutation of a cubit is the anti-pattern; the only reason it does not loop today is that `WishlistCubit.resolveProducts` ends in `emit(state.copyWith(products: matched))` (`wishlist_cubit.dart:123`) and `Equatable` makes that a no-op emission when the resolved list is unchanged. | **Impact:** The correctness of the page depends on an equality implementation in another file: if `resolveProducts` ever emits an unconditionally-different state (e.g. a timestamp or a new list identity added to `props`), this becomes an infinite rebuild loop that no existing test would catch. | **Fix:** resolve in a listener, not a builder — wrap the body in `BlocListener<CatalogCubit, CatalogState>(listenWhen: (p, c) => !identical(p.allProducts, c.allProducts), listener: (c, s) => c.read<WishlistCubit>().resolveProducts(s.allProducts), child: …)`, or inject the catalog into `WishlistCubit` at the composition root and resolve on `restore()`.

## LOW — The InstaPay page repeats the same "mounted guard + floating snackbar" block seven times

**Location:** `lib/features/payments/presentation/pages/instapay_instructions_page.dart:142,156,166,180,194,209,221` | **Issue:** Seven copies of `if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(<localized message>)));`, differing only in the message. No shared helper exists (the file does use `showFloatingError` elsewhere in the codebase, so the pattern is available). | **Impact:** Low — seven sites to touch for any snackbar-behaviour change, and the `mounted` guard is easy to omit in an eighth copy. | **Fix:** add `void _snack(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }` and replace the seven blocks with `_snack(l.<key>)`.

## LOW — Inline magic durations for debounce and cache TTL

**Location:** `lib/features/storefront/presentation/cubit/catalog_cubit.dart:170` (`Duration(milliseconds: 300)`) and `lib/features/admin/presentation/cubit/admin_customers_cubit.dart:121` (`this.searchDebounce = const Duration(milliseconds: 300)`) and `catalog_cubit.dart:128` (`Duration(seconds: 60)`) | **Issue:** The search-debounce interval is written twice as an inline literal in two features; the catalog cache TTL is an unnamed literal. By contrast the neighbouring code names its timings (`paymob_payment_service.dart:106 _rpcTimeout`, `analytics_service.dart:50 flushInterval`), so the convention exists and is simply not applied here. | **Impact:** Cosmetic friction — the two debounces can drift silently, and the 60s TTL cannot be referenced from a test. | **Fix:** add `static const searchDebounce = Duration(milliseconds: 300);` to a shared constants location (or reuse one from the other feature) and `static const _cacheTtl = Duration(seconds: 60);` in `CatalogCubit`.

---

## What's done well

- **The `safe_parse` consolidation held, and it is genuinely the only copy.** `lib/core/utils/safe_parse.dart` defines `safeString`/`safeInt`/`optInt`/`optDouble`/`optString`/`safeBool`/`safeMap`/`safeDateTime`, and a grep for re-declared variants across `lib/` finds no duplicate. Total-decode discipline is real, not aspirational: `admin_mappers.dart:181-186,197-202` filter id-less rows, `supabase_admin_repository.dart:354-361` filters `r['id'] is String` before mapping, `supabase_orders_repository.dart:65` skips unusable rows, and the newest mapper (`coupon_mapper.dart:17-26`) is total from day one.
- **Analyzer is genuinely clean with an unusually opinionated lint set.** `analysis_options.yaml` turns on `prefer_single_quotes`, `directives_ordering`, `unawaited_futures`, `use_build_context_synchronously`, `cancel_subscriptions`, `depend_on_referenced_packages` — not just `flutter_lints` defaults — and `flutter analyze` still reports `No issues found!` across 266 files. The rejected rule (`discarded_futures`) is documented in-file with the reason and the measured cost, which is exactly how a lint decision should be recorded.
- **`Equatable` usage is flawless, including the hard part.** All 42 subclasses declare `props`, and a field-vs-`props` diff over all 220 declared fields found zero omissions. The two memo fields that *are* omitted (`catalog_state.dart:32`, `orders_cubit.dart:36`) are excluded deliberately, with a comment stating the memoization contract ("Memo fields are deliberately NOT part of `props`; equal states always derive equal views") — the subtle case handled explicitly rather than accidentally.
- **Zero `TODO`/`FIXME`/`HACK` markers and zero commented-out code.** A scan for comment runs ≥4 lines that look like Dart statements returns 0 hits across `lib/`; a census for `TODO|FIXME|XXX|HACK` returns 0. Debt is tracked in the audit ledger, not left as code graffiti.
- **No dead files and no dead methods.** Every one of the 266 `lib/` files is reachable by `import`/`export`/`part` from `lib/` or `test/` except the two entry points (`main.dart`, `main_smoke.dart`). A scan for public methods whose name appears exactly once in the whole corpus returns only framework overrides (`shouldRepaint`, `didPush`/`didPop`/`didReplace`/`didRemove`/`didStartUserGesture`) — i.e. nothing callable was left behind.
- **All declared assets exist and all are referenced.** `pubspec.yaml` declares `assets/images/`, `assets/images/onboarding/` and the Montserrat/Inter variable fonts; every file in `assets/` is present, and `grep` confirms every SVG (`1.svg`–`9.svg`, the four onboarding fabric illustrations, `logo.svg`) has at least one reference in `lib/`. There is no unused font or orphaned asset.

SCORE: 8/10 — The discipline that earned the prior 10.0 is still visible and largely intact: analyzer clean under a strict custom lint set, a single consolidated `safe_parse` boundary with no regression, 42/42 correct `Equatable` implementations including the memo-field subtlety, no TODO markers, no commented-out code, no dead files or methods, and a fully reconciled asset manifest. But the score cannot stand at 10.0: the `dart format` gate the prior harness reported green is **red** on 8 files (content unchanged since `bed0d1c`, so the green result is not reproducible), the test suite could not be executed here so `1044/1044` is unverified, and three real defects have accumulated since 2026-09-15 — an emitted-but-unconsumed `WishlistStatus.error` that renders a failed load as a false empty state, an unguarded decode cast inside an `on Exception` boundary in the new coupons repository (which cannot catch the `TypeError` it needs to), and an app-authored English string still reaching Arabic users on the empty-cart path the l10n arc was built to close — alongside a dead `AdminReview` class, three write-only error fields, a 257-line `build()`, and three copy-paste clusters. Every one of these is a small, mechanical fix; none requires a design decision.
