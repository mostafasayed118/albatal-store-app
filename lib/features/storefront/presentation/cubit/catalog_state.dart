import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/flash_sale.dart';

/// Catalog UI state, split out of `catalog_cubit.dart` (audit P5): the
/// state — with its memoization contract — is one concern, the cubit's
/// timers/repository calls are another.

enum CatalogStatus { initial, loading, ready, error }

/// Immutable catalog UI state with memoized derived views.
///
/// MEMOIZATION CONTRACT: [allProducts] is treated as immutable after
/// construction (the cubit always assigns a freshly built list), so the
/// O(n) derived getters ([visible], [availableColors],
/// [categoryProductCount], price bounds, [productsInCategory]) compute
/// once per state instance and reuse their result afterwards — grid and
/// list builders call them on every frame. Memo fields are deliberately
/// NOT part of [props]; equal states always derive equal views.
///
/// This is why the constructor is no longer `const`: memoization needs
/// per-instance lazy fields, and Equatable equality still works because
/// those fields are never compared.
///
/// COUNTDOWN CONTRACT (audit P3): the flash-sale countdown does NOT live
/// in this state. 1Hz ticks never emit a [CatalogState] — they flow
/// through [CatalogCubit.flashCountdown] — so countdown activity can
/// never cause state inequality or rebuilds anywhere.
final class CatalogState extends Equatable {
  CatalogState({
    this.status = CatalogStatus.initial,
    this.allProducts = const [],
    this.categories = const [],
    this.filters = const CatalogFilters(),
    this.carouselIndex = 0,
    this.recentQueries = const [],
    this.flashSales = const [],
    this.isOffline = false,
    this.isTruncated = false,
  });

  final CatalogStatus status;
  final List<Product> allProducts;
  final List<String> categories;
  final CatalogFilters filters;
  final int carouselIndex;
  final List<String> recentQueries;

  /// Snapshot of the connectivity gate at load time (Task #8 offline
  /// catalog). When true the rendered data (on success) came from the
  /// persistent cache, and a [CatalogStatus.error] means "offline with a
  /// cold cache" — pages render a friendly offline notice instead of the
  /// generic error view. The error FeedbackView is reserved for real
  /// (online) failures.
  final bool isOffline;

  /// True when the loaded page hit the repository bound (`kCatalogPageSize`):
  /// client-side search/filter/sort operate over this page only, so the UI
  /// shows a "showing first 100 — refine search" hint instead of silently
  /// omitting products. Set by the cubit from
  /// [CatalogRepository.lastPageTruncated].
  final bool isTruncated;

  /// Active flash sales (T1) — typed domain entities mapped from the
  /// repository; schema knowledge lives in `FlashSaleCodec.fromRow`.
  final List<FlashSale> flashSales;

  /// Discount label for the first active flash sale (the one the
  /// storefront renders), or the legacy `'-15%'` placeholder when no
  /// sale is active. Derived here — not in `HomePage.build` — so the
  /// fallback lives beside [flashSales] and the page only reads state.
  String get discountLabel => flashSales.isEmpty
      ? '-${FlashSale.defaultDiscountPct}%'
      : '-${flashSales.first.discountPct}%';

  bool get hasActiveFilters => filters.hasActiveFilters;

  /// Lazy storage for the derived views. Held in one final container so
  /// [CatalogState] keeps every field final (the class stays @immutable
  /// clean) while individual views fill in on first use.
  final _CatalogMemos _m = _CatalogMemos();

  // ─── Memoized derived views ────────────────────────────────
  // Plain lazy fields + explicit null checks: no clever idioms, the
  // pattern is identical for every getter below.

  /// Fabric color names across the catalog (drives the filter sheet).
  ///
  /// Prefers the curated [Product.colorName] when a row carries one
  /// (AUD-011 was plumbed end-to-end but never consumed — audit 2026-09-21
  /// M-03) and falls back to the variant [Product.colors] set — the
  /// server's per-variant names — not the placeholder [Product.imageColor]
  /// tint, which is a single grey fallback on network-loaded rows and
  /// collapsed every product to one bucket.
  List<String> get availableColors {
    var cached = _m.availableColors;
    if (cached == null) {
      final colors = <String>{};
      for (final p in allProducts) {
        final named = p.colorName;
        if (named != null && named.isNotEmpty) {
          colors.add(named);
        } else {
          colors.addAll(p.colors);
        }
      }
      cached = colors.toList()..sort();
      _m.availableColors = cached;
    }
    return cached;
  }

  Money get catalogPriceMin {
    var cached = _m.priceMin;
    if (cached == null) {
      cached = allProducts.isEmpty
          ? Money.zero
          : allProducts.map((p) => p.price).reduce((a, b) => a < b ? a : b);
      _m.priceMin = cached;
    }
    return cached;
  }

  Money get catalogPriceMax {
    var cached = _m.priceMax;
    if (cached == null) {
      cached = allProducts.isEmpty
          ? CatalogPriceBounds.unboundedMax
          : allProducts.map((p) => p.price).reduce((a, b) => a > b ? a : b);
      _m.priceMax = cached;
    }
    return cached;
  }

  List<Product> productsInCategory(String category) =>
      _m.byCategory.putIfAbsent(
        category,
        () => allProducts.where((p) => p.category == category).toList(),
      );

  /// Hero-carousel picks: discounted products first (a deal is the
  /// strongest hero story — mirroring the mockup's "20% Off" slide),
  /// then best-rated, capped at three so a fourth dot never appears.
  /// Memoized like the other O(n) derived views; empty catalog → empty
  /// list, so a hero fed solely from this shows nothing (Home falls back
  /// to the evergreen promo slide).
  List<Product> get featuredProducts {
    var cached = _m.featured;
    if (cached == null) {
      final discounted = allProducts.where((p) => p.oldPrice != null).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      final rest = allProducts.where((p) => p.oldPrice == null).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      cached = [...discounted, ...rest].take(3).toList();
      _m.featured = cached;
    }
    return cached;
  }

  Map<String, int> get categoryProductCount {
    var cached = _m.categoryCount;
    if (cached == null) {
      final map = <String, int>{};
      for (final p in allProducts) {
        map[p.category] = (map[p.category] ?? 0) + 1;
      }
      cached = map;
      _m.categoryCount = cached;
    }
    return cached;
  }

  /// Filtered + sorted product list. Memoized per [CatalogFilters] value —
  /// the filters object is immutable with value equality, so a changed
  /// filter key invalidates the cache and identical filters reuse it.
  ///
  /// Bounded by the repository page ceiling (audit P4): the client only
  /// ever holds one page (`kCatalogPageSize`, 100 rows), so the linear
  /// filter and the O(n log n) sort above run over at most 100 products —
  /// searching or re-sorting can never walk an unbounded table.
  List<Product> get visible {
    final current = filters;
    if (_m.visible == null || _m.visibleKey != current) {
      final filtered = allProducts.where(current.matches).toList();
      switch (current.sort) {
        case CatalogSort.featured:
          break;
        case CatalogSort.priceLowToHigh:
          filtered.sort((a, b) => a.price.compareTo(b.price));
        case CatalogSort.priceHighToLow:
          filtered.sort((a, b) => b.price.compareTo(a.price));
        case CatalogSort.name:
          filtered.sort((a, b) => a.name.compareTo(b.name));
        case CatalogSort.newest:
          filtered.sort((a, b) => b.id.compareTo(a.id));
      }
      _m.visible = filtered;
      _m.visibleKey = current;
    }
    return _m.visible!;
  }

  /// O(1) product lookup over [allProducts] by id.
  ///
  /// Backed by a memoized id→product map (built once per state instance,
  /// carried over by [copyWith] when the product list is unchanged), so
  /// flash-sale hero resolution and similar id lookups never pay a linear
  /// scan. Duplicate ids resolve last-wins, matching the repository index.
  Product? findProductById(String id) {
    var cached = _m.byId;
    if (cached == null) {
      cached = {for (final p in allProducts) p.id: p};
      _m.byId = cached;
    }
    return cached[id];
  }

  CatalogState copyWith({
    CatalogStatus? status,
    List<Product>? allProducts,
    List<String>? categories,
    CatalogFilters? filters,
    int? carouselIndex,
    List<String>? recentQueries,
    List<FlashSale>? flashSales,
    bool? isOffline,
    bool? isTruncated,
  }) {
    final resolvedProducts = allProducts ?? this.allProducts;
    final resolvedFilters = filters ?? this.filters;
    final next = CatalogState(
      status: status ?? this.status,
      allProducts: resolvedProducts,
      categories: categories ?? this.categories,
      filters: resolvedFilters,
      carouselIndex: carouselIndex ?? this.carouselIndex,
      recentQueries: recentQueries ?? this.recentQueries,
      flashSales: flashSales ?? this.flashSales,
      isOffline: isOffline ?? this.isOffline,
      isTruncated: isTruncated ?? this.isTruncated,
    );
    // Data-only emits (e.g. a refreshed sales list over the same catalog)
    // leave the underlying products/filters untouched — carry the
    // memoized views over instead of paying O(n log n) recompute.
    if (identical(resolvedProducts, this.allProducts) &&
        resolvedFilters == this.filters) {
      next._m.adopt(_m);
    }
    return next;
  }

  @override
  List<Object?> get props => [
        status,
        allProducts,
        categories,
        filters,
        carouselIndex,
        recentQueries,
        flashSales,
        isOffline,
        isTruncated,
      ];
}

/// Per-state lazy storage for [CatalogState]'s derived views. Mutable by
/// design but never compared in equality — see [CatalogState] docs.
class _CatalogMemos {
  List<String>? availableColors;
  Money? priceMin;
  Money? priceMax;
  Map<String, int>? categoryCount;
  List<Product>? visible;
  CatalogFilters? visibleKey;
  List<Product>? featured;
  Map<String, Product>? byId;
  final Map<String, List<Product>> byCategory = {};

  /// Carries memoized views to a state built over identical data (see
  /// [CatalogState.copyWith]). Entries stay valid because the products
  /// and filters they were derived from have not changed.
  void adopt(_CatalogMemos other) {
    availableColors = other.availableColors;
    priceMin = other.priceMin;
    priceMax = other.priceMax;
    categoryCount = other.categoryCount;
    visible = other.visible;
    visibleKey = other.visibleKey;
    featured = other.featured;
    byId = other.byId;
    byCategory.addAll(other.byCategory);
  }
}
