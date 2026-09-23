import 'package:flutter/material.dart';

import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/l10n/money_copy.dart';
import '../../../../../shared/utils/app_date_formats.dart';
import '../../../domain/entities/admin_order.dart';
import '../../admin_order_status_label.dart';
import 'admin_detail_row.dart';

/// Order summary header for the admin detail view.
///
/// Extracted from `order_detail_cards.dart` verbatim.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final total = moneyText(l, order.total);
    // Localized fallback — a missing payment method used to render the
    // hardcoded English 'Unknown' on Arabic-visible paths.
    final paymentMethod = order.paymentMethod ?? l.paymentMethodUnknown;

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
                  child: Text(adminOrderStatusLabel(l, order.status),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const Divider(),
            AdminDetailRow(l.total, total),
            AdminDetailRow(l.paymentMethod, paymentMethod),
            AdminDetailRow(l.placedAt, _formatPlacedAt(order.placedAt, l)),
          ],
        ),
      ),
    );
  }

  /// Renders the server timestamp for the detail card. Month/day names
  /// follow the UI locale via intl (PR #41 pattern) — the old hardcoded
  /// `'yyyy-MM-dd HH:mm:ss'` was numeric-only, but the shared formatter
  /// keeps the admin card consistent with the customer order history.
  static String _formatPlacedAt(DateTime placedAt, AppLocalizations l) =>
      AppDateFormats.timestampSeconds(l.localeName).format(placedAt);
}
