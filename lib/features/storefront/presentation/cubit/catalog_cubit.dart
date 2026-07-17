import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';
import 'products_data.dart';

enum CatalogSort { featured, priceLowToHigh, priceHighToLow, name }

extension CatalogSortLabel on CatalogSort {
  String get label => switch (this) {
        CatalogSort.featured => 'Featured',
        CatalogSort.priceLowToHigh => 'Price: low to high',
        CatalogSort.priceHighToLow => 'Price: high to low',
        CatalogSort.name => 'Name: A to Z',
      };
}

final class CatalogState extends Equatable {
  const CatalogState({
    this.category = 'All',
    this.query = '',
    this.sort = CatalogSort.featured,
    this.carouselIndex = 0,
    this.saleSeconds = 14362,
  });

  final String category;
  final String query;
  final CatalogSort sort;
  final int carouselIndex;
  final int saleSeconds;

  bool get hasActiveFilters => category != 'All' || query.isNotEmpty || sort != CatalogSort.featured;

  List<Product> get visible {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = products.where((product) {
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
    String? category,
    String? query,
    CatalogSort? sort,
    int? carouselIndex,
    int? saleSeconds,
  }) =>
      CatalogState(
        category: category ?? this.category,
        query: query ?? this.query,
        sort: sort ?? this.sort,
        carouselIndex: carouselIndex ?? this.carouselIndex,
        saleSeconds: saleSeconds ?? this.saleSeconds,
      );

  @override
  List<Object?> get props => [category, query, sort, carouselIndex, saleSeconds];
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit() : super(const CatalogState()) {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emit(state.copyWith(saleSeconds: (state.saleSeconds - 1).clamp(0, 999999).toInt())),
    );
  }

  late final Timer _timer;

  void select(String category) => emit(state.copyWith(category: category));
  void updateQuery(String query) => emit(state.copyWith(query: query));
  void selectSort(CatalogSort sort) => emit(state.copyWith(sort: sort));
  void clearFilters() => emit(state.copyWith(category: 'All', query: '', sort: CatalogSort.featured));
  void carousel(int index) => emit(state.copyWith(carouselIndex: index));

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}
