import 'package:al_batal_elite/generated/l10n/app_localizations_ar.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit 2026-09-19, sweep part 34 (Tier 3): the admin console used to hardcode
/// English in-code ("Admin-only, intentionally unlocalized, no ARB keys"). The
/// owner reversed that convention, so every string on those surfaces is now an
/// ARB key — and this table is the contract for the copy.
///
/// Failure directions are pinned separately, as in the Tier-1 pin: a missing
/// mapping leaks English, and an untranslated key would pass a mere "non-empty"
/// check. The Arabic assertion is therefore **difference**, not presence.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  // (key, English getter, Arabic getter, expected English copy)
  final cases = <(String, String, String, String)>[
    ('salesDashboard', en.salesDashboard, ar.salesDashboard, 'Sales Dashboard'),
    (
      'salesDashboardSubtitle',
      en.salesDashboardSubtitle,
      ar.salesDashboardSubtitle,
      'Revenue, best sellers, low stock'
    ),
    (
      'adminAccessCheckFailed',
      en.adminAccessCheckFailed,
      ar.adminAccessCheckFailed,
      'Unable to verify admin access. Please try again.'
    ),
    (
      'adminNoCategories',
      en.adminNoCategories,
      ar.adminNoCategories,
      'No categories yet'
    ),
    (
      'adminNoCategoriesBody',
      en.adminNoCategoriesBody,
      ar.adminNoCategoriesBody,
      'Categories are created in the database; the storefront needs at least one.'
    ),
    ('inactive', en.inactive, ar.inactive, 'Inactive'),
    (
      'adminImagesUpdated',
      en.adminImagesUpdated,
      ar.adminImagesUpdated,
      'Images updated'
    ),
    (
      'adminImageFileEmpty',
      en.adminImageFileEmpty,
      ar.adminImageFileEmpty,
      'Selected file is empty.'
    ),
    (
      'adminImageUnsupportedFormat',
      en.adminImageUnsupportedFormat,
      ar.adminImageUnsupportedFormat,
      'Unsupported format. Use JPG, PNG, or WebP.'
    ),
    (
      'adminImageTooLarge',
      en.adminImageTooLarge,
      ar.adminImageTooLarge,
      'Image is too large after compression.'
    ),
    (
      'adminImageUploaded',
      en.adminImageUploaded,
      ar.adminImageUploaded,
      'Image uploaded'
    ),
    (
      'adminImageUploadFailed',
      en.adminImageUploadFailed,
      ar.adminImageUploadFailed,
      'Upload failed. Please try again.'
    ),
    (
      'adminDeleteImageTitle',
      en.adminDeleteImageTitle,
      ar.adminDeleteImageTitle,
      'Delete image?'
    ),
    (
      'adminDeleteImageBody',
      en.adminDeleteImageBody,
      ar.adminDeleteImageBody,
      'This removes the image from the product gallery on the store.'
    ),
    (
      'adminImagesLoadFailed',
      en.adminImagesLoadFailed,
      ar.adminImagesLoadFailed,
      'Could not load images'
    ),
    (
      'adminUploadImage',
      en.adminUploadImage,
      ar.adminUploadImage,
      'Upload Image'
    ),
    ('adminNoImages', en.adminNoImages, ar.adminNoImages, 'No images yet'),
    (
      'adminNoImagesBody',
      en.adminNoImagesBody,
      ar.adminNoImagesBody,
      'Upload the first image so the product has a gallery on the store.'
    ),
    (
      'adminProductNotFound',
      en.adminProductNotFound,
      ar.adminProductNotFound,
      'Product not found'
    ),
    (
      'adminSelectCategory',
      en.adminSelectCategory,
      ar.adminSelectCategory,
      'Please select a category'
    ),
    (
      'adminInvalidPrice',
      en.adminInvalidPrice,
      ar.adminInvalidPrice,
      'Invalid price'
    ),
    (
      'adminPriceNegative',
      en.adminPriceNegative,
      ar.adminPriceNegative,
      'Price cannot be negative'
    ),
    (
      'adminProductCreated',
      en.adminProductCreated,
      ar.adminProductCreated,
      'Product created'
    ),
    (
      'adminProductUpdated',
      en.adminProductUpdated,
      ar.adminProductUpdated,
      'Product updated'
    ),
    ('adminNewProduct', en.adminNewProduct, ar.adminNewProduct, 'New Product'),
    (
      'adminEditProduct',
      en.adminEditProduct,
      ar.adminEditProduct,
      'Edit Product'
    ),
    ('adminNameField', en.adminNameField, ar.adminNameField, 'Name'),
    ('adminSlugField', en.adminSlugField, ar.adminSlugField, 'Slug'),
    (
      'adminRequiredField',
      en.adminRequiredField,
      ar.adminRequiredField,
      'Required'
    ),
    (
      'adminBasePrice',
      en.adminBasePrice,
      ar.adminBasePrice,
      'Base Price (EGP)'
    ),
    (
      'adminInvalidNumber',
      en.adminInvalidNumber,
      ar.adminInvalidNumber,
      'Invalid number'
    ),
    ('adminWidthCm', en.adminWidthCm, ar.adminWidthCm, 'Width (cm)'),
    ('adminWeightGsm', en.adminWeightGsm, ar.adminWeightGsm, 'Weight (GSM)'),
    (
      'adminSellByLength',
      en.adminSellByLength,
      ar.adminSellByLength,
      'Sell by length (per meter)'
    ),
    (
      'adminSellByLengthHint',
      en.adminSellByLengthHint,
      ar.adminSellByLengthHint,
      'Shoppers pick a custom cut length in 0.5 m steps'
    ),
    (
      'adminMinCutMeters',
      en.adminMinCutMeters,
      ar.adminMinCutMeters,
      'Minimum cut (meters)'
    ),
    (
      'adminCreateProduct',
      en.adminCreateProduct,
      ar.adminCreateProduct,
      'Create Product'
    ),
    (
      'adminUpdateProduct',
      en.adminUpdateProduct,
      ar.adminUpdateProduct,
      'Update Product'
    ),
    (
      'adminNoProducts',
      en.adminNoProducts,
      ar.adminNoProducts,
      'No products yet'
    ),
    (
      'adminNoProductsBody',
      en.adminNoProductsBody,
      ar.adminNoProductsBody,
      'Create the first product so the storefront has something to sell.'
    ),
    (
      'adminImagesTooltip',
      en.adminImagesTooltip,
      ar.adminImagesTooltip,
      'Images'
    ),
    ('adminReload', en.adminReload, ar.adminReload, 'Reload'),
    (
      'adminSalesLoadFailed',
      en.adminSalesLoadFailed,
      ar.adminSalesLoadFailed,
      'Could not load sales'
    ),
    (
      'adminSalesLoadFailedBody',
      en.adminSalesLoadFailedBody,
      ar.adminSalesLoadFailedBody,
      'Failed to load sales data.'
    ),
    (
      'adminNoSalesData',
      en.adminNoSalesData,
      ar.adminNoSalesData,
      'No sales data available.'
    ),
    ('adminAddVariant', en.adminAddVariant, ar.adminAddVariant, 'Add Variant'),
    (
      'adminEditVariant',
      en.adminEditVariant,
      ar.adminEditVariant,
      'Edit Variant'
    ),
    ('adminSizeField', en.adminSizeField, ar.adminSizeField, 'Size'),
    ('adminStockField', en.adminStockField, ar.adminStockField, 'Stock'),
    (
      'adminPriceOverrideOptional',
      en.adminPriceOverrideOptional,
      ar.adminPriceOverrideOptional,
      'Price Override (optional)'
    ),
    (
      'adminSizeColorRequired',
      en.adminSizeColorRequired,
      ar.adminSizeColorRequired,
      'Size and color are required'
    ),
    (
      'adminInvalidStock',
      en.adminInvalidStock,
      ar.adminInvalidStock,
      'Invalid stock'
    ),
    (
      'adminInvalidPriceOverride',
      en.adminInvalidPriceOverride,
      ar.adminInvalidPriceOverride,
      'Invalid price override'
    ),
    (
      'adminPriceOverrideNegative',
      en.adminPriceOverrideNegative,
      ar.adminPriceOverrideNegative,
      'Price override cannot be negative'
    ),
    (
      'adminVariantSaved',
      en.adminVariantSaved,
      ar.adminVariantSaved,
      'Variant saved'
    ),
    (
      'adminNoVariants',
      en.adminNoVariants,
      ar.adminNoVariants,
      'No variants yet'
    ),
    (
      'adminVariantStock',
      en.adminVariantStock(3),
      ar.adminVariantStock(3),
      'Stock: 3'
    ),
    (
      'adminVariantOverride',
      en.adminVariantOverride('120'),
      ar.adminVariantOverride('120'),
      'Override: 120'
    ),
    (
      'adminLowStockTitle',
      en.adminLowStockTitle(5),
      ar.adminLowStockTitle(5),
      'Low stock (≤ 5)'
    ),
    (
      'adminLowStockEmpty',
      en.adminLowStockEmpty,
      ar.adminLowStockEmpty,
      'Nothing below the threshold'
    ),
    ('adminStockLeft', en.adminStockLeft(2), ar.adminStockLeft(2), '2 left'),
    (
      'adminRevenueLastDays',
      en.adminRevenueLastDays(14),
      ar.adminRevenueLastDays(14),
      'Revenue — last 14 days'
    ),
    (
      'adminNoRevenueData',
      en.adminNoRevenueData,
      ar.adminNoRevenueData,
      'No revenue data'
    ),
    (
      'adminOrdersByStatus',
      en.adminOrdersByStatus,
      ar.adminOrdersByStatus,
      'Orders by status'
    ),
    (
      'adminNoOrdersInWindow',
      en.adminNoOrdersInWindow,
      ar.adminNoOrdersInWindow,
      'No orders in this window'
    ),
    (
      'adminBestSellers',
      en.adminBestSellers,
      ar.adminBestSellers,
      'Best sellers — units sold'
    ),
    (
      'adminNoSalesInWindow',
      en.adminNoSalesInWindow,
      ar.adminNoSalesInWindow,
      'No sales in this window'
    ),
    ('adminUnitsShort', en.adminUnitsShort(4), ar.adminUnitsShort(4), '4 u'),
    ('unknown', en.unknown, ar.unknown, 'Unknown'),
    ('pending', en.pending, ar.pending, 'Pending'),
    ('refunded', en.refunded, ar.refunded, 'Refunded'),
  ];

  test('every admin key resolves to its exact English copy', () {
    for (final (key, actual, _, expected) in cases) {
      expect(actual, expected, reason: 'key $key');
    }
  });

  test('no admin key is left English in Arabic', () {
    for (final (key, english, arabic, _) in cases) {
      expect(arabic, isNotEmpty, reason: 'key $key is empty in Arabic');
      expect(arabic, isNot(english),
          reason: 'key $key is still English in Arabic');
    }
  });

  test('the placeholder and plural keys interpolate', () {
    expect(en.adminVariantStock(3), 'Stock: 3');
    expect(en.adminVariantOverride('120'), 'Override: 120');
    expect(en.adminLowStockTitle(5), 'Low stock (≤ 5)');
    expect(en.adminStockLeft(1), '1 left');
    expect(en.adminStockLeft(2), '2 left');
    expect(en.adminRevenueLastDays(14), 'Revenue — last 14 days');
    expect(en.adminUnitsShort(1), '1 u');
    expect(en.adminUnitsShort(4), '4 u');
    // Arabic must interpolate the same numbers, not drop them.
    expect(ar.adminVariantStock(3), contains('3'));
    expect(ar.adminLowStockTitle(5), contains('5'));
    expect(ar.adminRevenueLastDays(14), contains('14'));
  });
}
