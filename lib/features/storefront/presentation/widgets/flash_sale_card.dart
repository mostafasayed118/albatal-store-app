import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/cart_cubit.dart';
import '../../data/products_data.dart';
import 'product_image_placeholder.dart';

class FlashSaleCard extends StatelessWidget {
  const FlashSaleCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ProductImagePlaceholder(
              imageColor: product.imageColor,
              imageAsset: product.imageAsset,
              constraints: const BoxConstraints.tightFor(width: 90, height: 90),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('20% OFF · ${money(product.price)}'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.read<CartCubit>().add(product),
                    child: Text(l.addToCart),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
