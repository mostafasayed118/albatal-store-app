import 'package:flutter/material.dart';

import '../../../../core/entities/product.dart';

/// 5-star rating display with review count.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            i < product.rating.round() ? Icons.star : Icons.star_border,
            size: 18,
            color: scheme.secondary,
          ),
        ),
        const SizedBox(width: 6),
        Text('${product.rating}',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
        Text(' (${product.reviewCount})',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
