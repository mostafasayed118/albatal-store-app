import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';

/// Admin order detail — view items, update status, add tracking.
class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  /// Status transition awaiting repository confirmation — drives the
  /// verified "updated" snackbar in the listener below.
  AdminOrderStatus? _awaitedStatus;

  /// Membership-tier change awaiting repository confirmation — same
  /// verified-ack contract as [_awaitedStatus] for the tier control.
  String? _awaitedTier;

  /// Shown under the tracking field when Confirm is pressed with an empty
  /// input; a shipment must always carry a tracking number. A [ValueNotifier]
  /// because the dialog is a separate route that does not rebuild when the
  /// page's setState runs.
  final List<ValueNotifier<String?>> _dialogErrors = [];

  ValueNotifier<String?> _newDialogError() {
    final notifier = ValueNotifier<String?>(null);
    _dialogErrors.add(notifier);
    return notifier;
  }

  /// Dialog field controllers awaiting disposal. Freed in [dispose]:
  /// disposing synchronously when `showDialog` returns pulls the rug
  /// from under the still-animating dialog's TextFields.
  final List<TextEditingController> _dialogControllers = [];

  TextEditingController _newDialogController() {
    final ctrl = TextEditingController();
    _dialogControllers.add(ctrl);
    return ctrl;
  }

  @override
  void dispose() {
    for (final ctrl in _dialogControllers) {
      ctrl.dispose();
    }
    for (final notifier in _dialogErrors) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadOrderDetails(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Short ids arrive via deep links (bad notifications, stale links);
    // substring(0, 8) on those used to throw a RangeError on first build.
    final shortId = widget.orderId.length <= 8
        ? widget.orderId
        : widget.orderId.substring(0, 8);
    return Scaffold(
      appBar: AppBar(title: Text('${l.order} #$shortId...')),
      body: BlocListener<AdminCubit, AdminState>(
        listener: (context, state) {
          // Optimistic acks lie when the transition fails; confirm only
          // what the repository actually did.
          if (state.status == AdminStatus.error) {
            if (_awaitedStatus != null || _awaitedTier != null) {
              showFloatingError(
                  context, state.errorMessage ?? context.l10n.errorTitle);
            }
            _awaitedStatus = null;
            _awaitedTier = null;
          } else if (state.status == AdminStatus.ready &&
              _awaitedStatus != null &&
              state.selectedOrder?.status == _awaitedStatus) {
            showConfirmation(context,
                context.l10n.orderStatusUpdatedTo(_awaitedStatus!.name));
            _awaitedStatus = null;
          } else if (state.status == AdminStatus.ready &&
              _awaitedTier != null &&
              state.selectedOrder?.customerTier == _awaitedTier) {
            showConfirmation(context, context.l10n.membershipTierUpdated);
            _awaitedTier = null;
          }
        },
        child: BlocBuilder<AdminCubit, AdminState>(
          builder: (context, state) {
            if (state.status == AdminStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final order = state.selectedOrder;
            if (order == null) {
              // Unknown id (stale deep link) must not dead-end: same
              // language as every other error state, with a way back.
              return FeedbackView(
                type: FeedbackViewType.error,
                title: l.orderNotFound,
                actionLabel: l.retry,
                onAction: () =>
                    context.read<AdminCubit>().loadOrderDetails(widget.orderId),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OrderStatusCard(order: order),
                const SizedBox(height: 16),
                _CustomerCard(
                  order: order,
                  onChangeTier: () => _showTierDialog(order),
                ),
                const SizedBox(height: 16),
                _OrderItemsCard(order: order),
                const SizedBox(height: 16),
                _DeliveryAddressCard(order: order),
                const SizedBox(height: 16),
                _FulfillmentActions(
                  order: order,
                  onStatusInvoked: (status) => _awaitedStatus = status,
                  onShipRequested: () => _showTrackingDialog(order),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Opens the tracking dialog for [order]. Lives on the page State (not
  /// the card) so the field controllers are disposed with the page instead
  /// of while the dialog's exit animation still has the TextFields mounted.
  Future<void> _showTrackingDialog(AdminOrder order) async {
    // Let the tapped row's frame finish rendering before pushing the dialog;
    // a slow device can otherwise starve the route's opening frame.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final trackingCtrl = _newDialogController();
    final courierCtrl = _newDialogController();
    final trackingError = _newDialogError();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.addTrackingDetails),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: courierCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.courierName),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String?>(
                valueListenable: trackingError,
                builder: (context, error, _) => TextField(
                  controller: trackingCtrl,
                  onChanged: (_) {
                    // First keystroke clears a visible rejection.
                    if (trackingError.value != null) {
                      trackingError.value = null;
                    }
                  },
                  decoration: InputDecoration(
                    labelText: context.l10n.trackingNumber,
                    errorText: error,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final tracking = trackingCtrl.text.trim();
              if (tracking.isEmpty) {
                hapticWarning();
                trackingError.value = context.l10n.fieldRequired;
                return;
              }
              hapticWarning();
              _awaitedStatus = AdminOrderStatus.shipped;
              context.read<AdminCubit>().updateOrderStatus(
                    order.id,
                    AdminOrderStatus.shipped,
                    trackingNumber: tracking,
                  );
              Navigator.pop(context);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  /// Opens the membership-tier dialog for [order]. Lifecycle belongs to
  /// the page State for the same reason as the tracking dialog: this is a
  /// separate route and must not be disposed mid-animation.
  Future<void> _showTierDialog(AdminOrder order) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final l = context.l10n;
    // Captured from the page State's context BEFORE the dialog route is
    // pushed: the dialog builds above the BlocProvider, so closures inside
    // it must not resolve the cubit through their own context.
    final cubit = context.read<AdminCubit>();
    final currentTier = order.customerTier ?? 'standard';
    String selection = currentTier;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.changeMembershipTier),
          content: RadioGroup<String>(
            groupValue: selection,
            onChanged: (value) {
              if (value != null) setDialogState(() => selection = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'standard',
                  title: Text(l.standardMember),
                ),
                RadioListTile<String>(
                  value: 'premium',
                  title: Text(l.premiumMember),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final profileId = order.customerId;
                if (profileId == null) return;
                Navigator.pop(dialogContext);
                if (selection == currentTier) return;
                // Optimistic nothing; the ack below is earned by the
                // repository result (see the listener in build).
                hapticWarning();
                _awaitedTier = selection;
                cubit.setMembershipTier(profileId, selection);
              },
              child: Text(l.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  const _OrderStatusCard({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = order.total.format();
    final paymentMethod = order.paymentMethod ?? 'Unknown';

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
            _DetailRow(l.placedAt, _formatPlacedAt(order.placedAt)),
          ],
        ),
      ),
    );
  }

  /// Renders the server timestamp for the detail card.
  static String _formatPlacedAt(DateTime placedAt) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(placedAt);
}

/// Customer identity + membership tier for the order's profile, with the
/// admin-side tier control (migration 046). Premium styling mirrors the
/// customer-facing Profile badge so both sides agree on what premium
/// looks like. The control renders only when the detail query supplied a
/// profile id — without it the RPC would have nothing to address.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order, required this.onChangeTier});

  final AdminOrder order;
  final VoidCallback onChangeTier;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isPremium = order.customerTier == 'premium';
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

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

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

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({required this.order});

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
class _FulfillmentActions extends StatelessWidget {
  const _FulfillmentActions({
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
