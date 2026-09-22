import 'package:flutter/material.dart';

import '../../../../../core/entities/money.dart';
import '../../../../../generated/l10n/app_localizations.dart';
import '../../../../../shared/components/app_card.dart';
import 'server_total_row.dart';

export 'server_total_row.dart';

/// Server-confirmed totals card — extracted verbatim from
/// `checkout_page.dart` (was private `_ServerTotalsCard`).
final class CheckoutServerTotalsCard extends StatelessWidget {
  const CheckoutServerTotalsCard({
    super.key,
    required this.l10n,
    required this.scheme,
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final Money? subtotal;
  final Money? shipping;
  final Money? total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.serverConfirmedTotals,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            CheckoutServerTotalRow(label: l10n.subtotal, value: subtotal),
            CheckoutServerTotalRow(label: l10n.shipping, value: shipping),
            CheckoutServerTotalRow(label: l10n.total, value: total),
          ],
        ),
      ),
    );
  }
}
