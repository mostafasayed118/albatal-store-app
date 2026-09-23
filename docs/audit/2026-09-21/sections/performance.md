# Al Batal Elite — Performance Audit (2026-09-21)

- **Tree audited:** `master` @ `ef91836` (269 files under `lib/`, ~36.9 kLOC)
- **Prior score:** Performance **9.0/10** (`docs/audit/2026-09-15/05-reaudit.md`, v2–v8)
- **Method:** static source review only. Every claim below is anchored to a file and line that
  was opened and read. No device profile run was performed in this pass — the prior audit's
  v8 device measurements (cold start 1.6–2.7 s, ~1041 frames / 0 compositor drops on the
  products grid) stand as the only empirical data and are not re-derived here.
- **Read-only:** no source file was modified. This report is the only file written.

## 0. Verification of the four claimed perf commits

All four landed where claimed. Verified by reading the post-commit source, not the commit message.

| Commit | Claim | Verified |
|---|---|---|
| `5d8ec0c` | width-bounded render URLs on every product surface | **Yes.** `ProductCodec.fromRow` now resolves `imageAsset` at `gridImageWidth` (420) and `images` at `detailImageWidth` (720) through `StorageService.getProductImageUrlForWidth` — `lib/features/storefront/data/product_mapper.dart:93-113,126-127`. Budgets are named constants (`storage_service.dart:78-82`) and the width helper allowlists `{180,420,720,1080}` (`storage_service.dart:126-139`). Consumers confirmed: grid card decodes 420 (`stitch_product_grid_card.dart:62-63`), flash-sale 180 (`stitch_flash_sale_card.dart:64-65`), hero takes the detail render and decodes 840×360 (`stitch_hero_carousel.dart:70-74,249-251`), gallery 720 (`image_gallery.dart:90`), zoom 1080 (`zoom_gallery.dart:58-61`), cart/wishlist/related thumbs 144/360/280 (`cart_item_tile.dart:75`, `wishlist_tile.dart:36`, `related_card.dart:36`), review photo 240 (`reviews_section.dart:181-182`). |
| `bb3f449` | one-year cache lifetime on product images on upload | **Yes.** `uploadProductImage` sends `cacheControl: productImageCacheSeconds` = `'31536000'` (`storage_service.dart:58,114`). The digits-only shape constraint is documented and pinned by test. Avatars deliberately keep the SDK default (`storage_service.dart:204-207`) — correct, since the avatar path is fixed per user. |
| `4d8ecac` | image-manager previews bounded at the grid budget | **Yes.** `admin_image_manager_page.dart:319-343` requests the 420 render URL *and* passes `cacheWidth/cacheHeight: 420`, so the last full-upload surface is closed at both ends. |
| `bed0d1c` | threshold-gated cache compute | **Yes, and correctly scoped** — see §3. |

## 1. Findings

## MEDIUM — Every mounted `AppImage` takes an unconditional `MediaQuery` dependency, so the product grid rebuilds on each frame of the IME/view-inset animation
**Location:** `lib/shared/components/app_image.dart:57`
**Issue:** `build` reads `MediaQuery.maybeOf(context)?.devicePixelRatio` before checking whether the caller already supplied `cacheWidth`/`cacheHeight`:
```dart
final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
int? defaultFor(double? extent) =>
    extent == null ? null : (extent * dpr).round().clamp(1, 1080);
...
memCacheWidth: cacheWidth ?? defaultFor(width),
```
`MediaQuery.maybeOf` registers a dependency, so every `AppImage` rebuilds whenever *any* `MediaQueryData` field changes. On Android the IME inset is animated, so `viewInsets` takes a new value on each animation frame. The catalog page keeps the grid mounted below its search field (`catalog_page.dart:143-215`), so tapping search fans a per-frame rebuild out to every built grid card — even though the card path always passes an explicit `cacheWidth: 420` (`stitch_product_grid_card.dart:62-63`) and therefore never needs `dpr` at all.
**Impact:** measurable, per-frame, avoidable rebuild fan-out across the app's most-instantiated widget during IME open/close and rotation. Cost is widget rebuild only (the `CachedNetworkImage` state memoizes its provider, so no re-fetch and no re-decode) — which is why this is MEDIUM and not HIGH.
**Fix:** only touch `MediaQuery` when a default is actually needed:
```dart
final needsDefault = cacheWidth == null || cacheHeight == null;
final dpr = needsDefault
    ? (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0)
    : 1.0;
```
Callers that pass explicit budgets then carry no `MediaQuery` dependency at all.

## MEDIUM — the grid render (420) and the detail render (720) of the *same* photo are two distinct `CachedNetworkImage` cache keys, so the first image of every product is fetched, stored and decoded twice
**Location:** `lib/features/storefront/data/product_mapper.dart:93-113` + `lib/shared/services/storage_service.dart:126-139`
**Issue:** `fromRow` mints two different URL *strings* for one photo — the primary at `?width=420&quality=70&resize=contain` into `imageAsset`, and the same object at `?width=720&quality=70&resize=contain` as `images.first`. `CachedNetworkImageProvider`/`flutter_cache_manager` key both the in-memory `ImageCache` and the on-disk cache by URL, so these are two entries for one object. The mapper's own comment acknowledges the split ("the two budgets make one photo two different strings") and works around it only for gallery de-duplication, by comparing everything before the `?` (`image_gallery.dart:41-44`) — the network and memory caches still see two.
**Impact:** one redundant network fetch, one redundant disk entry and one redundant decoded bitmap per product the user opens from the grid. Memory arithmetic against Flutter's default `ImageCache` cap (100 MiB): a full pass over a 100-product grid leaves ≈67 MiB of grid bitmaps resident (100 × 420 × 420 × 4 B ≈ 0.67 MiB each), and each product subsequently opened at detail budget adds ≈2.0 MiB (720 × 720 × 4 B) for a photo already resident — so the cache reaches its cap after roughly 15 detail views rather than ~50. Eviction then re-decodes from disk (no re-download), so this is wasted bandwidth and memory pressure, not user-visible jank.
**Fix:** emit one canonical URL per photo and let each surface bound its own decode. In `product_mapper.dart`, resolve *both* `imageAsset` and `images` at `StorageService.detailImageWidth`; the grid card already caps its decode at 420 via `memCacheWidth` (`app_image.dart:65`), so the only change is a slightly larger grid payload (a 420 vs 720 render of the same JPEG) in exchange for one cache key per photo. Alternatively keep both budgets and pin a single width per object at the call sites — but do not leave two URLs for one object in the mapper.

## LOW — `PricingTierTable.build` copies and re-sorts a two-element `const` ladder on every build
**Location:** `lib/features/storefront/presentation/widgets/pricing_tier_table.dart:28-29`
**Issue:** `final tiers = [...kWholesaleTiers]..sort(...)` allocates a new list and runs a sort on every build, although `kWholesaleTiers` is a compile-time `const` with a fixed two-entry order (`cut_length_pricing.dart:21-24`) and the sort result can never change.
**Impact:** trivial per build (2 elements), but it is an allocation + sort on a widget that rebuilds with the details page and its variant/quantity selectors. Polish.
**Fix:** hoist once — `static final _tiersAscending = [...kWholesaleTiers]..sort(...)` — or declare the const ladder already ascending (25 before 10 is what forces the sort).

## LOW — `DateFormat` is constructed per row, per build, in four list surfaces
**Location:** `lib/features/storefront/presentation/widgets/reviews_section.dart:149`, `lib/features/storefront/presentation/widgets/order_card.dart:151`, `lib/features/storefront/presentation/widgets/order_status_timeline.dart:143`, `lib/features/admin/presentation/widgets/order_detail_cards.dart:69`
**Issue:** each call site does `DateFormat('<pattern>', locale).format(value)` inside `build`. `DateFormat` construction resolves locale data and parses the pattern; it is the documented reason `intl` ships a formatter cache, and none of these four use it.
**Impact:** one construction per row per rebuild — with 10 inline reviews (`reviews_section.dart:97`) that is 10 constructions per reviews rebuild. Bounded and small; polish.
**Fix:** memoize per (locale, pattern), e.g. a file-level
`final _fmtCache = <String, DateFormat>{};` with
`DateFormat _fmt(String pattern, String locale) => _fmtCache.putIfAbsent('$pattern|$locale', () => DateFormat(pattern, locale));`

## LOW — `CatalogFilters.matches` recomputes `query.trim().toLowerCase()` once per product, per filter pass
**Location:** `lib/features/storefront/domain/entities/catalog_filters.dart:88`
**Issue:** the normalized query is derived inside the per-product predicate, so a filter pass over the 100-row page performs 100 redundant `trim()` + `toLowerCase()` allocations of the same string.
**Impact:** ~100 short-string allocations per pass; sub-millisecond at `kCatalogPageSize = 100` (`supabase_catalog_repository.dart:68`). Bounded by the repository page ceiling, so it cannot grow with the table.
**Fix:** normalize once in the caller and pass it down — e.g. add `bool matchesNormalized(Product p, String normalizedQuery)` and have `CatalogState.visible` (`catalog_state.dart:172`) compute `current.query.trim().toLowerCase()` a single time before the `where`.

## LOW — `AddressesPage` builds a user-growable list with `ListView(children: …)` instead of a builder
**Location:** `lib/features/addresses/presentation/pages/addresses_page.dart:45-71`
**Issue:** `ListView(children: s.addresses.map((a) => Card(...)).toList())` materializes every saved address (plus its `PopupMenuButton` and three menu items) on every build. This is the only remaining non-builder `ListView` in `lib/` whose child count is genuinely dynamic — the other 19 sites are bounded static content (form fields, policy text, ≤4 cards, empty states), which the prior audit accepted and this pass re-confirms (`admin_catalog_page.dart:47-98`, `settings_page.dart:41`, `admin_reviews_page.dart:61` — the last is the *empty* branch; the populated branch is `ListView.separated` at line 67).
**Impact:** small in practice (a customer rarely keeps more than a handful of addresses) but unbounded by construction. LOW.
**Fix:** `ListView.builder(itemCount: s.addresses.length, itemBuilder: (_, i) { final a = s.addresses[i]; return Card(...); })`.

## LOW — `WishlistPage` schedules `resolveProducts` from inside `build`, and its `BlocBuilder` has no `buildWhen`
**Location:** `lib/features/storefront/presentation/pages/wishlist_page.dart:64-71`
**Issue:** the builder body calls `WidgetsBinding.instance.addPostFrameCallback` to trigger a cubit mutation — a side effect in a build path — and the `BlocBuilder<WishlistCubit, WishlistState>` has no `buildWhen`, so every wishlist emit (including `toggleBackInStockAlert`'s `alertIds` mirror, `wishlist_cubit.dart:139`) rebuilds the whole grid.
**Impact:** no infinite loop — `WishlistState` is `Equatable` over `ids`/`products`, and `resolveProducts` emits an equal state when nothing resolves, which Cubit drops (`wishlist_cubit.dart:111-124`). Verified as bounded. The residual cost is that a back-in-stock toggle rebuilds every visible tile, and the resolve trigger is re-armed on each build rather than once.
**Fix:** move the resolve to a `BlocListener` on `ids`, and gate the grid on
`buildWhen: (a, b) => !identical(a.products, b.products) || a.ids.length != b.ids.length`.

## LOW — `AdminOrdersPage`'s list builder has no `buildWhen`, although the sibling action builder in the same `AppBar` does
**Location:** `lib/features/admin/presentation/pages/admin_orders_page.dart:94` (contrast `:59-61`)
**Issue:** the export button correctly gates on `prev.filteredOrders.isEmpty != next.filteredOrders.isEmpty`, but the body `BlocBuilder<AdminCubit, AdminState>` rebuilds on *any* `AdminState` emit. `AdminCubit` is app-scoped and shared across the admin routes (`app.dart:225`), and it emits on low-stock loads (`admin_cubit.dart:197-200`), order-detail loads (`:140-143`) and membership-tier writes (`:237-239`) — none of which change the queue.
**Impact:** extra full-page rebuilds of a ≤50-row `ListView.builder`; cheap and lazy, so not felt. LOW.
**Fix:** `buildWhen: (a, b) => a.status != b.status || a.statusFilter != b.statusFilter || !identical(a.orders, b.orders)`.

## LOW — `AdminState.filteredOrders` is recomputed on every access, four times per build
**Location:** `lib/features/admin/presentation/cubit/admin_cubit.dart:38-42`; read at `admin_orders_page.dart:40,61,64,110`
**Issue:** the getter runs `orders.where(...).toList()` each time it is touched, with no memo — unlike `OrdersState.active/completed/cancelled` (`orders_cubit.dart:37-79`) and `CatalogState.visible` (`catalog_state.dart:169-189`), which both memoize on the state instance.
**Impact:** 4 × O(n) over a queue bounded at `limit = 50` (`supabase_admin_repository.dart:355`). Micro. LOW.
**Fix:** adopt the established `_CatalogMemos` / `_OrdersMemos` pattern: a private `List<AdminOrder>? _filtered` + `AdminOrderStatus? _filteredKey` on the state, invalidated when `orders` or `statusFilter` changes.

## LOW — `ProductImageResolver`'s local-asset branch decodes at full resolution
**Location:** `lib/features/storefront/presentation/widgets/product_image_resolver.dart:84-89`
**Issue:** `Image.asset(url, fit: …, gaplessPlayback: …)` receives no `cacheWidth`/`cacheHeight`, so the asset branch is the one image path in the app with no decode bound — every other path passes an explicit budget (`app_image.dart:65-66`, `zoom_gallery.dart:58-61`).
**Impact:** effectively zero today: since `5d8ec0c` a network row's `imageAsset` is a `https://` render URL, so the asset branch is reachable only for local seed rows, and `AppImage`'s own contract requires local runtime assets to be SVG (`app_image.dart:77-83`) which `Image.asset` cannot render anyway. Reported for completeness, not as a felt bottleneck.
**Fix:** pass `cacheWidth: cacheWidth, cacheHeight: cacheWidth` to `Image.asset` so the branch cannot regress if an asset-backed product ever ships.

## LOW — `AdminCustomersPage`'s outer `BlocBuilder` has no `buildWhen`, so `isLoadingMore` toggles rebuild the directory and the search field
**Location:** `lib/features/admin/presentation/pages/admin_customers_page.dart:112-113`
**Issue:** every `AdminCustomersState` emit rebuilds the `Scaffold` containing the `TextField` and the paged `ListView.separated`. `isLoadingMore` flips twice per page load (`admin_customers_cubit.dart:181,197-202`).
**Impact:** the search field is controller-driven (`:140`) so focus/text survive; the rebuilds are lazy and cheap. LOW.
**Fix:** `buildWhen` on `status`, `customers` identity, `total`, `hasMore` — excluding `isLoadingMore`, or isolating the footer in its own `BlocSelector`.

## 2. Verified non-findings (explicitly checked, nothing to report)

Recording these so the absence of a finding is distinguishable from a missed one.

- **Admin phone search is not O(n²).** `customerPhoneDigitPattern` → `_asciiDigits` is O(term × digit-blocks) with a fixed ~60-entry `_digitBlockBases` table (`supabase_admin_repository.dart:145-162,193-199`) — bounded by the term length an admin can type, not by the table. The search itself is **server-side**, debounced 300 ms, keyset-paged and `count(exact)` in one round trip (`admin_customers_cubit.dart:167-174,216-249`; `supabase_admin_repository.dart:702-768`). There is no client-side filtered copy to drift or to scan (`admin_customers_cubit.dart:27-31`).
- **No N+1 queries.** A scan of every `_client.from` / `_client.rpc` site for a query inside a loop found none. Relations are fetched with embedded selects (`_productSelect`, `supabase_catalog_repository.dart:79-85`) or a single RPC (`get_order_details`, `supabase_admin_repository.dart:374-377`).
- **No `select('*')`.** The only occurrence is inside a doc comment explaining its removal (`supabase_admin_repository.dart:338`). The orders queue selects an explicit column list and deliberately excludes the heavy `address_snapshot` JSONB (`:341-343`).
- **No `jsonDecode`/`jsonEncode` in any presentation layer**, and **no `getIt<…>` lookup in any view** — both sweeps return zero hits, so no per-frame decode and no service-locator work in `build`.
- **No `SharedPreferences` read in a build path.** Every read is in a data-layer store/repository, and `SharedPreferences` serves from an in-memory map after the one `getInstance()` at startup (`service_locator.dart:76`).
- **The local order-snapshot decode is dead in production**, so it is not the un-gated counterpart to the catalog cache: `LocalStorefrontPersistence.readOrders()` (`storefront_persistence.dart:134-153`) has **no production caller** — `OrdersCubit` reads `SupabaseOrdersRepository.readOrders()` (`orders_cubit.dart:114`) — and there is no writer for `_ordersKey` anywhere in `lib/`. Only `readCart`/`readWishlist` are live, and both are small (≤10 cart lines; a list of ids), so their inline `jsonDecode` is correctly *not* isolate-gated.
- **No unbounded list endpoints.** `fetchProducts` `.limit(100)`, `getAllOrders` `.limit(50)`, `fetchPendingReviews` `.limit(100)`, `fetchCustomers` `.limit(pageSize + 1).count(exact)` with a keyset cursor, `readOrders` `.limit(50)`.
- **Counts are server-side** (`CountOption.exact`, `supabase_admin_repository.dart:733`), not computed client-side over a fetched page.
- **Sorting is memoized where it matters.** `CatalogState.visible` (`catalog_state.dart:169-189`), `OrdersState.active/completed/cancelled` (`orders_cubit.dart:37-79`), `featuredProducts`/`availableColors`/`categoryProductCount` (`catalog_state.dart:88-159`) and `findProductById`'s id map (`:197-204`) all cache per state instance and carry their memos across data-preserving `copyWith` (`:231-234`). The only per-build sort found is the 2-element `PricingTierTable` case above.
- **Heavy work is off the UI isolate or off the frame.** Invoice PDF builds on a background isolate via `Isolate.run` (`invoice_pdf_builder.dart:39`); image compression is a platform channel (`admin_image_manager_page.dart:155`); the catalog cache encode/decode is threshold-gated (§3); CSV export is synchronous but bounded to the ≤50-row filtered queue (`orders_csv_exporter.dart:8-24`, `admin_orders_page.dart:40-46`).
- **Startup path is minimal.** Before the first frame: `WidgetsFlutterBinding.ensureInitialized`, `SentryFlutter.init` (skipped when no DSN, `bootstrap.dart:47-51`), `SupabaseConfig.initialize`, `configureDependencies` (one `SharedPreferences.getInstance()`; all 40+ registrations are lazy singletons). OneSignal/notifications/connectivity are `unawaited` (`bootstrap.dart:106-111`), and all cubit restores/loads are async (`app.dart:74-105,225`).
- **Build granularity is good.** 13 `buildWhen` predicates cover the outer builders of the highest-traffic pages — home, catalog, cart, details (×4), checkout, admin orders/detail/sales-dashboard, and the app-level settings builder (`app.dart:229`). The per-card wishlist heart is isolated with a per-item `BlocSelector` (`home_page.dart:295-299`, `catalog_page.dart:194-198`), and the 1 Hz flash countdown flows on a dedicated stream that never emits state (`catalog_cubit.dart:52-62`).

## 3. The `bed0d1c` threshold gate — what it gates, and whether it is correct

`supabase_catalog_repository.dart:333-390`.

- **Encode** (`_persistCache`) is gated on **item count** `> _isolateItemBudget` (40) — `:359`. Item count is used deliberately because the encoded string length is unknown before encoding.
- **Decode** (`_restorePersistentCache`) is gated on **string length** `> _isolateJsonChars` (64 KiB) — `:380`. Length is used because the string is already in hand.
- **Correctness:** sound. `jsonEncode`/`jsonDecode` are top-level functions, so they are legal `compute` callbacks, and `List<Map<String, dynamic>>` of primitives crosses the isolate boundary via the standard send port. The gate direction is right for both: a small cache parses inline (avoiding isolate spawn latency on the offline cold-start path, where `_restorePersistentCache` is awaited *before* first paint — `:166,226,284`) while a large page moves off the UI thread. `_persistCache` is reached via `unawaited` (`:160`), so the extra isolate hop never blocks the load path.
- **Residual:** the two thresholds are not derived from each other, so a payload can be inline-encoded and isolate-decoded (or vice versa) — harmless, just an asymmetry worth a comment. The 40-item encode gate is on the conservative side (a 41-row page may encode faster inline than an isolate round trip costs); the doc comment at `:340-347` already states this trade-off, so it is a tuning question, not a defect.

## What's done well

- **The P0-4 image pipeline is complete and consistent.** Every product surface now requests a width-bounded render *and* bounds its own decode, at budgets that live as named constants on `StorageService` (`storage_service.dart:78-82`) rather than literals at call sites — grid 420, flash-sale 180, hero 840, gallery 720, zoom 1080, thumbs 144/280/360, review photo 240. Uploaded objects get a one-year `Cache-Control` (`:58,114`), justified by the UUID-per-upload path contract that makes a URL immutable by construction.
- **`CatalogState` is a textbook memoized derived-view container.** Every O(n) view (`visible`, `availableColors`, `catalogPriceMin/Max`, `categoryProductCount`, `featuredProducts`, `productsInCategory`, `findProductById`) computes once per state and the memos are carried across data-preserving `copyWith` (`catalog_state.dart:76-236`) — so grid/list builders can call them on every frame for free.
- **`bed0d1c`'s isolate gate is correctly scoped and correctly argued.** Encode gates on item count, decode on string length, both with the reasoning documented inline, and the small-payload inline path is preserved precisely because it sits on the offline cold-start route.
- **The flash-sale countdown was moved out of state entirely.** 1 Hz ticks travel on a broadcast stream (`catalog_cubit.dart:52-62`) and are consumed by a `StreamBuilder` scoped to one card (`home_page.dart:364`), so a per-second timer can never cause state inequality, a page rebuild, or a memo-cache invalidation anywhere.
- **Admin paging is keyset, not offset, with a server-side count and a live search.** `fetchCustomers` takes one bounded page plus an exact `count` in a single round trip, ordered on `(created_at DESC, id DESC)` with `id` as a tiebreaker (`supabase_admin_repository.dart:702-768`), and the search is debounced and server-side so it reaches customers on pages never loaded. This closed the previous silent `.limit(500)` truncation without moving the scan to the client.

SCORE: 9.2/10 — every claim in the four landed perf commits is verified in the post-commit source, and the residual list is two MEDIUMs (an avoidable per-frame `MediaQuery` dependency in `AppImage`, and one photo cached twice because the mapper mints two URLs for one object) plus nine LOW-grade polish items, with no HIGH or CRITICAL and no un-memoized or unbounded hot path found. The score moves off the prior 9.0 because the P0-4 and P6 work genuinely removed a class of defect and was verified rather than taken on trust; it does not go higher because this pass is static-only and the two MEDIUMs are real, unmeasured-on-device waste that a device profile would be needed to size.
