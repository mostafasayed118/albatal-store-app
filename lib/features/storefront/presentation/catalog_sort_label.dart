import '../../../generated/l10n/app_localizations.dart';
import '../domain/entities/catalog_filters.dart';

/// The one place a [CatalogSort] becomes shopper-visible copy.
///
/// Why this exists: `CatalogSortLabel.label` in the domain layer returned
/// hardcoded English (`'Featured'`, `'Price: low to high'`, …), which two
/// surfaces rendered verbatim — so an Arabic session read English sort
/// options (audit). The enum lives in the domain layer, which must not know
/// about presentation copy (same rule as `adminOrderStatusLabel`), so the
/// mapping lives here against ARB keys.
String catalogSortLabel(AppLocalizations l, CatalogSort sort) => switch (sort) {
      CatalogSort.featured => l.sortFeatured,
      CatalogSort.priceLowToHigh => l.sortPriceLowToHigh,
      CatalogSort.priceHighToLow => l.sortPriceHighToLow,
      CatalogSort.name => l.sortNameAZ,
      CatalogSort.newest => l.sortNewest,
    };
