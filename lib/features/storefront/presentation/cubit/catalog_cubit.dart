import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

enum CatalogSort { featured, priceLowToHigh, priceHighToLow, name, newest }

extension CatalogSortLabel on CatalogSort {
  String get label => switch (this) {
        CatalogSort.featured => 'Featured',
        CatalogSort.priceLowToHigh => 'Price: low to high',
        CatalogSort.priceHighToLow => 'Price: high to low',
        CatalogSort.name => 'Name: A to Z',
        CatalogSort.newest => 'Newest',
      };
}

enum CatalogStatus { initial, loading, ready, error }

final class CatalogState extends Equatable {
  const CatalogState({
    this.status = CatalogStatus.initial,
    this.allProducts = const [],
    this.categories = const [],
    this.category = 'All',
    this.query = '',
    this.sort = CatalogSort.featured,
    this.carouselIndex = 0,
    this.saleSeconds = 14362,
    this.recentQueries = const [],
    this.colorFilter = '',
    this.priceMin = 0.0,
    this.priceMax = 999999.0,
  });

  final CatalogStatus status;
  final List<Product> allProducts;
  final List<String> categories;
  final String category;
  final String query;
  final CatalogSort sort;
  final int carouselIndex;
  final int saleSeconds;
  final List<String> recentQueries;
  final String colorFilter;
  final double priceMin;
  final double priceMax;

  bool get hasActiveFilters =>
      category != 'All' ||
      query.isNotEmpty ||
      sort != CatalogSort.featured ||
      colorFilter.isNotEmpty ||
      priceMin > 0 ||
      priceMax < 999999;

  /// Unique colors extracted from all products (by name derived from imageColor).
  List<String> get availableColors {
    final colors = <String>{};
    for (final p in allProducts) {
      colors.add(_colorName(p.imageColor));
    }
    return colors.toList()..sort();
  }

  /// Price bounds computed from the full catalog.
  double get catalogPriceMin =>
      allProducts.isEmpty ? 0 : allProducts.map((p) => p.price).reduce((a, b) => a < b ? a : b);
  double get catalogPriceMax =>
      allProducts.isEmpty ? 999999 : allProducts.map((p) => p.price).reduce((a, b) => a > b ? a : b);

  List<Product> get visible {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = allProducts.where((product) {
      final matchesCategory = category == 'All' || product.category == category;
      final matchesQuery = normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.category.toLowerCase().contains(normalizedQuery) ||
          (product.description?.toLowerCase().contains(normalizedQuery) ?? false);
      final matchesColor = colorFilter.isEmpty ||
          _colorName(product.imageColor) == colorFilter;
      final matchesPrice = product.price >= priceMin && product.price <= priceMax;
      return matchesCategory && matchesQuery && matchesColor && matchesPrice;
    }).toList();

    switch (sort) {
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
    String? category,
    String? query,
    CatalogSort? sort,
    int? carouselIndex,
    int? saleSeconds,
    List<String>? recentQueries,
    String? colorFilter,
    double? priceMin,
    double? priceMax,
    bool clearColorFilter = false,
    bool resetPrice = false,
  }) =>
      CatalogState(
        status: status ?? this.status,
        allProducts: allProducts ?? this.allProducts,
        categories: categories ?? this.categories,
        category: category ?? this.category,
        query: query ?? this.query,
        sort: sort ?? this.sort,
        carouselIndex: carouselIndex ?? this.carouselIndex,
        saleSeconds: saleSeconds ?? this.saleSeconds,
        recentQueries: recentQueries ?? this.recentQueries,
        colorFilter: clearColorFilter ? '' : (colorFilter ?? this.colorFilter),
        priceMin: resetPrice ? 0 : (priceMin ?? this.priceMin),
        priceMax: resetPrice ? 999999 : (priceMax ?? this.priceMax),
      );

  @override
  List<Object?> get props => [
        status,
        allProducts,
        categories,
        category,
        query,
        sort,
        carouselIndex,
        saleSeconds,
        recentQueries,
        colorFilter,
        priceMin,
        priceMax,
      ];
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState()) {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emit(state.copyWith(
          saleSeconds: (state.saleSeconds - 1).clamp(0, 999999).toInt())),
    );
  }

  final CatalogRepository _repository;
  late final Timer _timer;
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

  void select(String category) => emit(state.copyWith(category: category));

  void updateQuery(String query) {
    _debounce?.cancel();
    emit(state.copyWith(query: query));
    if (query.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _recordRecentQuery(query.trim());
      });
    }
  }

  void selectSort(CatalogSort sort) => emit(state.copyWith(sort: sort));

  void setColorFilter(String color) {
    if (color == state.colorFilter) {
      emit(state.copyWith(clearColorFilter: true));
    } else {
      emit(state.copyWith(colorFilter: color));
    }
  }

  void setPriceRange(double min, double max) =>
      emit(state.copyWith(priceMin: min, priceMax: max));

  void clearFilters() => emit(
      state.copyWith(
        category: 'All',
        query: '',
        sort: CatalogSort.featured,
        clearColorFilter: true,
        resetPrice: true,
      ));

  void carousel(int index) => emit(state.copyWith(carouselIndex: index));

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
    _debounce?.cancel();
    return super.close();
  }
}

/// Maps an imageColor int to a human-readable color name for filtering.
String _colorName(int color) {
  const map = {
    0xFF176B57: 'Emerald',
    0xFFC99A64: 'Gold',
    0xFF302244: 'Purple',
    0xFFD9C6A1: 'Beige',
    0xFF88715F: 'Brown',
    0xFFB57A2A: 'Amber',
    0xFF6FA39A: 'Teal',
    0xFF6B1F2E: 'Crimson',
    0xFFE0CDA0: 'Sand',
  };
  return map[color] ?? 'Other';
}
