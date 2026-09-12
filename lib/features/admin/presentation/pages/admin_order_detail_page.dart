import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/components/feedback.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_cubit.dart';
import '../widgets/dialog_controllers.dart';
import '../widgets/order_detail_cards.dart';

/// Admin order detail — view items, update status, add tracking.
class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage>
    with DialogControllers {
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

  @override
  void dispose() {
    // Dialog controllers free via the shared mixin (never synchronously
    // when showDialog returns — the exit animation still has them mounted).
    disposeDialogControllers();
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
    final l10n = context.l10n;
    // Short ids arrive via deep links (bad notifications, stale links);
    // substring(0, 8) on those used to throw a RangeError on first build.
    final shortId = widget.orderId.length <= 8
        ? widget.orderId
        : widget.orderId.substring(0, 8);
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.order} #$shortId...')),
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
                title: l10n.orderNotFound,
                actionLabel: l10n.retry,
                onAction: () =>
                    context.read<AdminCubit>().loadOrderDetails(widget.orderId),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OrderStatusCard(order: order),
                const SizedBox(height: 16),
                CustomerCard(
                  order: order,
                  onChangeTier: () => _showTierDialog(order),
                ),
                const SizedBox(height: 16),
                OrderItemsCard(order: order),
                const SizedBox(height: 16),
                DeliveryAddressCard(order: order),
                const SizedBox(height: 16),
                FulfillmentActions(
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
    final trackingCtrl = newDialogController();
    final courierCtrl = newDialogController();
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
