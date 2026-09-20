import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_sales.dart';
import '../admin_order_status_label.dart';

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
            child: Text(context.l10n.adminOrdersByStatus,
                style: textTheme.titleMedium),
          ),
          if (counts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(context.l10n.adminNoOrdersInWindow,
                  style: textTheme.bodySmall),
            )
          else
            for (final entry in counts)
              ListTile(
                dense: true,
                title: Text(adminOrderStatusLabel(context.l10n, entry.status)),
                trailing: Text('${entry.count}'),
              ),
        ],
      ),
    );
  }
}
