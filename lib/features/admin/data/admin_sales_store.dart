import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_codes.dart';
import '../../../../core/error/result.dart';
import '../domain/entities/admin_sales.dart';
import '../domain/entities/low_stock_variant.dart';
import '../domain/repositories/admin_sales_port.dart';
import 'admin_mappers.dart';
import 'admin_sales_mappers.dart';

/// Sales dashboard and low-stock reads for [SupabaseAdminRepository].
///
/// Implements [AdminSalesPort] against Supabase; the facade keeps the
/// `AdminRepository` surface and delegates here unchanged.
final class SupabaseAdminSales implements AdminSalesPort {
  SupabaseAdminSales({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<Result<List<LowStockVariant>>> getLowStockProducts({
    int threshold = 5,
  }) =>
      Result.guard(() async {
        final response = await _client
            .rpc('get_low_stock_products', params: {'p_threshold': threshold});
        return AdminMappers.lowStockVariantsFromRows(response as List<dynamic>);
      }, 'Failed to load low stock products', code: kAdminLowStockLoadFailed);

  @override
  Future<Result<AdminSalesOverview>> getSalesOverview({int days = 14}) =>
      Result.guard(() async {
        final response = await _client.rpc(
          'admin_sales_overview',
          params: {'p_days': days},
        );
        return AdminSalesMappers.salesOverviewFromRpc(response);
      }, 'Failed to load sales overview', code: kAdminSalesLoadFailed);
}
