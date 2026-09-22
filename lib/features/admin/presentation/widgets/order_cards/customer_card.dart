import 'package:flutter/material.dart';

import '../../../../../core/entities/profile.dart';
import '../../../../../shared/extensions/build_context_x.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/entities/admin_order.dart';

/// Customer identity + membership tier for the order's profile, with the
/// admin-side tier control (migration 046). Premium styling mirrors the
/// customer-facing Profile badge so both sides agree on what premium
/// looks like. The control renders only when the detail query supplied a
/// profile id — without it the RPC would have nothing to address.
///
/// Extracted from `order_detail_cards.dart` verbatim.
class CustomerCard extends StatelessWidget {
  const CustomerCard(
      {super.key, required this.order, required this.onChangeTier});

  final AdminOrder order;
  final VoidCallback onChangeTier;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Typed tier decode (shared with ProfileCodec.fromRow) instead of a raw
    // `== 'premium'` string compare scattered through the UI.
    final isPremium = membershipTierFromServerValue(order.customerTier) ==
        MembershipTier.premium;
    final accent = isPremium
        ? AppColors.gold
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.customer, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(order.customerName ?? '—'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPremium ? Icons.workspace_premium : Icons.person_outline,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isPremium ? l.premiumMember : l.standardMember,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (order.customerId != null)
                  TextButton.icon(
                    onPressed: onChangeTier,
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(l.change),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
