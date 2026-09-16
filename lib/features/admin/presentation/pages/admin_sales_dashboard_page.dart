import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/services/service_locator.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_sales_dashboard_cubit.dart';
import '../widgets/sales_low_stock_list.dart';
import '../widgets/sales_revenue_chart.dart';
import '../widgets/sales_status_counts_list.dart';
import '../widgets/sales_top_products_list.dart';

/// Admin sales dashboard (#12): read-only view over the last 14 days of
/// orders — revenue per day, best sellers, order counts by status — plus
/// the low-stock list.
///
/// The repository is constructor-injected via the router composition
/// root (audit P1), with an optional [cubit] seam for tests. Admin-only
/// copy is intentionally English in-code (no ARB keys), matching the
/// documented admin-surface convention.
class AdminSalesDashboardPage extends StatefulWidget {
  const AdminSalesDashboardPage({super.key, this.cubit, this.repository});

  final AdminSalesDashboardCubit? cubit;
  final AdminRepository? repository;

  @override
  State<AdminSalesDashboardPage> createState() =>
      _AdminSalesDashboardPageState();
}

class _AdminSalesDashboardPageState extends State<AdminSalesDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminSalesDashboardCubit>(
      create: (_) => (widget.cubit ??
          AdminSalesDashboardCubit(
              repository: widget.repository ?? getIt<AdminRepository>()))
        ..load(),
      child: BlocBuilder<AdminSalesDashboardCubit, AdminSalesDashboardState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sales Dashboard'),
              actions: [
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      context.read<AdminSalesDashboardCubit>().load(),
                ),
              ],
            ),
            body: switch (state.status) {
              AdminSalesDashboardStatus.loading =>
                const FeedbackView(type: FeedbackViewType.loading),
              AdminSalesDashboardStatus.error => FeedbackView(
                  type: FeedbackViewType.error,
                  // Admin-only copy stays English in-code (no ARB keys),
                  // matching this screen's documented convention.
                  title: 'Could not load sales',
                  body: state.errorMessage ?? 'Failed to load sales data.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      context.read<AdminSalesDashboardCubit>().load(),
                ),
              AdminSalesDashboardStatus.loaded =>
                _SalesDashboardBody(state: state),
            },
          );
        },
      ),
    );
  }
}

final class _SalesDashboardBody extends StatelessWidget {
  const _SalesDashboardBody({required this.state});

  final AdminSalesDashboardState state;

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    // The loaded status always carries an overview; this only keeps a
    // state-constructor misuse from crashing the widget tree.
    if (overview == null) {
      return const Center(child: Text('No sales data available.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SalesRevenueChartCard(points: overview.revenueByDay),
        SalesStatusCountsCard(counts: overview.statusCounts),
        SalesTopProductsCard(products: overview.topProducts),
        SalesLowStockCard(variants: state.lowStock),
      ],
    );
  }
}
