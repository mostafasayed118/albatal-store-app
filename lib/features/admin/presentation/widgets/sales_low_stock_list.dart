import 'package:flutter/material.dart';

import '../../domain/entities/low_stock_variant.dart';

/// Low-stock panel for the admin sales dashboard (#12): variants at or
/// below the threshold, worst stock first is not guaranteed — the RPC
/// `get_low_stock_products` ordering is preserved as-is.
class SalesLowStockCard extends StatelessWidget {
  const SalesLowStockCard({super.key, required this.variants});

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
            child: Text('Low stock (≤ 5)', style: textTheme.titleMedium),
          ),
          if (variants.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Nothing below the threshold',
                  style: textTheme.bodySmall),
            )
          else
            for (final variant in variants)
              ListTile(
                dense: true,
                title: Text(variant.productName),
                subtitle: Text(variant.variantLabel),
                trailing: Text(
                  '${variant.stock} left',
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
