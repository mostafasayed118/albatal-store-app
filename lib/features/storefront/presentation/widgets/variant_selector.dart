import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/pricing/cut_length_pricing.dart';
import '../cubit/product_details_cubit.dart';
import 'color_swatches.dart';
import 'pricing_tier_table.dart';
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
                    runSpacing: 8,
                    children: product.colors
                        .map((x) => ChoiceChip(
                              avatar: ColorSwatchDot(name: x),
                              label: Text(x),
                              selected: state.color == x,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
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
                  if (product.sellByLength) ...[
                    // §10: cut-length stepper for sell-by-the-meter rolls
                    // (0.5 m steps, min cut clamped in the cubit).
                    Row(
                      children: [
                        IconButton(
                          tooltip: l.cutLength,
                          onPressed: () {
                            final current = double.tryParse(state.length) ??
                                product.minCutMeters ??
                                1.0;
                            cubit.setCutLength(current - 0.5);
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                            '${(double.tryParse(state.length) ?? product.minCutMeters ?? 1.0).toStringAsFixed(1)} m'),
                        IconButton(
                          tooltip: l.cutLength,
                          onPressed: () {
                            final current = double.tryParse(state.length) ??
                                product.minCutMeters ??
                                1.0;
                            cubit.setCutLength(current + 0.5);
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Text(l.sellByLengthNote,
                        style: Theme.of(context).textTheme.bodySmall),
                    // Wave C: running metered line price (tier-aware)
                    // + the wholesale tier ladder.
                    _MeteredPriceLine(product: product, state: state),
                    const SizedBox(height: 8),
                    PricingTierTable(
                        meters: double.tryParse(state.length) ?? 0),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.sizes
                          .map((x) => ChoiceChip(
                                label: Text(x),
                                selected: state.length == x,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                onSelected: (_) => cubit.length(x),
                              ))
                          .toList(),
                    ),
                  ],
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

/// Live "price × meters × quantity" estimate under the cut selector.
class _MeteredPriceLine extends StatelessWidget {
  const _MeteredPriceLine({required this.product, required this.state});
  final Product product;
  final DetailsState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meters = double.tryParse(state.length);
    if (meters == null) return const SizedBox.shrink();
    final total = meteredLineTotal(
        tieredPerMeterPrice(product.price, meters), meters,
        quantity: state.quantity);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        l.cutLengthEstimatedTotal(total.format()),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
