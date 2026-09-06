import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/entities/order.dart';
import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';
import 'order_card.dart';

/// List of orders with an inviting empty state.
///
/// Empty tabs keep the tab's own message but gain a CTA back into the
/// catalog — "no active orders" alone dead-ends a new user on their
/// very first visit to this screen.
class OrderList extends StatelessWidget {
  const OrderList({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.isCompleted,
    required this.scheme,
  });
  final List<Order> orders;
  final String emptyMessage;
  final bool isCompleted;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      // The finish line for a first-time user: invite them to fill the
      // list instead of confirming it is empty. Outline style matches
      // the empty-state CTA contract (FeedbackView UX-039).
      return FeedbackView(
        type: FeedbackViewType.empty,
        icon: Icons.receipt_long_outlined,
        title: emptyMessage,
        body: context.l10n.emptyBody,
        actionLabel: context.l10n.continueShopping,
        onAction: () => context.go('/catalog'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => OrderCard(
        order: orders[i],
        isCompleted: isCompleted,
        scheme: scheme,
      ),
    );
  }
}
