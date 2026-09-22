import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/components/feedback.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/admin_order.dart';
import '../../cubit/admin_cubit.dart';
import 'fulfillment_action_tile.dart';

/// Status-transition actions for the detail view, derived from the typed
/// [AdminOrder] guards (`canConfirm`, `canCancel`, `canShip`, `canDeliver`)
/// instead of string comparisons scattered through the UI.
///
/// Extracted from `order_detail_cards.dart` verbatim.
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
        FulfillmentActionTile(
          icon: Icons.autorenew,
          title: l.confirmOrder,
          onTap: () => _updateStatus(context, AdminOrderStatus.processing),
        ),
      if (order.canShip)
        FulfillmentActionTile(
          icon: Icons.local_shipping,
          title: l.markAsShipped,
          onTap: onShipRequested,
        ),
      if (order.canDeliver)
        FulfillmentActionTile(
          icon: Icons.check_circle,
          title: l.markAsDelivered,
          onTap: () => _updateStatus(context, AdminOrderStatus.delivered),
        ),
      if (order.canCancel)
        FulfillmentActionTile(
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
