import 'package:equatable/equatable.dart';

import '../../../../core/entities/money.dart';
import '../../../../core/entities/product.dart';

/// Sort modes for the catalog visible list.
enum CatalogSort { featured, priceLowToHigh, priceHighToLow, name, newest }

/// Fabric weight bands for the attribute finder (Batch 3 #4, v1).
///
/// Bands are range-based, never raw-text enums: `composition` free text is
/// inconsistent, but `gsm` is a structured column. Null gsm matches only
/// [unspecified] (or [any]) — never silently hidden, never silently shown.
enum FabricWeight { any, light, medium, heavy, unspecified }

/// Fabric roll-width bands (Batch 3 #4, v1). Same null contract as weight.
enum FabricWidth { any, narrow, standard, wide, unspecified }

/// Price bounds owned by the catalog domain (audit 2026-09-21: renamed —
/// the presentation feature already owns a `CatalogConstants` for
/// swatch/category data, and two same-named holders in one feature
/// guarantee the wrong import).
abstract final class CatalogPriceBounds {
  /// Upper bound used when no max-price filter is applied.
  /// Large enough to cover any plausible fabric price (999999 EGP).
  static const unboundedMax = Money.egp(999999);
}

/// Attribute-finder constants (Batch 3 #4, v1 — zero migration).
abstract final class FabricFinder {
  /// GSM band edges: light < 150, medium 150–300, heavy > 300.
  static const lightGsmMax = 150;
  static const heavyGsmMin = 300;

  /// Width band edges (cm): narrow < 150, standard == 150, wide > 150.
  static const standardWidthCm = 150;

  /// Curated fabric keywords allowed in [CatalogFilters.fabricKeyword].
  /// Matched case-insensitively against `composition` only — the one
  /// free-text field curated enough for `contains`. Anything outside this
  /// list is ignored (fail-open: a crafted value constrains nothing).
  static const keywords = [
    'cotton',
    'linen',
    'silk',
    'wool',
    'polyester',
    'velvet',
    'chiffon',
    'denim',
  ];
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
    this.weight = FabricWeight.any,
    this.width = FabricWidth.any,
    this.fabricKeyword = '',
    this.inStockOnly = false,
    this.sellByLengthOnly = false,
    this.minRating = 0,
  });

  final String category;
  final String query;
  final CatalogSort sort;
  final String colorFilter;
  final Money priceMin;
  final Money priceMax;

  /// Attribute-finder facets (Batch 3 #4, v1). All default to inert so
  /// existing constructions and the default grid are byte-identical.
  final FabricWeight weight;
  final FabricWidth width;
  final String fabricKeyword;
  final bool inStockOnly;
  final bool sellByLengthOnly;
  final double minRating;

  /// True when any filter differs from its default.
  bool get hasActiveFilters =>
      category != 'All' ||
      query.isNotEmpty ||
      sort != CatalogSort.featured ||
      colorFilter.isNotEmpty ||
      priceMin > Money.zero ||
      priceMax < CatalogPriceBounds.unboundedMax ||
      weight != FabricWeight.any ||
      width != FabricWidth.any ||
      fabricKeyword.isNotEmpty ||
      inStockOnly ||
      sellByLengthOnly ||
      minRating > 0;

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
    final matchesWeight = switch (weight) {
      FabricWeight.any => true,
      FabricWeight.light =>
        product.gsm != null && product.gsm! < FabricFinder.lightGsmMax,
      FabricWeight.medium => product.gsm != null &&
          product.gsm! >= FabricFinder.lightGsmMax &&
          product.gsm! <= FabricFinder.heavyGsmMin,
      FabricWeight.heavy =>
        product.gsm != null && product.gsm! > FabricFinder.heavyGsmMin,
      FabricWeight.unspecified => product.gsm == null,
    };
    final matchesWidth = switch (width) {
      FabricWidth.any => true,
      FabricWidth.narrow => product.widthCm != null &&
          product.widthCm! < FabricFinder.standardWidthCm,
      FabricWidth.standard => product.widthCm == FabricFinder.standardWidthCm,
      FabricWidth.wide => product.widthCm != null &&
          product.widthCm! > FabricFinder.standardWidthCm,
      FabricWidth.unspecified => product.widthCm == null,
    };
    // Curated allow-list only (see [FabricFinder.keywords]): unknown
    // values constrain nothing instead of matching nothing.
    final keyword = fabricKeyword.trim().toLowerCase();
    final matchesFabric = keyword.isEmpty ||
        !FabricFinder.keywords.contains(keyword) ||
        (product.composition?.toLowerCase().contains(keyword) ?? false);
    final matchesStock = !inStockOnly || product.inStock;
    final matchesCut = !sellByLengthOnly || product.sellByLength;
    final matchesRating = product.rating >= minRating;
    return matchesCategory &&
        matchesQuery &&
        matchesColor &&
        matchesPrice &&
        matchesWeight &&
        matchesWidth &&
        matchesFabric &&
        matchesStock &&
        matchesCut &&
        matchesRating;
  }

  CatalogFilters copyWith({
    String? category,
    String? query,
    CatalogSort? sort,
    String? colorFilter,
    Money? priceMin,
    Money? priceMax,
    FabricWeight? weight,
    FabricWidth? width,
    String? fabricKeyword,
    bool? inStockOnly,
    bool? sellByLengthOnly,
    double? minRating,
    bool clearColorFilter = false,
    bool resetPrice = false,
    bool clearFabricFilters = false,
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
        weight: clearFabricFilters ? FabricWeight.any : (weight ?? this.weight),
        width: clearFabricFilters ? FabricWidth.any : (width ?? this.width),
        fabricKeyword:
            clearFabricFilters ? '' : (fabricKeyword ?? this.fabricKeyword),
        inStockOnly:
            clearFabricFilters ? false : (inStockOnly ?? this.inStockOnly),
        sellByLengthOnly: clearFabricFilters
            ? false
            : (sellByLengthOnly ?? this.sellByLengthOnly),
        minRating: clearFabricFilters ? 0 : (minRating ?? this.minRating),
      );

  @override
  List<Object?> get props => [
        category,
        query,
        sort,
        colorFilter,
        priceMin,
        priceMax,
        weight,
        width,
        fabricKeyword,
        inStockOnly,
        sellByLengthOnly,
        minRating,
      ];
}
