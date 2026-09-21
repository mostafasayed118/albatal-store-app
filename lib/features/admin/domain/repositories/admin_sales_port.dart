import '../../../../core/error/result.dart';
import '../entities/admin_sales.dart';
import '../entities/low_stock_variant.dart';

/// Narrow port for the admin sales dashboard (ISP).
///
/// Split out of [AdminRepository] (audit). [AdminSalesDashboardCubit]
/// depends on this instead of the ~20-method facade.
abstract interface class AdminSalesPort {
  /// Aggregated sales overview for the last [days] days.
  ///
  /// Purely read-only: one bounded select over existing `orders` rows
  /// (with joined `order_items(product_name, quantity)`), aggregated
  /// client-side — no schema change and no write.
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14});

  /// Get low-stock variants below [threshold].
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  });
}
