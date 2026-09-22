import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Animated product-card bone (was private `_ProductCardSkeleton`).
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Skeletonizer paints decorated containers as bones, so a
          // plain surface box reads as the product image area.
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2),
                SizedBox(height: 4),
                Bone.text(words: 1, fontSize: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
