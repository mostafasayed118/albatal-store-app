import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/admin_cubit.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminCubit>().loadDashboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminDashboard)),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          switch (state.status) {
            case AdminStatus.initial:
            case AdminStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case AdminStatus.unauthorized:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(l.notAvailableTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/home'),
                        child: Text(l.returnHome),
                      ),
                    ],
                  ),
                ),
              );

            case AdminStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? l.errorTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            context.read<AdminCubit>().loadDashboard(),
                        child: Text(l.retry),
                      ),
                    ],
                  ),
                ),
              );

            case AdminStatus.ready:
              if (state.orders.isEmpty && state.lowStockProducts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(l.emptyTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
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
                        '${state.orders.where((o) => o['status'] == 'placed').length}',
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
          }
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
        trailing: Icon(Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
