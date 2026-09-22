import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../cubit/admin_sales_dashboard_cubit.dart';
import 'sales_low_stock_list.dart';
import 'sales_revenue_chart.dart';
import 'sales_status_counts_list.dart';
import 'sales_top_products_list.dart';

/// Loaded sales-dashboard body — extracted from
/// `admin_sales_dashboard_page.dart` verbatim (was private
/// `_SalesDashboardBody`).
final class SalesDashboardBody extends StatelessWidget {
  const SalesDashboardBody({super.key, required this.state});

  final AdminSalesDashboardState state;

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    // The loaded status always carries an overview; this only keeps a
    // state-constructor misuse from crashing the widget tree.
    if (overview == null) {
      return Center(child: Text(context.l10n.adminNoSalesData));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => switch (i) {
        0 => SalesRevenueChartCard(points: overview.revenueByDay),
        1 => SalesStatusCountsCard(counts: overview.statusCounts),
        2 => SalesTopProductsCard(products: overview.topProducts),
        _ => SalesLowStockCard(variants: state.lowStock),
      },
    );
  }
}
