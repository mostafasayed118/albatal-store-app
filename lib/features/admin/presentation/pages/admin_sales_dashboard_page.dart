import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
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
/// root (audit P1), with an optional [cubit] seam for tests. Admin copy is
/// localized like the storefront (owner decision, part 34).
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
      // service_locator stays only as the test-only fallback above; the
      // router always injects [AdminSalesDashboardPage.repository].
      child: BlocBuilder<AdminSalesDashboardCubit, AdminSalesDashboardState>(
        // Audit (buildWhen): only the fields the cards render below gate
        // a rebuild — any future state field that no card reads stays
        // rebuild-free.
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.overview != current.overview ||
            previous.lowStock != current.lowStock ||
            previous.errorMessage != current.errorMessage,
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.salesDashboard),
              actions: [
                IconButton(
                  tooltip: context.l10n.adminReload,
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
                  title: context.l10n.adminSalesLoadFailed,
                  body: failureText(context.l10n,
                      code: state.errorCode,
                      message: state.errorMessage,
                      fallback: context.l10n.adminSalesLoadFailedBody),
                  actionLabel: context.l10n.retry,
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
