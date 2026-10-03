import '../../../../core/error/result.dart';
import '../entities/admin_wholesale_price_entry.dart';

/// Narrow port for the wholesale price-list management (ISP, 078 B2B).
///
/// Split out of [AdminRepository] like the other admin ports: the
/// price-list screen depends on this instead of the ~20-method facade.
abstract interface class AdminWholesalePricesPort {
  /// All wholesale list rows with the product display name attached.
  Future<Result<List<AdminWholesalePriceEntry>>> fetchWholesalePrices();

  /// Creates or updates the wholesale price for one product (078
  /// `admin_upsert_wholesale_price`; server rejects invalid tiers,
  /// non-positive prices and unknown products with 22023/P0002).
  Future<Result<void>> upsertWholesalePrice({
    required String productId,
    required int priceMinor,
  });

  /// Removes the wholesale price for one product (078
  /// `admin_delete_wholesale_price`; missing rows raise P0002).
  Future<Result<void>> deleteWholesalePrice(String productId);
}
