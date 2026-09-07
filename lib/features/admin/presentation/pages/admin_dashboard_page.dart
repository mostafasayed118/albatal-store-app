import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';

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
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == AdminStatus.error) {
            return FeedbackView(
              type: FeedbackViewType.error,
              body: state.errorMessage,
              // Reload the data; the old handler only cleared the error
              // flag, leaving the dashboard empty on the "retry".
              onAction: () => context.read<AdminCubit>()
                ..clearError()
                ..loadOrders()
                ..loadLowStockProducts()
                ..checkAdmin(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                title: l.totalOrders,
                value: '${state.orders.length}',
                icon: Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: l.pendingOrders,
                value:
                    '${state.orders.where((o) => o.status == AdminOrderStatus.placed).length}',
                icon: Icons.pending_actions,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: l.lowStock,
                value: '${state.lowStockProducts.length}',
                icon: Icons.warning_amber,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(l.quickActions,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.receipt_long,
                title: l.orderQueue,
                subtitle: l.viewAllOrders,
                onTap: () => context.push('/admin/orders'),
              ),
              _ActionTile(
                icon: Icons.inventory_2_outlined,
                title: l.inventory,
                subtitle: l.manageStock,
                onTap: () => context.push('/admin/inventory'),
              ),
              _ActionTile(
                icon: Icons.shopping_bag_outlined,
                title: l.catalog,
                subtitle: l.manageProducts,
                onTap: () => context.push('/admin/catalog'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(context.directionalTrailingIcon),
        onTap: onTap,
      ),
    );
  }
}
