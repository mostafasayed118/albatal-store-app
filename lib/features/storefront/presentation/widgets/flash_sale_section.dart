import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/catalog_cubit.dart';
import '../../data/products_data.dart';
import '../widgets/flash_sale_card.dart';

/// Flash sale section with countdown timer and product card.
class FlashSaleSection extends StatelessWidget {
  const FlashSaleSection({super.key, required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Text(l.flashSale, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Text(
              '${(state.saleSeconds ~/ 3600).toString().padLeft(2, '0')}:'
              '${((state.saleSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
              '${(state.saleSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: scheme.secondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FlashSaleCard(product: products.first),
      ],
    );
  }
}
