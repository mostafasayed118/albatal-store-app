import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import '../../../../generated/l10n/app_localizations.dart';
import 'info_row.dart';

/// Description, composition, origin, and care details.
class ProductDetailsSection extends StatelessWidget {
  const ProductDetailsSection(
      {super.key, required this.product, required this.l});
  final Product product;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    if (product.composition == null &&
        product.origin == null &&
        product.care == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.composition != null || product.origin != null) ...[
          const SizedBox(height: 20),
          Text(l.details, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (product.composition != null)
            InfoRow(
                icon: Icons.science_outlined,
                label: l.composition,
                value: product.composition!),
          if (product.origin != null)
            InfoRow(
                icon: Icons.place_outlined,
                label: l.origin,
                value: product.origin!),
        ],
        if (product.care != null) ...[
          const SizedBox(height: 20),
          Text(l.care, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(product.care!),
        ],
      ],
    );
  }
}
