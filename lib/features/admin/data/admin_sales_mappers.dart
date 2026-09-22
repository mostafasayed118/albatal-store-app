import '../../../../core/utils/safe_parse.dart';
import '../domain/entities/admin_order.dart';
import '../domain/entities/admin_sales.dart';

/// Sales-dashboard aggregation over raw Supabase rows.
///
/// Extracted from [AdminMappers]; that facade still forwards
/// [salesOverviewFromRows] so the mapper import surface is unchanged.
class AdminSalesMappers {
  AdminSalesMappers._();

  /// Aggregates a windowed `orders` read (with joined
  /// `order_items(product_name, quantity)`) into an [AdminSalesOverview]
  /// for the sales dashboard (#12).
  ///
  /// The aggregation lives here so the repository stays a single bounded
  /// select and no schema/RPC is added. Defensive by contract: non-map
  /// rows and rows without a parseable `placed_at` are skipped entirely,
  /// non-map line items are ignored, and numeric fields degrade via
  /// [optInt]. [now] is injected so the day window is deterministic in
  /// tests.
  static AdminSalesOverview salesOverviewFromRows(
    List<dynamic> rows, {
    required int days,
    required DateTime now,
  }) {
    final window = days < 1 ? 1 : days;
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final firstDay = todayUtc.subtract(Duration(days: window - 1));
    final revenueByDay = <DateTime, int>{
      for (var i = 0; i < window; i++) firstDay.add(Duration(days: i)): 0,
    };
    final statusCounts = <AdminOrderStatus, int>{};
    final unitsByProduct = <String, int>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final placedRaw = row['placed_at'];
      final placedAt =
          placedRaw is String ? DateTime.tryParse(placedRaw) : null;
      if (placedAt == null) continue;
      final status = AdminOrderStatus.fromName(row['status']);
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;

      // Cancelled / refunded / unrecognized orders are listed in the
      // status counts but are not sales: they are excluded from both the
      // revenue timeline and the best-seller aggregation.
      final countsAsSale = status != AdminOrderStatus.cancelled &&
          status != AdminOrderStatus.refunded &&
          status != AdminOrderStatus.unknown;
      if (!countsAsSale) continue;

      // Day buckets use the timestamp's calendar date (as parsed from
      // the DB) so a day always means a calendar day on the chart.
      final day = DateTime.utc(placedAt.year, placedAt.month, placedAt.day);
      if (revenueByDay.containsKey(day)) {
        revenueByDay[day] = revenueByDay[day]! + (optInt(row, 'total') ?? 0);
      }

      final items = row['order_items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final quantity = optInt(item, 'quantity') ?? 0;
        if (quantity <= 0) continue;
        final name = optString(item, 'product_name') ?? 'Unknown';
        unitsByProduct[name] = (unitsByProduct[name] ?? 0) + quantity;
      }
    }

    final rankedProducts = unitsByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AdminSalesOverview(
      revenueByDay: [
        for (final entry in revenueByDay.entries)
          AdminRevenuePoint(day: entry.key, revenueMinor: entry.value),
      ],
      topProducts: [
        for (final entry in rankedProducts.take(5))
          AdminTopProduct(productName: entry.key, unitsSold: entry.value),
      ],
      statusCounts: [
        for (final entry in statusCounts.entries)
          AdminSalesStatusCount(status: entry.key, count: entry.value),
      ]..sort((a, b) => b.count.compareTo(a.count)),
    );
  }
}
