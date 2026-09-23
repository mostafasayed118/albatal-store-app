import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';

/// Sort modes for the catalog visible list.
enum CatalogSort { featured, priceLowToHigh, priceHighToLow, name, newest }

/// Price bounds owned by the catalog domain (audit 2026-09-21: renamed —
/// the presentation feature already owns a `CatalogConstants` for
/// swatch/category data, and two same-named holders in one feature
/// guarantee the wrong import).
abstract final class CatalogPriceBounds {
  /// Upper bound used when no max-price filter is applied.
  /// Large enough to cover any plausible fabric price (999999 EGP).
  static const unboundedMax = Money.egp(999999);
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
    this.priceMax = CatalogPriceBounds.unboundedMax,
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
      priceMax < CatalogPriceBounds.unboundedMax;

  /// Returns true when [product] matches all active filter criteria.
  bool matches(Product product) {
    final normalizedQuery = query.trim().toLowerCase();
    final matchesCategory = category == 'All' || product.category == category;
    final matchesQuery = normalizedQuery.isEmpty ||
        product.name.toLowerCase().contains(normalizedQuery) ||
        product.category.toLowerCase().contains(normalizedQuery) ||
        (product.description?.toLowerCase().contains(normalizedQuery) ?? false);
    // Same source as CatalogState.availableColors (variant colors OR the
    // curated products.color_name — audit 2026-09-21 M-03) — the filter
    // chips and the matcher must agree or offered chips can never match
    // anything (imageColor is a placeholder tint on network rows).
    final matchesColor = colorFilter.isEmpty ||
        product.colors.contains(colorFilter) ||
        product.colorName == colorFilter;
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
        priceMax: resetPrice
            ? CatalogPriceBounds.unboundedMax
            : (priceMax ?? this.priceMax),
      );

  @override
  List<Object?> get props =>
      [category, query, sort, colorFilter, priceMin, priceMax];
}
