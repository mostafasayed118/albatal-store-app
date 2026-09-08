import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/entities/profile.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';

/// Order summary header for the admin detail view.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = order.total.format();
    // Localized fallback — a missing payment method used to render the
    // hardcoded English 'Unknown' on Arabic-visible paths.
    final paymentMethod = order.paymentMethod ?? l.paymentMethodUnknown;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(order.status.name.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const Divider(),
            _DetailRow(l.total, total),
            _DetailRow(l.paymentMethod, paymentMethod),
            _DetailRow(l.placedAt, _formatPlacedAt(order.placedAt, l)),
          ],
        ),
      ),
    );
  }

  /// Renders the server timestamp for the detail card. Month/day names
  /// follow the UI locale via intl (PR #41 pattern) — the old hardcoded
  /// `'yyyy-MM-dd HH:mm:ss'` was numeric-only, but the shared formatter
  /// keeps the admin card consistent with the customer order history.
  static String _formatPlacedAt(DateTime placedAt, AppLocalizations l) =>
      DateFormat('yyyy-MM-dd HH:mm:ss', l.localeName).format(placedAt);
}

/// Customer identity + membership tier for the order's profile, with the
/// admin-side tier control (migration 046). Premium styling mirrors the
/// customer-facing Profile badge so both sides agree on what premium
/// looks like. The control renders only when the detail query supplied a
/// profile id — without it the RPC would have nothing to address.
class CustomerCard extends StatelessWidget {
  const CustomerCard(
      {super.key, required this.order, required this.onChangeTier});

  final AdminOrder order;
  final VoidCallback onChangeTier;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Typed tier decode (shared with Profile.fromRow) instead of a raw
    // `== 'premium'` string compare scattered through the UI.
    final isPremium = membershipTierFromServerValue(order.customerTier) ==
        MembershipTier.premium;
    final accent = isPremium
        ? AppColors.gold
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.customer, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(order.customerName ?? '—'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPremium ? Icons.workspace_premium : Icons.person_outline,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isPremium ? l.premiumMember : l.standardMember,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (order.customerId != null)
                  TextButton.icon(
                    onPressed: onChangeTier,
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(l.change),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Line items for the admin detail view.
class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = order.items;

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
                  title: Text(item.productName),
                  subtitle: Text('${item.size} / ${item.color}'),
                  trailing:
                      Text('×${item.quantity} · ${item.unitPrice.format()}'),
                )),
          ],
        ),
      ),
    );
  }
}

/// Delivery address for the admin detail view.
class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final address = order.address;

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
              Text(address.recipient),
              Text(address.singleLine),
              Text(address.country),
            ] else
              Text(l.noAddressProvided),
          ],
        ),
      ),
    );
  }
}

/// Status-transition actions for the detail view, derived from the typed
/// [AdminOrder] guards (`canConfirm`, `canCancel`, `canShip`, `canDeliver`)
/// instead of string comparisons scattered through the UI.
class FulfillmentActions extends StatelessWidget {
  const FulfillmentActions({
    super.key,
    required this.order,
    required this.onStatusInvoked,
    required this.onShipRequested,
  });

  final AdminOrder order;

  /// Notified when a transition is requested so the page's listener can
  /// verify the repository result before confirming it.
  final ValueChanged<AdminOrderStatus> onStatusInvoked;

  /// Opens the tracking dialog on the page State, which owns the dialog's
  /// field controller lifecycle.
  final VoidCallback onShipRequested;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    final actions = <Widget>[
      if (order.canConfirm)
        _ActionTile(
          icon: Icons.autorenew,
          title: l.confirmOrder,
          onTap: () => _updateStatus(context, AdminOrderStatus.processing),
        ),
      if (order.canShip)
        _ActionTile(
          icon: Icons.local_shipping,
          title: l.markAsShipped,
          onTap: onShipRequested,
        ),
      if (order.canDeliver)
        _ActionTile(
          icon: Icons.check_circle,
          title: l.markAsDelivered,
          onTap: () => _updateStatus(context, AdminOrderStatus.delivered),
        ),
      if (order.canCancel)
        _ActionTile(
          icon: Icons.cancel,
          title: l.cancelOrder,
          color: Theme.of(context).colorScheme.error,
          onTap: () => _updateStatus(context, AdminOrderStatus.cancelled),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.fulfillmentActions,
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...actions,
            if (actions.isEmpty) Text(l.noActionsAvailable),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, AdminOrderStatus status) {
    // The tap acknowledges itself immediately; the "updated" confirmation
    // is earned by the repository result (see the listener in build), so
    // a failed transition never claims success.
    hapticWarning();
    onStatusInvoked(status);
    context.read<AdminCubit>().updateOrderStatus(
          order.id,
          status,
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
      trailing: Icon(context.directionalTrailingIcon),
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
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
