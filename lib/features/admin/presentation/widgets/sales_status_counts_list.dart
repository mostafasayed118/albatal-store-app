import 'package:flutter/material.dart';

import '../../domain/entities/admin_order.dart';
import '../../domain/entities/admin_sales.dart';

/// Order counts by status for the admin sales dashboard (#12), most
/// frequent first. Includes cancelled/refunded/unknown rows on purpose —
/// the status board is operational, unlike the revenue chart.
class SalesStatusCountsCard extends StatelessWidget {
  const SalesStatusCountsCard({super.key, required this.counts});

  final List<AdminSalesStatusCount> counts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Orders by status', style: textTheme.titleMedium),
          ),
          if (counts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child:
                  Text('No orders in this window', style: textTheme.bodySmall),
            )
          else
            for (final entry in counts)
              ListTile(
                dense: true,
                title: Text(_statusLabel(entry.status)),
                trailing: Text('${entry.count}'),
              ),
        ],
      ),
    );
  }

  String _statusLabel(AdminOrderStatus status) => switch (status) {
        AdminOrderStatus.unknown => 'Unknown',
        // Canonical DB names are lowercase; capitalize for display.
        _ => status.name[0].toUpperCase() + status.name.substring(1),
      };
}
