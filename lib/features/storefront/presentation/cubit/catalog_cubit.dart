import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

enum CatalogSort { featured, priceLowToHigh, priceHighToLow, name }

extension CatalogSortLabel on CatalogSort {
  String get label => switch (this) {
        CatalogSort.featured => 'Featured',
        CatalogSort.priceLowToHigh => 'Price: low to high',
        CatalogSort.priceHighToLow => 'Price: high to low',
        CatalogSort.name => 'Name: A to Z',
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

  bool get hasActiveFilters =>
      category != 'All' || query.isNotEmpty || sort != CatalogSort.featured;

  List<Product> get visible {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = allProducts.where((product) {
      final matchesCategory = category == 'All' || product.category == category;
      final matchesQuery = normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          product.category.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
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
      ];
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogState()) {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emit(state.copyWith(
          saleSeconds: (state.saleSeconds - 1).clamp(0, 999999).toInt())),
    );
    load();
  }

  final CatalogRepository _repository;
  late final Timer _timer;
  Timer? _debounce;

  /// Fetches products + categories through the repository.
  /// On success the state becomes [CatalogStatus.ready] with populated lists.
  /// On failure the state becomes [CatalogStatus.error]; the UI can retry
  /// by calling [load] again.
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

  /// Debounced query update — prevents re-rendering the grid on every keystroke.
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

  void clearFilters() => emit(
      state.copyWith(category: 'All', query: '', sort: CatalogSort.featured));

  void carousel(int index) => emit(state.copyWith(carouselIndex: index));

  void _recordRecentQuery(String q) {
    final updated = [q, ...state.recentQueries.where((r) => r != q)].take(5).toList();
    emit(state.copyWith(recentQueries: updated));
  }

  @override
  Future<void> close() {
    _timer.cancel();
    _debounce?.cancel();
    return super.close();
  }
}
