import 'admin_catalog_port.dart';
import 'admin_coupons_port.dart';
import 'admin_customers_port.dart';
import 'admin_orders_port.dart';
import 'admin_reviews_port.dart';
import 'admin_sales_port.dart';

/// Paging contract for the customer directory — canonical home is
/// [AdminCustomersPort]; re-exported here so existing importers keep
/// working while migrating to the narrow port.
export 'admin_customers_port.dart'
    show CustomerCursor, defaultCustomersPageSize;

/// Admin operations for order-queue and inventory management.
///
/// Domain port for the admin feature. The data layer implements this
/// against Supabase (see [SupabaseAdminRepository]); the presentation
/// layer (AdminCubit) depends only on this interface and on the typed
/// entities, never on `Map<String, dynamic>` rows or the Supabase SDK.
///
/// All reads return [Result] so failures are values handled at the
/// cubit boundary instead of thrown exceptions crossing layers.
///
/// Segregated (audit ISP): single-concern consumers depend on the narrow
/// ports ([AdminOrdersPort], [AdminCouponsPort], [AdminCustomersPort],
/// [AdminReviewsPort], [AdminSalesPort], [AdminCatalogPort]) instead of
/// this ~20-method facade. This interface extends them all, so existing
/// implementations and multi-concern consumers ([AdminCubit]) keep working
/// unchanged.
abstract interface class AdminRepository
    implements
        AdminOrdersPort,
        AdminCouponsPort,
        AdminCustomersPort,
        AdminReviewsPort,
        AdminSalesPort,
        AdminCatalogPort {
  /// Check if the current user is an admin.
  Future<bool> isCurrentUserAdmin();
}
