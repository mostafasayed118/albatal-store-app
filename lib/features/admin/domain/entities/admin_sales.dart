// Read-only sales-analytics read models for the admin sales dashboard
// (issue #12). All aggregation happens client-side in the data layer
// over existing `orders` / `order_items` rows — no schema or RPC is
// added; these classes are pure presentation-facing views.
library;

import 'package:equatable/equatable.dart';

import 'admin_order.dart';

/// One day of the revenue timeline.
///
/// [day] is a UTC calendar date (midnight) so day buckets stay stable
/// regardless of the device timezone; [revenueMinor] is the sum of the
/// day's order totals in integer minor units (the same integer-minor
/// convention as `Money`) excluding cancelled/refunded orders.
final class AdminRevenuePoint extends Equatable {
  const AdminRevenuePoint({required this.day, required this.revenueMinor});

  final DateTime day;
  final int revenueMinor;

  @override
  List<Object?> get props => [day, revenueMinor];
}

/// A best-selling product aggregated by units sold across order line
/// items. [unitsSold] counts units, not orders.
final class AdminTopProduct extends Equatable {
  const AdminTopProduct({required this.productName, required this.unitsSold});

  final String productName;
  final int unitsSold;

  @override
  List<Object?> get props => [productName, unitsSold];
}

/// Count of orders sharing one [AdminOrderStatus] within the window.
final class AdminSalesStatusCount extends Equatable {
  const AdminSalesStatusCount({required this.status, required this.count});

  final AdminOrderStatus status;
  final int count;

  @override
  List<Object?> get props => [status, count];
}

/// Everything the admin sales dashboard renders in one immutable read
/// model, so the cubit emits a single atomic loaded state.
final class AdminSalesOverview extends Equatable {
  const AdminSalesOverview({
    required this.revenueByDay,
    required this.topProducts,
    required this.statusCounts,
  });

  /// Exactly one point per day of the requested window, oldest first,
  /// zero-filled — the chart never needs to compute gaps itself.
  final List<AdminRevenuePoint> revenueByDay;

  /// Best sellers by units sold, best first, capped at 5.
  final List<AdminTopProduct> topProducts;

  /// Order counts per status within the window, most frequent first.
  final List<AdminSalesStatusCount> statusCounts;

  @override
  List<Object?> get props => [revenueByDay, topProducts, statusCounts];
}
