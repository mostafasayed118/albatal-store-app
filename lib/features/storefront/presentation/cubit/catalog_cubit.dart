import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../domain/entities/catalog_filters.dart';
import '../../domain/entities/flash_sale.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'flash_sale_ticker.dart';

export '../../domain/entities/catalog_filters.dart'
    show
        CatalogFilters,
        CatalogSort,
        CatalogSortLabel,
        CatalogConstants,
        catalogColorName;

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
final class CatalogState extends Equatable {
  CatalogState({
    this.status = CatalogStatus.initial,
    this.allProducts = const [],
    this.categories = const [],
    this.filters = const CatalogFilters(),
    this.carouselIndex = 0,
    this.recentQueries = const [],
    this.flashEnd,
    this.flashRemaining,
    this.flashSales = const [],
  });

  final CatalogStatus status;
  final List<Product> allProducts;
  final List<String> categories;
  final CatalogFilters filters;
  final int carouselIndex;
  final List<String> recentQueries;
  final DateTime? flashEnd;
  final Duration? flashRemaining;

  /// Active flash sales (T1) — typed domain entities mapped from the
  /// repository; schema knowledge lives in `FlashSaleCodec.fromRow`.
  final List<FlashSale> flashSales;

  bool get hasActiveFilters => filters.hasActiveFilters;

  /// Lazy storage for the derived views. Held in one final container so
  /// [CatalogState] keeps every field final (the class stays @immutable
  /// clean) while individual views fill in on first use.
  final _CatalogMemos _m = _CatalogMemos();

  // ─── Memoized derived views ────────────────────────────────
  // Plain lazy fields + explicit null checks: no clever idioms, the
  // pattern is identical for every getter below.

  List<String> get availableColors {
    var cached = _m.availableColors;
    if (cached == null) {
      final colors = <String>{};
      for (final p in allProducts) {
        colors.add(catalogColorName(p.imageColor));
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
          ? CatalogConstants.unboundedMax
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

  CatalogState copyWith({
    CatalogStatus? status,
    List<Product>? allProducts,
    List<String>? categories,
    CatalogFilters? filters,
    int? carouselIndex,
    List<String>? recentQueries,
    DateTime? flashEnd,
    Duration? flashRemaining,
    List<FlashSale>? flashSales,
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
      flashEnd: flashEnd ?? this.flashEnd,
      flashRemaining: flashRemaining ?? this.flashRemaining,
      flashSales: flashSales ?? this.flashSales,
    );
    // Countdown-only emits (flashRemaining ticks) leave the underlying
    // data untouched — carry the memoized views over instead of paying
    // O(n log n) recompute per tick.
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
        flashEnd,
        flashRemaining,
        flashSales,
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
    byCategory.addAll(other.byCategory);
  }
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(CatalogState()) {
    // Countdown ticking lives in FlashSaleTicker (server-driven); the
    // legacy 1Hz saleSeconds timer was removed (audit P4) — nothing
    // consumed it and it rebuilt memo caches every second.
    _flashTicker = FlashSaleTicker(now: _now);
  }

  final CatalogRepository _repository;

  /// Injectable clock so the flash countdown is testable deterministically.
  final DateTime Function() _now;
  late final FlashSaleTicker _flashTicker;
  Timer? _queryDebounce;

  Future<void> load() async {
    emit(state.copyWith(status: CatalogStatus.loading));
    final productResult = await _repository.fetchProducts();
    final categoryResult = await _repository.fetchCategories();
    productResult.when(
      success: (products) {
        final cats = categoryResult.when(
          success: (c) => c,
          failure: (_) => <String>['All'],
        );
        emit(state.copyWith(
          status: CatalogStatus.ready,
          allProducts: products,
          categories: cats,
        ));
        // Integrate flash sales into initial load (T1). Fire-and-forget;
        // emissions are skipped when sales are empty to keep existing
        // load tests deterministic.
        // ignore: discarded_futures
        loadFlashSales();
      },
      failure: (_) => emit(state.copyWith(status: CatalogStatus.error)),
    );
  }

  /// Loads active flash sales from the repository and binds the countdown.
  ///
  /// Calls [_repository.getActiveFlashSales] and emits [state.flashSales].
  /// When the first sale carries an [FlashSale.endsAt], it drives
  /// [startFlashSale] so the countdown ticks live. Failures are
  /// swallowed so catalog loading never regresses to error due to a
  /// flash-sale fetch issue.
  Future<void> loadFlashSales() async {
    final result = await _repository.getActiveFlashSales();
    result.when(
      success: (sales) {
        if (sales.isEmpty && state.flashSales.isEmpty) return;
        emit(state.copyWith(flashSales: sales));
        if (sales.isNotEmpty) {
          final endsAt = sales.first.endsAt;
          if (endsAt != null) startFlashSale(end: endsAt);
        }
      },
      failure: (_) {
        // Swallow — flash sales are non-critical.
      },
    );
  }

  void select(String category) =>
      emit(state.copyWith(filters: state.filters.copyWith(category: category)));

  /// Live search with a 300ms debounce: each keystroke restarts the
  /// timer so typing runs one O(n log n) filter pass, not one per
  /// character. The text field itself is controller-driven, so display
  /// never lags. Recent queries are recorded in the same fire.
  void updateQuery(String query) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 300), () {
      if (isClosed) return;
      final trimmed = query.trim();
      final recents = trimmed.isEmpty
          ? state.recentQueries
          : [trimmed, ...state.recentQueries.where((r) => r != trimmed)]
              .take(5)
              .toList();
      emit(state.copyWith(
        filters: state.filters.copyWith(query: query),
        recentQueries: recents,
      ));
    });
  }

  void selectSort(CatalogSort sort) =>
      emit(state.copyWith(filters: state.filters.copyWith(sort: sort)));

  void setColorFilter(String color) {
    if (color == state.filters.colorFilter) {
      emit(state.copyWith(
          filters: state.filters.copyWith(clearColorFilter: true)));
    } else {
      emit(state.copyWith(filters: state.filters.copyWith(colorFilter: color)));
    }
  }

  void setPriceRange(Money min, Money max) => emit(state.copyWith(
      filters: state.filters.copyWith(priceMin: min, priceMax: max)));

  void clearFilters() {
    // A pending debounced query must not land after the reset.
    _queryDebounce?.cancel();
    emit(state.copyWith(filters: const CatalogFilters()));
  }

  void carousel(int index) => emit(state.copyWith(carouselIndex: index));

  /// Starts the flash-sale countdown ending at [end].
  ///
  /// Delegates ticking to [FlashSaleTicker]; mirrors updates back into
  /// state via `onTick: (remaining) => emit(state.copyWith(flashRemaining: remaining))`.
  void startFlashSale({required DateTime end}) {
    emit(state.copyWith(flashEnd: end));
    _flashTicker.start(
      end,
      onTick: (remaining) => emit(state.copyWith(flashRemaining: remaining)),
    );
  }

  @override
  Future<void> close() {
    _flashTicker.cancel();
    _queryDebounce?.cancel();
    return super.close();
  }

  void deleteRecentQuery(String q) {
    emit(state.copyWith(
        recentQueries: state.recentQueries.where((r) => r != q).toList()));
  }
}
