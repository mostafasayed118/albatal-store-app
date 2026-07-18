import 'package:flutter/material.dart';

import 'empty_state_view.dart';
import 'order_card.dart';

/// List of orders with empty state.
class OrderList extends StatelessWidget {
  const OrderList({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.isCompleted,
    required this.scheme,
  });
  final List orders;
  final String emptyMessage;
  final bool isCompleted;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: emptyMessage,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => OrderCard(
        order: orders[i],
        isCompleted: isCompleted,
        scheme: scheme,
      ),
    );
  }
}
