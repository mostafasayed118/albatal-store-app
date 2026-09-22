import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/repositories/admin_sales_port.dart';
import '../cubit/admin_sales_dashboard_cubit.dart';
import '../widgets/admin_error_feedback.dart';
import '../widgets/sales_dashboard_body.dart';

/// Admin sales dashboard (#12): read-only view over the last 14 days of
/// orders — revenue per day, best sellers, order counts by status — plus
/// the low-stock list.
///
/// The repository is constructor-injected via the router composition
/// root (audit P1), with an optional [cubit] seam for tests. Admin copy is
/// localized like the storefront (owner decision, part 34).
class AdminSalesDashboardPage extends StatefulWidget {
  const AdminSalesDashboardPage({super.key, this.cubit, this.repository})
      : assert(cubit != null || repository != null,
            'Provide either cubit or repository.');

  final AdminSalesDashboardCubit? cubit;
  final AdminSalesPort? repository;

  @override
  State<AdminSalesDashboardPage> createState() =>
      _AdminSalesDashboardPageState();
}

class _AdminSalesDashboardPageState extends State<AdminSalesDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminSalesDashboardCubit>(
      create: (_) => (widget.cubit ??
          AdminSalesDashboardCubit(repository: widget.repository!))
        ..load(),
      // The router always injects [repository] (or a [cubit] in tests) —
      // the view never service-locates (audit DIP: no getIt in views).
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
              AdminSalesDashboardStatus.error => AdminErrorFeedback(
                  errorCode: state.errorCode,
                  errorMessage: state.errorMessage,
                  title: context.l10n.adminSalesLoadFailed,
                  fallback: context.l10n.adminSalesLoadFailedBody,
                  actionLabel: context.l10n.retry,
                  onRetry: () =>
                      context.read<AdminSalesDashboardCubit>().load(),
                ),
              AdminSalesDashboardStatus.loaded =>
                SalesDashboardBody(state: state),
            },
          );
        },
      ),
    );
  }
}
