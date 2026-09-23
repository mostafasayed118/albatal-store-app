import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/pricing/cut_length_pricing.dart';
import '../cubit/product_details_cubit.dart';

/// Live "price × meters × quantity" estimate under the cut selector.
///
/// Extracted from `variant_selector.dart` verbatim (was private
/// `_MeteredPriceLine`).
class MeteredPriceLine extends StatelessWidget {
  const MeteredPriceLine(
      {super.key, required this.product, required this.state});
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
