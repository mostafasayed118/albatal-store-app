import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/admin_order.dart';

/// Line items for the admin detail view.
///
/// Extracted from `order_detail_cards.dart` verbatim.
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
