import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
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
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              context.read<AdminCubit>().loadOrders(status: status);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(l.allOrders)),
              PopupMenuItem(value: 'placed', child: Text(l.placed)),
              PopupMenuItem(value: 'processing', child: Text(l.processing)),
              PopupMenuItem(value: 'shipped', child: Text(l.shipped)),
              PopupMenuItem(value: 'delivered', child: Text(l.delivered)),
              PopupMenuItem(value: 'cancelled', child: Text(l.cancelled)),
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
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? 'unknown';
    final total = Money(order['total'] as int? ?? 0).format();
    final customerName = order['profiles']?['full_name'] as String? ?? 'Unknown';
    final itemCount = (order['order_items'] as List?)?.length ?? 0;

    return Card(
      child: ListTile(
        onTap: () => context.push('/admin/orders/${order['id']}'),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status, scheme).withValues(alpha: .12),
          child: Icon(_statusIcon(status),
              color: _statusColor(status, scheme), size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text('#${order['id'].toString().substring(0, 8)}...',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('$total EGY',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: scheme.primary)),
          ],
        ),
        subtitle: Text('$customerName · $itemCount ${l.items}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'placed':
        return scheme.secondary;
      case 'processing':
        return scheme.tertiary;
      case 'shipped':
        return scheme.primary;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return scheme.error;
      default:
        return scheme.outline;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'placed':
        return Icons.receipt_long;
      case 'processing':
        return Icons.autorenew;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}
