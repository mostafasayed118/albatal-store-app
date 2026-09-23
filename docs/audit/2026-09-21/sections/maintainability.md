# Al Batal Elite — Maintainability Audit (2026-09-21)

- **Dimension:** Maintainability — modularity, readability, naming, documentation, testability, ease of future modification
- **Scope:** `lib/` (266 hand-written `.dart` files, 29,769 LOC) + `pubspec.yaml` + `l10n/` + `.gitignore`. `lib/generated/` contents skipped.
- **Baseline:** [2026-09-15/05-reaudit.md](../2026-09-15/05-reaudit.md) — Maintainability 9.5 → 10.0 (v3/v5 ledger)
- **Tree:** `master` @ `ef91836` (both branches merged; 1044/1044 per commit message)
- **Method:** full-tree mechanical scans (`wc -l`, dartdoc-coverage script over all public declarations, TODO/ignore census, duplicate-class-name scan, ARB key diff, dead-symbol trace by grep across `lib/` + `test/`) plus full reads of the 5 largest files and every file cited below. Every claim below was reproduced by opening the file.

## Residual-register verification (as instructed)

| ID | Prior status | Verified today | Evidence |
|---|---|---|---|
| R3 (`AUD-011`, colour names) | "Implemented (commit 6256c80)" | **Data layer only — NOT closed at the UI.** `Product.colorName` is mapped and round-tripped but **never read** | `product_mapper.dart:138,169,216` write it; `grep -rn colorName lib test` shows zero presentation reads. See finding M-03 |
| R4 (`.gitignore` vs `lib/generated`) | Open (trivial) | ✅ **Closed** | `.gitignore:48` — "EXCEPTION: lib/generated/ (flutter gen-l10n output) IS" |
| R5 (admin-console localization) | Waived | **Console closed; invoice PDF still open** | `56317cb` localized ~70 strings (127 `context.l10n` uses in `lib/features/admin`); `git show 56317cb --stat -- lib/features/admin/domain/invoice/` is **empty**. See finding M-07 |

---

## HIGH — `lib/core/error/result.dart` is the most-used abstraction in the codebase and has no class documentation

**Location:** `lib/core/error/result.dart:3` (`sealed class Result<T>`), `:42` (`Success`), `:47` (`Failure`)
**Issue:** `Result`/`Success`/`Failure` are the return type of essentially every repository method in every feature, and the switch target of every cubit boundary. Only the `guard` factory (`:28`) carries a doc comment. The three class declarations themselves — the ones a new contributor hits first — carry none. The same gap applies to the other high-traffic core types: `lib/core/entities/product.dart:5` (`Product`) and `:102` (`CartItem`), `lib/core/entities/address.dart:3` (`Address`). Measured dartdoc coverage across `lib/core` + `lib/features` public declarations is **188/272 = 69.1%**; the missing 31% is concentrated in exactly these core types, while peripheral admin widgets are documented to a high standard. Coverage is inversely correlated with how often the type is read.
**Impact:** A contributor must infer the `Success`/`Failure` contract (when is a missing row `Success(null)` vs `Failure`?) from call sites rather than the type. `SupabaseProfileRepository` documents the answer (`supabase_profile_repository.dart:11-13`) while the type that defines it does not.
**Fix:** Add class-level dartdoc to the three declarations, stating the contract once:
```dart
/// A value-or-error return, used at every repository boundary.
///
/// [Success] wraps a value (a `null` value is a legitimate "absent row",
/// not an error). [Failure] wraps an [AppError]. Construct via
/// [Result.guard] so the try/catch boundary lives in one place.
sealed class Result<T> { ... }
```
Then document `Product`, `CartItem`, and `Address` with one paragraph each on their invariants (e.g. `Product.colors` is variant names, `Product.imageColor` is a placeholder tint).

## MEDIUM — `SupabaseAdminRepository` is an 824-line class implementing six ports

**Location:** `lib/features/admin/data/supabase_admin_repository.dart:293` (`SupabaseAdminRepository`), 20 public methods spanning `:298`–`:810`
**Issue:** The file is 2.0× the next-largest file in `lib/` (491 lines) and 2.8× the 400-line soft ceiling. It implements the full `AdminRepository` facade, which itself `implements` six segregated ports (`AdminOrdersPort`, `AdminCouponsPort`, `AdminCustomersPort`, `AdminReviewsPort`, `AdminSalesPort`, `AdminCatalogPort` — `admin_repository.dart:26-33`). The ports were extracted in `c7039f3` (P3), which correctly narrowed the *consumers* — but the *implementation* stayed monolithic, so the class still mixes order-queue reads, catalogue writes, coupon CRUD, customer keyset paging, review moderation, sales aggregation, and a 75-entry Unicode digit-block table (`:67-291`) in one scope. 164 of the 824 lines are dartdoc, so the code itself is ~660 lines.
**Impact:** The `admin` data layer is the single hardest file to navigate; a change to coupon logic and a change to phone-digit normalisation land in the same file and the same review. The digit-block table (`:64-291`) is generated data with a "do not edit by hand" marker — pure noise in a class about admin operations.
**Fix:** Three mechanical moves, no behaviour change: (1) extract `:18-291` (the search-pattern + digit-normalisation helpers) into `lib/features/admin/data/admin_search_pattern.dart` as a `final class AdminSearchPattern` with static members — it is already stateless and test-visible; (2) split the implementation along the existing port seams into `supabase_admin_orders_data_source.dart`, `…_catalog_data_source.dart`, `…_coupons_data_source.dart`, etc., each `implements` one port; (3) reduce `SupabaseAdminRepository` to a facade that holds the six data sources and delegates. The DI registration in `service_locator.dart` changes only at the construction site.

## MEDIUM — Colour and category vocabulary is still English-only in the shopper UI, and `Product.colorName` (the AUD-011 fix) is plumbed but never read

**Location:** `lib/features/storefront/presentation/widgets/filter_sheet.dart:121` (`label: Text(color)`), `:101` (`label: Text(c)`); `lib/features/storefront/presentation/cubit/catalog_state.dart:88-96` (`availableColors` derived from `Product.colors`); `lib/core/entities/product.dart:24` (`this.colors = const ['Emerald', 'Gold', 'Ivory']`)
**Issue:** The ARB is genuinely complete and bilingual — 548 keys in `l10n/app_en.arb`, 548 in `l10n/app_ar.arb`, **zero key divergence** (verified by set diff). But colour names and category names are *data*, not ARB keys, and they are rendered verbatim: the filter sheet's colour chips read `Text(color)` straight from the variant colour set, and the category chips read `Text(c)` from the DB category list. A per-row `products.color_name` column and a `Product.colorName` field exist (migration 062, `product_mapper.dart:138`) but nothing in `lib/` reads `colorName` — the grep returns only the declaration, the mapper, and the tests. So R3 was implemented as a *transport* fix: the field travels end-to-end and stops there.
**Impact:** An Arabic session sees localized chrome around English filter chips ("Emerald", "Gold", "Silk", "Cotton"). The UI_UX audit logged this as UX-031 (`docs/UI_UX_AUDIT.md:230`) and it is still live. R3's user-visible symptom therefore persists despite the residual register reading "Implemented".
**Fix:** Consume the field that already exists. In `CatalogState.availableColors`, prefer `p.colorName` and fall back to the variant set:
```dart
for (final p in allProducts) {
  final named = p.colorName;
  if (named != null && named.isNotEmpty) { colors.add(named); }
  else { colors.addAll(p.colors); }
}
```
Then map the resulting vocabulary through ARB in `filter_sheet.dart` (a `catalogColorLabel(l10n, raw)` helper mirroring `catalogSortLabel`, which already establishes this exact pattern at `catalog_sort_label.dart:11`). Categories need the same treatment or a documented "category names are proper nouns and stay untranslated" decision.

## MEDIUM — `catalogColorName` is dead code whose doc comment describes behaviour no code implements

**Location:** `lib/features/storefront/domain/entities/catalog_filters.dart:39-52`; re-exported at `lib/features/storefront/presentation/cubit/catalog_cubit.dart:21`
**Issue:** `catalogColorName(int color)` — a 9-entry ARGB→name map with an `'Other'` fallback — has **zero call sites** in `lib/` or `test/` (grep for `catalogColorName(` returns only the definition). It is nevertheless deliberately re-exported through the cubit barrel, so it reads as live public API. Its own doc comment instructs a strategy nobody follows: "DB-derived alternative: `products.color_name` (migration 062) … **prefer it when a row carries one**." No code prefers it (see finding M-03).
**Impact:** A contributor searching for "where do colour filter names come from" finds this function, believes it is the source, and is wrong. Dead API that advertises the correct-but-unimplemented design is worse than no API — it actively misdirects the fix for M-03.
**Fix:** Delete `catalogColorName` and remove the `catalogColorName` line from the `catalog_cubit.dart:17-22` re-export list (keep `CatalogFilters`, `CatalogSort`, `CatalogSortLabel`, `CatalogConstants`). If the ARGB tint fallback is genuinely still needed for seed/local rows, it belongs in `catalog_constants.dart` next to `curatedSwatches`, not in the domain layer — and it should be called from `availableColors`, not merely exported.

## MEDIUM — Two different classes named `CatalogConstants` live in the same feature

**Location:** `lib/features/storefront/domain/entities/catalog_filters.dart:26` (`unboundedMax`) and `lib/features/storefront/presentation/catalog_constants.dart:19` (`defaults`, `categoryAccents`, `curatedSwatches`, `swatchFor`, `deterministicTint`)
**Issue:** Both are `abstract final class CatalogConstants`, both in `features/storefront`, and both claim centrality in their doc comments — the domain one says "Centralized catalog constants for audit lint compliance" (`catalog_filters.dart:25`) while the presentation one says "Single source of truth for catalog fallback data" (`catalog_constants.dart:8`). No file imports both today, so the tree compiles — the collision is latent, not active. The domain copy is reachable through the `catalog_cubit.dart` barrel, so it is not even scoped away.
**Impact:** The first file that needs a price ceiling *and* a swatch colour (a plausible next change — e.g. a price-range filter that renders category accents) fails to resolve `CatalogConstants` and needs an import prefix or an alias. Two same-named classes with mutually exclusive "single source of truth" claims also guarantee the wrong one gets imported by autocomplete.
**Fix:** Rename the domain holder to match what it holds — `CatalogPriceBounds` — and update its three references (`catalog_filters.dart:29,67,84,120` and the `catalog_cubit.dart` re-export list). Alternatively fold `unboundedMax` into `presentation/catalog_constants.dart` and delete the domain declaration; the price ceiling is a presentation-filter concern, not a domain one.

## MEDIUM — The same admin navigation tile is implemented three times

**Location:** `lib/features/admin/presentation/pages/admin_dashboard_page.dart:174-198` (`_ActionTile`), `lib/features/admin/presentation/pages/admin_catalog_page.dart:103-126` (`_ManagementTile`), `lib/features/admin/presentation/widgets/order_detail_cards.dart:284-305` (`_ActionTile`, a variant)
**Issue:** `_ActionTile` (dashboard) and `_ManagementTile` (catalog) are the same widget under two names: identical field sets (`icon`, `title`, `subtitle`, `onTap`), identical body (`Card > ListTile` with `leading: Icon(icon)`, `trailing: Icon(context.directionalTrailingIcon)`). The `order_detail_cards.dart:284` copy drops `subtitle` and adds `color`, which is the same widget with two optional parameters. All three are `private`, so nothing can be reused — each new admin hub page re-grows a copy. The dashboard and the catalog hub already render the same destination set (Orders, Inventory, Catalog, Coupons on the dashboard; Products, Categories, Images, Variants, Reviews, Customers, Sales on the catalog hub) with two different tile classes.
**Impact:** A design change to the admin tile (spacing, tap target, a11y semantics, ripple) requires finding and editing three files, and nothing fails if one is missed.
**Fix:** Promote one public widget into `lib/shared/components/` (the directory already holds `app_card.dart`, `app_button.dart`) — `NavigationTile({required icon, required title, String? subtitle, Color? color, required onTap})` — and delete all three private copies. Replace `_ActionTile`/`_ManagementTile` usages at `admin_dashboard_page.dart:93-118` and `admin_catalog_page.dart:50-96`.

## MEDIUM — The invoice PDF is hardcoded English and now contradicts a convention the codebase explicitly retired

**Location:** `lib/features/admin/domain/invoice/invoice_pdf_builder.dart:74` (`'Al Batal Elite'`), `:79` (`'Premium Fabrics'`), `:83` (`'INVOICE'`), `:91-94` (`'Order:'`, `'Date:'`, `'Customer:'`), `:103` (headers `Item/Size/Color/Qty/Unit (EGP)/Line (EGP)`), `:119` (`'Total:'`)
**Issue:** Commit `56317cb` ("localize the admin console and retire the English-only convention") moved ~70 user-facing strings into the ARB and deleted the 31 in-code comments that had asserted the old "Admin-only, intentionally unlocalized" rule. It did not touch this file — `git show 56317cb --stat -- lib/features/admin/domain/invoice/` returns nothing, and the file's last change is `643d39a`. So the one admin surface that still ships English is the one that leaves the app: the invoice is generated at `admin_order_detail_page.dart:89` and handed to the OS share sheet, i.e. it reaches the customer. The surrounding admin chrome is Arabic while the document the customer receives is English. `RESIDUAL-R5`'s risk note — "customer-facing surfaces are fully localized" — no longer holds.
**Impact:** An Arabic-first customer receives a branded invoice whose labels are English. The convention that justified the omission is gone, so a contributor reading the file has no signal that English here is a decision rather than an oversight — the inverse of the previous state, where 22 comments documented the rule.
**Fix:** Thread the locale through the builder (`InvoicePdfBuilder.build(order, {required AppLocalizations l})` or an `InvoiceCopy` value object), add the ~10 invoice keys to both ARBs, and pass `context.l10n` from `admin_order_detail_page.dart:89`. Because the document build runs on a background isolate (`invoice_pdf_builder.dart:39`, `Isolate.run`), the copy must be resolved on the main isolate and passed in as a plain sendable object — `AppLocalizations` itself must not cross the isolate boundary. If the intent is genuinely to keep the invoice English, reinstate an explicit one-line rationale comment on the class, since the previous justification has been deleted.

## MEDIUM — Admin port method naming mixes three verbs and two prefixes inside one interface family

**Location:** `lib/features/admin/domain/repositories/admin_catalog_port.dart` (`getAllProducts`, `getProductById`, `getVariants`, `getProductImagePaths`, `getAllCategories`), `admin_orders_port.dart` (`getAllOrders`, `getOrderDetails`), `admin_sales_port.dart` (`getLowStockProducts`, `getSalesOverview`), `admin_reviews_port.dart:10` (`fetchPendingReviews`), `admin_customers_port.dart` (`fetchCustomers`), `admin_coupons_port.dart` (`fetchCoupons`)
**Issue:** Two inconsistencies in one cohesive interface set. (1) **Verb:** reads use `get*` in five ports and `fetch*` in three, for identical operations — `getLowStockProducts` and `fetchPendingReviews` are both "read a filtered list". The `admin_repository.dart` facade `implements` all six, so both spellings appear on the same object. (2) **Prefix:** three write methods carry a redundant `admin` prefix (`adminUpsertProduct`, `adminUpsertVariant`, `adminSetProductImages`) while their direct siblings do not (`createCoupon`, `updateStock`, `setCouponActive`, `setReviewStatus`, `setMembershipTier`). The prefix adds nothing: every method in the family is already admin-scoped by the port name.
**Impact:** Callers cannot predict a method name from the operation, so autocomplete is the only way to find one — the exact friction the P3 port split was meant to remove. `adminUpsertProduct` also reads as a verb-noun collision ("admin" is not the verb).
**Fix:** Standardise reads on `fetch*` (matches `fetchCustomers`/`fetchCoupons`, and the storefront repositories) and drop the `admin` prefix on writes:
```
getAllProducts → fetchProducts        adminUpsertProduct → upsertProduct
getProductById → fetchProductById     adminUpsertVariant → upsertVariant
getAllCategories → fetchCategories    adminSetProductImages → setProductImages
getVariants → fetchVariants
```
Rename across the port, `SupabaseAdminRepository`, the six cubits, and the tests in one mechanical pass; the analyzer finds every site.

## LOW — `lib/core/helper/` is an empty directory that the project structure documents as real

**Location:** `lib/core/helper/` (directory exists, zero files)
**Issue:** The directory is empty and untracked — `git ls-files lib/core/helper/` returns nothing, so git does not carry it. The audit brief itself lists `lib/core/{data,entities,error,helper,utils}` as the core shape, which means the documented structure and the actual structure disagree. A contributor told to "put it in core/helper" finds a directory that does not exist after a fresh clone.
**Impact:** Very low — an empty directory and a stale structure description. It costs a contributor one confused `ls`.
**Fix:** Either `rmdir lib/core/helper` and drop it from the structure documentation, or state in the docs what belongs there (helpers that are neither entities, errors, parsing utils, nor data codecs). Do not add a `.gitkeep` — an empty directory with a placeholder is the same ambiguity with extra steps.

## LOW — `CatalogSortLabel.label` is a dead getter kept for a consumer that does not exist

**Location:** `lib/features/storefront/domain/entities/catalog_filters.dart:16-22`
**Issue:** The extension getter returns five hardcoded English strings and has **zero call sites** (grep for `.label` across `lib/` matches only unrelated `label` fields on other classes). Its doc comment says it is an "English fallback for diagnostics only — never rendered", which is accurate, but a getter that is never read and never rendered is not a fallback — it is a second, silent copy of the sort vocabulary that will drift from `catalog_sort_label.dart:11` the moment a sort mode is added.
**Impact:** Low, but it is a live drift hazard: `CatalogSort` gains a value, `catalog_sort_label.dart` gets the new ARB key, and this switch fails to compile — a build break in dead code, discovered by whoever next touches the enum.
**Fix:** Delete the `CatalogSortLabel` extension and remove `CatalogSortLabel` from the `catalog_cubit.dart:17-22` re-export list. `catalogSortLabel(l10n, sort)` at `catalog_sort_label.dart:11` is the single mapping and is exhaustively switch-checked.

## LOW — Two `@Deprecated` top-level functions exist only to keep tests compiling

**Location:** `lib/features/storefront/presentation/widgets/color_swatches.dart:10-16` (`deterministicTint`, `swatchColorFor`)
**Issue:** Both are `@Deprecated('Use CatalogConstants.… instead.')` and both are called **only** from two test files (`color_swatches_test.dart:116-119`, `color_swatch_test.dart:6-27`). No production code uses them. They exist because the real implementations moved to `CatalogConstants` (`catalog_constants.dart:118`) and the tests were not updated.
**Impact:** Production `lib/` ships two functions whose only purpose is test compatibility — a small but real "test-shaped code in the app" smell, and the deprecation warnings they emit train readers to ignore deprecations.
**Fix:** Point the two test files at `CatalogConstants.deterministicTint` / `CatalogConstants.swatchFor` and delete `color_swatches.dart:10-16`. Keep only `ColorSwatchDot`, which is genuinely used (`filter_sheet.dart:119`, variant chips).

## LOW — Port and implementation share a basename in two store pairs

**Location:** `lib/features/storefront/domain/repositories/recent_searches_store.dart` vs `lib/features/storefront/data/recent_searches_store.dart`; `…/domain/repositories/recently_viewed_store.dart` vs `…/data/recently_viewed_store.dart`
**Issue:** In both pairs the domain port and the data implementation carry the identical filename. Today no single file imports both, so nothing breaks. The moment one does — e.g. a cubit that needs the interface for its constructor and the concrete type for a factory default — the two imports are indistinguishable by name in the import block, and Dart will report a conflicting-import error with no hint which file each refers to.
**Impact:** Low, latent. `import` lines become ambiguous to read even when they resolve, and the error message on collision names only the symbol.
**Fix:** Suffix the implementations the way the codebase already does elsewhere: `PrefsRecentSearchesStore` lives in `data/recent_searches_store.dart` while the port `RecentSearchesStore` lives in `domain/repositories/recent_searches_store.dart` — rename the data files to `prefs_recent_searches_store.dart` and `prefs_recently_viewed_store.dart` to match the class names inside them (`data/recent_searches_store.dart:11`, `PrefsRecentSearchesStore`).

## LOW — `features/addresses/domain/address.dart` is a one-line re-export shim used only by tests

**Location:** `lib/features/addresses/domain/address.dart:1-2` (`export '../../../core/entities/address.dart';`)
**Issue:** The file contains no code — it forwards to the canonical `core/entities/address.dart`. Its importers are **three test files only** (`test/features/addresses/data/address_repository_hardening_test.dart:6`, `test/features/auth/data/auth_snapshot_dip_test.dart:3`, `test/shared/services/secure_store_test.dart:8`); no `lib/` file imports it. It is a fourth path to one entity, and it sits at `domain/address.dart` rather than `domain/entities/address.dart`, which is where every other feature keeps its entities.
**Impact:** Low. A reader following an import chain takes an extra hop to reach the real declaration, and the address feature appears to own an entity it does not own.
**Fix:** Delete the shim, update the three test imports to `package:al_batal_elite/core/entities/address.dart`, and drop the stale `lib/features/addresses/domain/address.dart` path. (If it is kept, move it to `domain/entities/address.dart` so the feature shape matches `auth`, `admin`, `payments`, `storefront`, and `support`.)

## LOW — Feature module shape is not uniform

**Location:** `lib/features/addresses/domain/address.dart` (entity outside `domain/entities/`); `lib/features/support/presentation/` (no `cubit/`); `lib/features/admin/domain/invoice/` (a fourth `domain/` subfolder unique to admin); `lib/features/storefront/presentation/catalog_constants.dart` and `catalog_sort_label.dart` (loose files beside `cubit/`, `pages/`, `widgets/`)
**Issue:** Seven of the eight features use `domain/entities/`; `addresses` does not. Seven features put state in `presentation/cubit/`; `support` has none (its repository is injected straight into the page, which is defensible for static content but undocumented as a choice). `admin` is the only feature with a fourth domain subfolder. `storefront/presentation/` is the only presentation directory with loose top-level files.
**Impact:** Low — each deviation is individually reasonable, but there is no written rule, so "where does this file go?" is answered by looking at neighbours, and the answer differs per feature. Structural inconsistency is cheap to fix now and expensive after more features land.
**Fix:** Either conform (`addresses/domain/entities/address.dart`, move the two storefront helpers into `presentation/helpers/`) or write the rule down: one paragraph in the architecture doc stating which subfolders are mandatory, which are optional, and what earns a new subfolder. A documented exception is maintainable; an undocumented one is drift.

## LOW — 391 lines of on-device smoke-test scaffolding live in the production `lib/` tree

**Location:** `lib/shared/smoke/` — `smoke_harness.dart` (207), `admin_read_scenarios.dart` (71), `smoke_runner.dart` (64), `smoke_scenario.dart` (49); imported by `lib/app.dart:46` and `lib/bootstrap.dart:20`
**Issue:** A test harness — scenario runner, scenario definitions, a semantics-tree workaround for uiautomator-dead devices — is compiled into the shipped application. It is well-gated (mounted only when `AlBatalApp.exitApp` is non-null, set only by `lib/main_smoke.dart`, and it refuses to run under `kReleaseMode` — `smoke_harness.dart:27-35`) and the gating is documented thoroughly. But it still means `lib/` is not purely application code, and the harness's admin scenarios reach into `features/admin/presentation/cubit/admin_cubit.dart` (`smoke_harness.dart:9`), so the production tree carries a dependency on admin presentation internals that exists for no production reason.
**Impact:** Low. The gating is sound; the cost is tree size, a widened import graph, and the precedent that `lib/` may hold non-product code.
**Fix:** Move `lib/shared/smoke/` to `tool/smoke/` (or `test/smoke/`) and have `main_smoke.dart` import it by package path — the smoke build is already a distinct entry point with its own `--target`, so no application code needs to change. If it must stay, the class doc should state *why* it cannot live outside `lib/` (e.g. it needs `dart:io` `exit` and the real widget tree), so the next reader does not "clean it up" into a broken build.

---

## What's done well

- **Comment quality is exceptional and answers *why*, not *what*.** The census found **zero `TODO`/`FIXME`/`HACK`/`XXX`** in 29,769 lines, and the nine `// ignore:` directives all carry an inline justification (`catalog_cubit.dart:101,132,221` "discarded_futures" with the reason at the call site; `payment_cubit.dart:113` names where the subscription is cancelled). Comments explain failure modes and rejected alternatives — `admin_mappers.dart:9-14` states the "never bare `as` casts" rule and the consequence; `invoice_pdf_builder.dart:17-20` explains the Helvetica fallback by bundle size; `catalog_filters.dart:94-96` warns that the filter chips and the matcher must share a colour source "or offered chips can never match anything". This is the strongest single signal in the dimension.
- **Total-decode discipline is documented and mechanically consistent.** `lib/core/utils/safe_parse.dart` centralizes the never-throw accessors with a rationale per helper, and the layers above it honour the rule: `admin_mappers.dart` contains every cast, `profile.dart:52-58` documents precisely which column fails closed (`id` throws) versus degrades (everything else), and `address_codec.dart:26-29` states the same contract for addresses. The `56317cb`-era duplication of `_optInt` was genuinely removed — `admin_mappers.dart` now imports the core helpers and defines none of its own.
- **Test-to-source parity is close to 1:1 and the suite is real.** 177 `_test.dart` files, 29,636 test LOC against 29,769 source LOC. The suite guards behaviour, not just coverage: `product_mapper_test.dart:182-202` pins the `colorName` round-trip *and* the pre-062 cache-degradation case, and `56317cb` updated existing string pins rather than deleting them.
- **Dependency hygiene in `pubspec.yaml` is documented at the point of decision.** Every non-obvious pin carries an inline rationale with a date and an approval reference (`fl_chart: ^0.71.0` explains in four lines why 1.x is refused — it would raise the Dart SDK floor; `flutter_secure_storage` and `image_picker` cite the residual and PR; `connectivity_plus` and `internet_connection_checker_plus` distinguish "interface-type signal" from "real reachability probe"). The `intl 0.20.3` incompatibility is recorded as a comment rather than left as a mystery. `http` is correctly pinned to `^1.2.0`, confirming `RESIDUAL-R2` stays closed.
- **l10n is complete and structurally enforced, not aspirational.** The two ARBs are at exact parity (548 keys each, zero divergence by set diff), and the localization work created *single-mapping helpers* rather than scattering `switch` statements: `admin_order_status_label.dart:16` and `catalog_sort_label.dart:11` both exist specifically to prevent a second and third spelling of the same vocabulary, and both document why the mapping cannot live on the domain enum.

SCORE: 8.0/10 — The maintainability foundations remain strong: zero TODO debt, ~1:1 test parity, documented dependency rationales, complete bilingual ARB parity, and comment quality that consistently explains rationale rather than narrating code. The deduction is for a specific and fixable cluster rather than general decline: the most-referenced core types (`Result`/`Success`/`Failure`, `Product`, `Address`) carry no class documentation while coverage sits at 69.1%; one 824-line data class implements six ports; two same-named `CatalogConstants` classes coexist in one feature; the same admin tile is written three times; admin port naming mixes `get*`/`fetch*` and a redundant `admin` prefix; and the AUD-011 colour fix was plumbed end-to-end without a single consumer, so the shopper UI still shows English colour chips while `catalogColorName` — dead code whose doc comment describes the correct unimplemented design — actively misdirects the fix. R4 is confirmed closed, R5's console half is genuinely closed by `56317cb`, but the invoice PDF that leaves the app is still hardcoded English with the convention that justified it now deleted. Every finding above is mechanical to fix; none requires a schema, credential, or deployment decision.
