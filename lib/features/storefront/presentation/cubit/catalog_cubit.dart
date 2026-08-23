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
    CatalogFilters? filters,
    // Deprecated individual filter params — kept for backward compat.
    // Stored as overrides and merged lazily in [filters] getter to keep
    // the const constructor valid (Dart disallows `??` with variable inside
    // a const object creation for the derived field).
    String? category,
    String? query,
    CatalogSort? sort,
    String? colorFilter,
    Money? priceMin,
    Money? priceMax,
    this.carouselIndex = 0,
    this.saleSeconds = 14362,
    this.recentQueries = const [],
    this.flashEnd,
    this.flashRemaining,
  })  : _rawFilters = filters ?? const CatalogFilters(),
        _category = category,
        _query = query,
        _sort = sort,
        _colorFilter = colorFilter,
        _priceMin = priceMin,
        _priceMax = priceMax;

  final CatalogStatus status;
  final List<Product> allProducts;
  final List<String> categories;
  final CatalogFilters _rawFilters;
  final String? _category;
  final String? _query;
  final CatalogSort? _sort;
  final String? _colorFilter;
  final Money? _priceMin;
  final Money? _priceMax;
  final int carouselIndex;
  final int saleSeconds;
  final List<String> recentQueries;
  final DateTime? flashEnd;
  final Duration? flashRemaining;

  /// Effective filters — merges overrides when deprecated ctor params were used.
  CatalogFilters get filters {
    if (_category == null &&
        _query == null &&
        _sort == null &&
        _colorFilter == null &&
        _priceMin == null &&
        _priceMax == null) {
      return _rawFilters;
    }
    return CatalogFilters(
      category: _category ?? _rawFilters.category,
      query: _query ?? _rawFilters.query,
      sort: _sort ?? _rawFilters.sort,
      colorFilter: _colorFilter ?? _rawFilters.colorFilter,
      priceMin: _priceMin ?? _rawFilters.priceMin,
      priceMax: _priceMax ?? _rawFilters.priceMax,
    );
  }

  // Backward-compat getters so existing tests/pages (state.category etc) keep working.
  @Deprecated('Use filters.category')
  String get category => filters.category;
  @Deprecated('Use filters.query')
  String get query => filters.query;
  @Deprecated('Use filters.sort')
  CatalogSort get sort => filters.sort;
  @Deprecated('Use filters.colorFilter')
  String get colorFilter => filters.colorFilter;
  @Deprecated('Use filters.priceMin')
  Money get priceMin => filters.priceMin;
  @Deprecated('Use filters.priceMax')
  Money get priceMax => filters.priceMax;

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
    @Deprecated('Use filters') String? category,
    @Deprecated('Use filters') String? query,
    @Deprecated('Use filters') CatalogSort? sort,
    int? carouselIndex,
    int? saleSeconds,
    List<String>? recentQueries,
    @Deprecated('Use filters') String? colorFilter,
    @Deprecated('Use filters') Money? priceMin,
    @Deprecated('Use filters') Money? priceMax,
    bool clearColorFilter = false,
    bool resetPrice = false,
    DateTime? flashEnd,
    Duration? flashRemaining,
  }) {
    var effectiveFilters = filters ?? this.filters;
    final hasDeprecated = category != null ||
        query != null ||
        sort != null ||
        colorFilter != null ||
        priceMin != null ||
        priceMax != null ||
        clearColorFilter ||
        resetPrice;
    if (hasDeprecated) {
      effectiveFilters = effectiveFilters.copyWith(
        category: category,
        query: query,
        sort: sort,
        colorFilter: colorFilter,
        priceMin: priceMin,
        priceMax: priceMax,
        clearColorFilter: clearColorFilter,
        resetPrice: resetPrice,
      );
    }
    return CatalogState(
      status: status ?? this.status,
      allProducts: allProducts ?? this.allProducts,
      categories: categories ?? this.categories,
      filters: effectiveFilters,
      carouselIndex: carouselIndex ?? this.carouselIndex,
      saleSeconds: saleSeconds ?? this.saleSeconds,
      recentQueries: recentQueries ?? this.recentQueries,
      flashEnd: flashEnd ?? this.flashEnd,
      flashRemaining: flashRemaining ?? this.flashRemaining,
    );
  }

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
      },
      failure: (_) => emit(state.copyWith(status: CatalogStatus.error)),
    );
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
    if (color == state.colorFilter) {
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
