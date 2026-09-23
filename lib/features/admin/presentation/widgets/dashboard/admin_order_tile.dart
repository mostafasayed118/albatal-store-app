import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/l10n/money_copy.dart';
import '../../../../../shared/routing/app_routes.dart';
import '../../../domain/entities/admin_order.dart';

/// Admin order-queue row — extracted from `admin_orders_page.dart`
/// verbatim (was private `_OrderTile`).
///
/// Public so other admin surfaces (search, dashboard recents) can reuse
/// the exact row treatment.
final class AdminOrderTile extends StatelessWidget {
  const AdminOrderTile({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final status = order.status;
    final total = moneyText(l10n, order.total);
    final customerName = order.customerName ?? l10n.unknown;
    final itemCount = order.itemCount ?? order.items.length;

    return Card(
      child: ListTile(
        onTap: () => context.push(Routes.adminOrder(order.id)),
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
        subtitle: Text('$customerName · $itemCount ${l10n.items}'),
        trailing: Icon(context.directionalTrailingIcon),
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
