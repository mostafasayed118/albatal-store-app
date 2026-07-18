import 'package:flutter/material.dart';

import '../../../../core/entities/address.dart';
import '../../../../generated/l10n/app_localizations.dart';

/// Shows selected shipping address in order review.
class OrderReview extends StatelessWidget {
  const OrderReview({super.key, required this.address, required this.l});
  final Address address;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(l.shippingTo,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 4),
            Text(address.recipient,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${address.line}, ${address.city}, ${address.country}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
