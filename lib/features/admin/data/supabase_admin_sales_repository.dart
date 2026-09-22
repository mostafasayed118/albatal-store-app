import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_sales.dart';
import '../domain/entities/low_stock_variant.dart';
import '../domain/repositories/admin_sales_port.dart';
import 'admin_mappers.dart';

/// Supabase-backed implementation of [AdminSalesPort] — the sales-dashboard
/// slice of the former 22-method `SupabaseAdminRepository` god-class
/// (audit 2026-09-21, P1 split).
final class SupabaseAdminSalesRepository implements AdminSalesPort {
  SupabaseAdminSalesRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) =>
      Result.guard(() async {
        // Read-only dashboard aggregation (#12): a single bounded select
        // over existing orders rows with the joined line-item columns the
        // detail query already uses. Client-side aggregation keeps the
        // schema untouched; the limit keeps a burst of orders from
        // stalling the dashboard (same bounded-read discipline as
        // getAllProducts).
        final now = DateTime.now();
        final firstDay = DateTime.utc(now.year, now.month, now.day).subtract(
          Duration(days: (days < 1 ? 1 : days) - 1),
        );
        final rows = await _client
            .from('orders')
            .select('id, status, total, placed_at, '
                'order_items(product_name, quantity)')
            .gte('placed_at', firstDay.toIso8601String())
            .order('placed_at')
            .limit(1000);
        return AdminMappers.salesOverviewFromRows(
          rows as List<dynamic>,
          days: days,
          now: now,
        );
      }, 'Failed to load sales overview', code: kAdminSalesLoadFailed);

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  }) =>
      Result.guard(() async {
        final response = await _client
            .rpc('get_low_stock_products', params: {'p_threshold': threshold});
        return AdminMappers.lowStockVariantsFromRows(response as List<dynamic>);
      }, 'Failed to load low stock products', code: kAdminLowStockLoadFailed);
}
