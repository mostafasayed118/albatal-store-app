import '../../../../core/entities/money.dart';
import '../../../../core/error/result.dart';
import '../entities/admin_catalog.dart';
import '../entities/admin_variant.dart';

/// Narrow port for admin catalog management (ISP).
///
/// Split out of [AdminRepository] (audit): catalog pages call these
/// directly, while single-concern cubits depend on their own ports. The
/// facade still extends this, so existing implementations keep working.
abstract interface class AdminCatalogPort {
  /// Create or update a product. Returns the product id.
  Future<Result<String>> adminUpsertProduct({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? composition,
    String? care,
    String? origin,
    int? widthCm,
    int? gsm,
    bool? sellByLength,
    double? minCutMeters,
    required String categoryId,
    required Money basePrice,
    required bool isActive,
  });

  /// Create or update a variant for a product. Returns the variant id.
  Future<Result<String>> adminUpsertVariant({
    required String productId,
    required String size,
    required String color,
    required int stock,
    Money? priceOverride,
  });

  /// Replace all images for a product with the given storage paths.
  Future<Result<void>> adminSetProductImages(
      String productId, List<String> storagePaths);

  /// Get all variants for [productId], ordered by size.
  Future<Result<List<AdminVariant>>> getVariants(String productId);

  /// Get ordered storage paths for a product's images.
  Future<Result<List<String>>> getProductImagePaths(String productId);

  /// Get every product for the catalog management list — including
  /// inactive rows, which are exactly what an admin needs to see and
  /// un-hide. Rows carry the joined category name for display.
  Future<Result<List<AdminProduct>>> getAllProducts();

  /// Single product for the edit-form prefill — avoids the
  /// fetch-all-and-scan the page previously did (audit 2026-09-13).
  /// Null when the id does not exist.
  Future<Result<AdminProduct?>> getProductById(String productId);

  /// Get every category for the catalog management list (read-only
  /// until a category write RPC exists).
  Future<Result<List<AdminCategory>>> getAllCategories();

  /// Update variant stock by variant id.
  Future<Result<void>> updateStock(String variantId, int newStock);
}
