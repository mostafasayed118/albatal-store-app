import 'package:flutter/material.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/pricing/cut_length_pricing.dart';

/// Wholesale tier table for sell-by-length fabrics (Wave C).
///
/// Renders the owner-tunable [kWholesaleTiers] ladder ("10+ m — 5%"
/// style rows) and highlights the row the shopper's current cut length
/// qualifies for. Purely presentational — all math lives in
/// `cut_length_pricing.dart`.
class PricingTierTable extends StatelessWidget {
  /// The wholesale ladder, lowest threshold first. Built once: the const
  /// ladder itself is unordered by design (it mirrors the RPC's tier list).
  static final List<({double minMeters, int discountPercent})> _ascendingTiers =
      [...kWholesaleTiers]..sort((a, b) => a.minMeters.compareTo(b.minMeters));

  const PricingTierTable({super.key, required this.meters});

  /// Current cut length selection in meters (0 when none parsed).
  final double meters;

  @override
  Widget build(BuildContext context) {
    if (kWholesaleTiers.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final activePercent = tierDiscountPercent(meters);
    // Render lowest threshold first (ascending) regardless of the
    // const ladder order. Sorted once, not per build (audit 2026-09-21).
    final tiers = _ascendingTiers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.pricingTiersTitle, style: theme.titleSmall),
        const SizedBox(height: 4),
        for (final tier in tiers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    // Whole-meters label via Money's canonical whole-unit
                    // formatter — one ruleset for every bare toStringAsFixed
                    // (audit 2026-09 money/meters formatting sweep).
                    l.pricingTierRow(Money.wholeEgpLabel(tier.minMeters),
                        tier.discountPercent),
                    style: theme.bodySmall?.copyWith(
                      color: tier.discountPercent == activePercent
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: tier.discountPercent == activePercent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (tier.discountPercent == activePercent)
                  Icon(Icons.check_circle, size: 16, color: scheme.primary),
              ],
            ),
          ),
      ],
    );
  }
}
