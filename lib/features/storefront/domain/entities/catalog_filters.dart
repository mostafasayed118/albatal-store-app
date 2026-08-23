import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';

/// Sort modes for the catalog visible list.
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

/// Centralized catalog constants for audit lint compliance.
abstract final class CatalogConstants {
  /// Upper bound used when no max-price filter is applied.
  /// Large enough to cover any plausible fabric price (999999 EGP).
  static const unboundedMax = Money.egp(999999);
}

/// Maps an imageColor int to a human-readable color name for filtering.
///
/// TODO(audit): derive color names from DB/config (Product.colorName field)
/// rather than hardcoded map; keep fallback to 'Other' for unknown values.
String catalogColorName(int color) {
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

/// Immutable value object that owns all catalog filter criteria.
///
/// Extracted from [CatalogState] to reduce the God Cubit SRP violation
/// (audit HIGH). The state now holds a single [CatalogFilters] field and
/// exposes deprecated getters for backward compatibility so existing tests
/// and pages do not break.
final class CatalogFilters extends Equatable {
  const CatalogFilters({
    this.category = 'All',
    this.query = '',
    this.sort = CatalogSort.featured,
    this.colorFilter = '',
    this.priceMin = Money.zero,
    this.priceMax = CatalogConstants.unboundedMax,
  });

  final String category;
  final String query;
  final CatalogSort sort;
  final String colorFilter;
  final Money priceMin;
  final Money priceMax;

  /// True when any filter differs from its default.
  bool get hasActiveFilters =>
      category != 'All' ||
      query.isNotEmpty ||
      sort != CatalogSort.featured ||
      colorFilter.isNotEmpty ||
      priceMin > Money.zero ||
      priceMax < CatalogConstants.unboundedMax;

  /// Returns true when [product] matches all active filter criteria.
  bool matches(Product product) {
    final normalizedQuery = query.trim().toLowerCase();
    final matchesCategory = category == 'All' || product.category == category;
    final matchesQuery = normalizedQuery.isEmpty ||
        product.name.toLowerCase().contains(normalizedQuery) ||
        product.category.toLowerCase().contains(normalizedQuery) ||
        (product.description?.toLowerCase().contains(normalizedQuery) ?? false);
    final matchesColor =
        colorFilter.isEmpty || catalogColorName(product.imageColor) == colorFilter;
    final matchesPrice = product.price >= priceMin && product.price <= priceMax;
    return matchesCategory && matchesQuery && matchesColor && matchesPrice;
  }

  CatalogFilters copyWith({
    String? category,
    String? query,
    CatalogSort? sort,
    String? colorFilter,
    Money? priceMin,
    Money? priceMax,
    bool clearColorFilter = false,
    bool resetPrice = false,
  }) =>
      CatalogFilters(
        category: category ?? this.category,
        query: query ?? this.query,
        sort: sort ?? this.sort,
        colorFilter: clearColorFilter ? '' : (colorFilter ?? this.colorFilter),
        priceMin: resetPrice ? Money.zero : (priceMin ?? this.priceMin),
        priceMax:
            resetPrice ? CatalogConstants.unboundedMax : (priceMax ?? this.priceMax),
      );

  @override
  List<Object?> get props => [category, query, sort, colorFilter, priceMin, priceMax];
}
