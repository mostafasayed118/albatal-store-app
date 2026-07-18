import 'package:flutter/material.dart';

import '../../../../generated/l10n/app_localizations.dart';
import 'info_card.dart';

/// Express delivery and returns info cards.
class DeliveryInfo extends StatelessWidget {
  const DeliveryInfo({super.key, required this.l, required this.scheme});
  final AppLocalizations l;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoCard(
          icon: Icons.local_shipping_outlined,
          title: l.expressDelivery,
          subtitle: l.expressDeliveryBody,
          color: scheme.primary,
        ),
        const SizedBox(height: 8),
        InfoCard(
          icon: Icons.replay_outlined,
          title: l.returns,
          subtitle: l.returnsBody,
          color: scheme.secondary,
        ),
      ],
    );
  }
}
