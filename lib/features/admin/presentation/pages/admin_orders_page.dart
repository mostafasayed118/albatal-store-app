import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';

/// Admin order queue — filter by status, view orders.
class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.orderQueue),
        actions: [
          PopupMenuButton<AdminOrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              context.read<AdminCubit>().loadOrders(status: status);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(l.allOrders)),
              PopupMenuItem(
                  value: AdminOrderStatus.placed, child: Text(l.placed)),
              PopupMenuItem(
                  value: AdminOrderStatus.processing,
                  child: Text(l.processing)),
              PopupMenuItem(
                  value: AdminOrderStatus.shipped, child: Text(l.shipped)),
              PopupMenuItem(
                  value: AdminOrderStatus.delivered, child: Text(l.delivered)),
              PopupMenuItem(
                  value: AdminOrderStatus.cancelled, child: Text(l.cancelled)),
            ],
          ),
        ],
      ),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state.status == AdminStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = state.filteredOrders;
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l.noOrdersFound),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderTile(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final status = order.status;
    final total = order.total.format();
    final customerName = order.customerName ?? 'Unknown';
    final itemCount = order.itemCount ?? order.items.length;

    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/orders/${order.id}'),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status, scheme).withValues(alpha: .12),
          child: Icon(_statusIcon(status),
              color: _statusColor(status, scheme), size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text('#${order.shortId}...',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(total,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: scheme.primary)),
          ],
        ),
        subtitle: Text('$customerName · $itemCount ${l.items}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Color _statusColor(AdminOrderStatus status, ColorScheme scheme) {
    switch (status) {
      case AdminOrderStatus.placed:
        return scheme.secondary;
      case AdminOrderStatus.pending:
      case AdminOrderStatus.paid:
      case AdminOrderStatus.processing:
        return scheme.tertiary;
      case AdminOrderStatus.shipped:
        return scheme.primary;
      case AdminOrderStatus.delivered:
        // Success tone from the token palette — never a raw Material
        // color (dark-mode + contrast safe, single-accent rule).
        return scheme.tertiary;
      case AdminOrderStatus.cancelled:
      case AdminOrderStatus.refunded:
        return scheme.error;
      case AdminOrderStatus.unknown:
        return scheme.outline;
    }
  }

  IconData _statusIcon(AdminOrderStatus status) {
    switch (status) {
      case AdminOrderStatus.placed:
        return Icons.receipt_long;
      case AdminOrderStatus.pending:
      case AdminOrderStatus.paid:
      case AdminOrderStatus.processing:
        return Icons.autorenew;
      case AdminOrderStatus.shipped:
        return Icons.local_shipping;
      case AdminOrderStatus.delivered:
        return Icons.check_circle;
      case AdminOrderStatus.cancelled:
      case AdminOrderStatus.refunded:
        return Icons.cancel;
      case AdminOrderStatus.unknown:
        return Icons.help_outline;
    }
  }
}
