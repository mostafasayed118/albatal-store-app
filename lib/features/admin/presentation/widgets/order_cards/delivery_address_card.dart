import 'package:flutter/material.dart';

import '../../../../../shared/extensions/build_context_x.dart';
import '../../../domain/entities/admin_order.dart';

/// Delivery address for the admin detail view.
///
/// Extracted from `order_detail_cards.dart` verbatim.
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
