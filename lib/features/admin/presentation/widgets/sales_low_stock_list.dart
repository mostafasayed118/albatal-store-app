import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/low_stock_variant.dart';

/// Low-stock panel for the admin sales dashboard (#12): variants at or
/// below the threshold, worst stock first is not guaranteed — the RPC
/// `get_low_stock_products` ordering is preserved as-is.
class SalesLowStockCard extends StatelessWidget {
  const SalesLowStockCard({super.key, required this.variants});

  /// Mirrors the default of `AdminRepository.getLowStock` (5): the panel's
  /// title prints it, so the query and the heading cannot drift apart silently.
  static const lowStockThreshold = 5;

  final List<LowStockVariant> variants;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(context.l10n.adminLowStockTitle(lowStockThreshold),
                style: textTheme.titleMedium),
          ),
          if (variants.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(context.l10n.adminLowStockEmpty,
                  style: textTheme.bodySmall),
            )
          else
            for (final variant in variants)
              ListTile(
                dense: true,
                title: Text(variant.productName),
                subtitle: Text(variant.variantLabel),
                trailing: Text(
                  context.l10n.adminStockLeft(variant.stock),
                  style: TextStyle(
                    color: variant.stock == 0 ? scheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
