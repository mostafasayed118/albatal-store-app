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

final class CatalogState extends Equatable {
  const CatalogState({
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

  /// Unique colors extracted from all products (by name derived from imageColor).
  List<String> get availableColors {
    final colors = <String>{};
    for (final p in allProducts) {
      colors.add(catalogColorName(p.imageColor));
    }
    return colors.toList()..sort();
  }

  /// Price bounds computed from the full catalog.
  Money get catalogPriceMin => allProducts.isEmpty
      ? Money.zero
      : allProducts.map((p) => p.price).reduce((a, b) => a < b ? a : b);
  Money get catalogPriceMax => allProducts.isEmpty
      ? CatalogConstants.unboundedMax
      : allProducts.map((p) => p.price).reduce((a, b) => a > b ? a : b);

  /// Products in a specific category (excluding "All").
  List<Product> productsInCategory(String category) =>
      allProducts.where((p) => p.category == category).toList();

  /// Product count per category (excluding "All").
  Map<String, int> get categoryProductCount {
    final map = <String, int>{};
    for (final p in allProducts) {
      map[p.category] = (map[p.category] ?? 0) + 1;
    }
    return map;
  }

  List<Product> get visible {
    final filtered = allProducts.where(filters.matches).toList();

    switch (filters.sort) {
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
    return filtered;
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

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const CatalogState()) {
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
      emit(state.copyWith(
          filters: state.filters.copyWith(colorFilter: color)));
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
