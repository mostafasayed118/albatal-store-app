import 'package:al_batal_elite/features/storefront/domain/entities/catalog_filters.dart';
import 'package:al_batal_elite/features/storefront/presentation/catalog_sort_label.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression pin (audit): `CatalogSortLabel.label` returned hardcoded
/// English rendered verbatim in the sort menus, so an Arabic session read
/// English sort options. `catalogSortLabel` must resolve localized copy.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  test('every sort resolves to exact English copy', () {
    expect(catalogSortLabel(en, CatalogSort.featured), 'Featured');
    expect(
        catalogSortLabel(en, CatalogSort.priceLowToHigh), 'Price: low to high');
    expect(catalogSortLabel(
        en, CatalogSort.priceHighToLow), 'Price: high to low');
    expect(catalogSortLabel(en, CatalogSort.name), 'Name: A to Z');
    expect(catalogSortLabel(en, CatalogSort.newest), 'Newest');
  });

  test('no sort falls back to English in Arabic', () {
    for (final sort in CatalogSort.values) {
      final arabic = catalogSortLabel(ar, sort);
      expect(arabic, isNotEmpty, reason: 'sort $sort is empty in Arabic');
      expect(arabic, isNot(catalogSortLabel(en, sort)),
          reason: 'sort $sort is still English in Arabic');
    }
  });
}
