import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/product_details_cubit.dart';
import 'quantity_stepper.dart';
import 'stock_badge.dart';

/// Color, length, and quantity selectors.
class VariantSelector extends StatelessWidget {
  const VariantSelector(
      {super.key, required this.product, required this.state});
  final Product product;
  final DetailsState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ProductDetailsCubit>();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.color, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.colors
                        .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: state.color == x,
                              onSelected: (_) => cubit.color(x),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StockBadge(stock: state.stock, l: l),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.length,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: product.sizes
                        .map((x) => ChoiceChip(
                              label: Text(x),
                              selected: state.length == x,
                              onSelected: (_) => cubit.length(x),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(l.quantity, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            QuantityStepper(
              quantity: state.quantity,
              onChanged: (v) => cubit.quantity(v),
              max: state.stock,
            ),
          ],
        ),
      ],
    );
  }
}
