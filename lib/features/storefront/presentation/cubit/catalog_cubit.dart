import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';
import '../../domain/entities/catalog_filters.dart';
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
    this.saleSeconds = 14362,
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
  final int saleSeconds;
  final List<String> recentQueries;
  final DateTime? flashEnd;
  final Duration? flashRemaining;

  /// Active flash sales (T1) — raw rows from the repository.
  final List<Map<String, dynamic>> flashSales;

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
    int? saleSeconds,
    List<String>? recentQueries,
    DateTime? flashEnd,
    Duration? flashRemaining,
    List<Map<String, dynamic>>? flashSales,
  }) =>
      CatalogState(
        status: status ?? this.status,
        allProducts: allProducts ?? this.allProducts,
        categories: categories ?? this.categories,
        filters: filters ?? this.filters,
        carouselIndex: carouselIndex ?? this.carouselIndex,
        saleSeconds: saleSeconds ?? this.saleSeconds,
        recentQueries: recentQueries ?? this.recentQueries,
        flashEnd: flashEnd ?? this.flashEnd,
        flashRemaining: flashRemaining ?? this.flashRemaining,
        flashSales: flashSales ?? this.flashSales,
      );

  @override
  List<Object?> get props => [
        status,
        allProducts,
        categories,
        filters,
        carouselIndex,
        saleSeconds,
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
  final Map<String, List<Product>> byCategory = {};
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(CatalogState()) {
    // Legacy hero countdown (saleSeconds) — will be removed when flash_sales table lands.
    // Gated to avoid needless ticks: only ticks while saleSeconds > 0,
    // cancelled deterministically in close().
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (state.saleSeconds == 0) return;
        emit(state.copyWith(
            saleSeconds: (state.saleSeconds - 1).clamp(0, 999999).toInt()));
      },
    );
    _flashTicker = FlashSaleTicker(now: _now);
  }

  final CatalogRepository _repository;

  /// Injectable clock so the flash countdown is testable deterministically.
  final DateTime Function() _now;
  late final Timer _timer;
  late final FlashSaleTicker _flashTicker;
  Timer? _debounce;

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
  /// When a sale is active, the first sale's `endsAt` drives
  /// [startFlashSale] so the countdown ticks live. Failures are
  /// swallowed so catalog loading never regresses to error due to a
  /// flash-sale fetch issue.
  Future<void> loadFlashSales() async {
    try {
      final sales = await _repository.getActiveFlashSales();
      if (sales.isEmpty && state.flashSales.isEmpty) return;
      emit(state.copyWith(flashSales: sales));
      if (sales.isNotEmpty) {
        final endsAt = _parseFlashEndsAt(sales.first);
        if (endsAt != null) startFlashSale(end: endsAt);
      }
    } catch (_) {
      // Swallow — flash sales are non-critical.
    }
  }

  DateTime? _parseFlashEndsAt(Map<String, dynamic> sale) {
    final raw = sale['ends_at'] ?? sale['endsAt'] ?? sale['end_at'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  void select(String category) =>
      emit(state.copyWith(filters: state.filters.copyWith(category: category)));

  void updateQuery(String query) {
    _debounce?.cancel();
    emit(state.copyWith(filters: state.filters.copyWith(query: query)));
    if (query.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _recordRecentQuery(query.trim());
      });
    }
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

  void clearFilters() => emit(state.copyWith(filters: const CatalogFilters()));

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

  void _recordRecentQuery(String q) {
    final updated =
        [q, ...state.recentQueries.where((r) => r != q)].take(5).toList();
    emit(state.copyWith(recentQueries: updated));
  }

  void deleteRecentQuery(String q) {
    emit(state.copyWith(
        recentQueries: state.recentQueries.where((r) => r != q).toList()));
  }

  @override
  Future<void> close() {
    _timer.cancel();
    _flashTicker.cancel();
    _debounce?.cancel();
    return super.close();
  }
}
