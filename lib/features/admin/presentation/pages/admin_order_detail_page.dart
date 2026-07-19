import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/admin_cubit.dart';

/// Admin order detail — view items, update status, add tracking.
class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadOrderDetails(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text('${l.order} #${widget.orderId.substring(0, 8)}...')),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state.status == AdminStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = state.selectedOrder;
          if (order == null) {
            return Center(child: Text(l.orderNotFound));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _OrderStatusCard(order: order),
              const SizedBox(height: 16),
              _OrderItemsCard(order: order),
              const SizedBox(height: 16),
              _DeliveryAddressCard(order: order),
              const SizedBox(height: 16),
              _FulfillmentActions(order: order),
            ],
          );
        },
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = order['status'] as String? ?? 'unknown';
    final total = Money(order['total'] as int? ?? 0).format();
    final paymentMethod = order['payment_method'] as String? ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.orderDetails,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const Divider(),
            _DetailRow(l.total, '$total EGY'),
            _DetailRow(l.paymentMethod, paymentMethod),
            _DetailRow(l.placedAt,
                order['placed_at']?.toString().substring(0, 19) ?? ''),
          ],
        ),
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = (order['order_items'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.items, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['product_name'] ?? 'Unknown'),
                  subtitle: Text('${item['size']} / ${item['color']}'),
                  trailing: Text(
                      '×${item['quantity']} · ${Money(item['unit_price'] as int? ?? 0).format()}'),
                )),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final address = order['address_snapshot'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.shippingAddress,
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            if (address != null) ...[
              Text(address['recipient'] ?? ''),
              Text('${address['line'] ?? ''}, ${address['city'] ?? ''}'),
              Text(address['country'] ?? ''),
            ] else
              Text(l.noAddressProvided),
          ],
        ),
      ),
    );
  }
}

class _FulfillmentActions extends StatelessWidget {
  const _FulfillmentActions({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = order['status'] as String? ?? 'unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.fulfillmentActions,
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            if (status == 'placed') ...[
              _ActionTile(
                icon: Icons.autorenew,
                title: l.confirmOrder,
                onTap: () => _updateStatus(context, 'processing'),
              ),
              _ActionTile(
                icon: Icons.cancel,
                title: l.cancelOrder,
                color: Theme.of(context).colorScheme.error,
                onTap: () => _updateStatus(context, 'cancelled'),
              ),
            ] else if (status == 'processing') ...[
              _ActionTile(
                icon: Icons.local_shipping,
                title: l.markAsShipped,
                onTap: () => _showTrackingDialog(context),
              ),
              _ActionTile(
                icon: Icons.cancel,
                title: l.cancelOrder,
                color: Theme.of(context).colorScheme.error,
                onTap: () => _updateStatus(context, 'cancelled'),
              ),
            ] else if (status == 'shipped') ...[
              _ActionTile(
                icon: Icons.check_circle,
                title: l.markAsDelivered,
                onTap: () => _updateStatus(context, 'delivered'),
              ),
            ] else ...[
              Text(l.noActionsAvailable),
            ],
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, String status) {
    context.read<AdminCubit>().updateOrderStatus(
          order['id'] as String,
          status,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order status updated to $status')),
    );
  }

  void _showTrackingDialog(BuildContext context) {
    final trackingCtrl = TextEditingController();
    final courierCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Tracking Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courierCtrl,
              decoration: const InputDecoration(labelText: 'Courier Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: trackingCtrl,
              decoration: const InputDecoration(labelText: 'Tracking Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<AdminCubit>().updateOrderStatus(
                    order['id'] as String,
                    'shipped',
                    trackingNumber: trackingCtrl.text,
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order marked as shipped')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
