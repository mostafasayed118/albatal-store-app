import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/l10n/failure_copy.dart';
import '../../../../shared/routing/app_routes.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';
import '../widgets/dashboard/admin_action_tile.dart';
import '../widgets/dashboard/admin_stat_card.dart';

/// Admin dashboard home — shows order stats and quick actions.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    // The dashboard previously only rendered whatever sat in the cubit;
    // a fresh session landed on permanently-empty stats. Load on entry,
    // like every other admin surface. Sequential so a non-admin's final
    // state is the access-denied error, not a race between loaders.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cubit = context.read<AdminCubit>();
      await cubit.loadOrders();
      if (!mounted) return;
      await cubit.loadLowStockProducts();
      if (!mounted) return;
      await cubit.checkAdmin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminDashboard)),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state.status == AdminStatus.loading) {
            return const FeedbackView(type: FeedbackViewType.loading);
          }
          if (state.status == AdminStatus.error) {
            return FeedbackView(
              type: FeedbackViewType.error,
              body: failureText(context.l10n,
                  code: state.errorCode,
                  message: state.errorMessage,
                  fallback: context.l10n.errorTitle),
              // Reload the data; the old handler only cleared the error
              // flag, leaving the dashboard empty on the "retry".
              onAction: () => context.read<AdminCubit>()
                ..clearError()
                ..loadOrders()
                ..loadLowStockProducts()
                ..checkAdmin(),
            );
          }
          // Lazy build (audit): same children as before, inflated on demand.
          final children = <Widget>[
            AdminStatCard(
              title: l.totalOrders,
              value: '${state.orders.length}',
              icon: Icons.receipt_long,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            AdminStatCard(
              title: l.pendingOrders,
              value:
                  '${state.orders.where((o) => o.status == AdminOrderStatus.placed).length}',
              icon: Icons.pending_actions,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            AdminStatCard(
              title: l.lowStock,
              value: '${state.lowStockProducts.length}',
              icon: Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(l.quickActions, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AdminActionTile(
              icon: Icons.receipt_long,
              title: l.orderQueue,
              subtitle: l.viewAllOrders,
              onTap: () => context.push(Routes.adminOrders),
            ),
            AdminActionTile(
              icon: Icons.inventory_2_outlined,
              title: l.inventory,
              subtitle: l.manageStock,
              onTap: () => context.push(Routes.adminInventory),
            ),
            AdminActionTile(
              icon: Icons.shopping_bag_outlined,
              title: l.catalog,
              subtitle: l.manageProducts,
              onTap: () => context.push(Routes.adminCatalog),
            ),
            // Promo codes (§8): the page, cubit and repository methods
            // shipped with no destination, so a coupon could be redeemed
            // at checkout but never created. Both labels already exist in
            // EN + AR, so no ARB change was needed.
            AdminActionTile(
              icon: Icons.local_offer_outlined,
              title: l.adminCoupons,
              subtitle: l.adminAddCoupon,
              onTap: () => context.push(Routes.adminCoupons),
            ),
          ];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            itemBuilder: (_, i) => children[i],
          );
        },
      ),
    );
  }
}
