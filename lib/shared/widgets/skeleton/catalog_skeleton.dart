import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../theme/grid_delegate.dart';
import 'product_card_skeleton.dart';
import 'static_card_skeleton.dart';

/// Catalog-shaped loading placeholder (feature-batch §3).
///
/// Mirrors the product-card grid so swapping the skeleton for real
/// content doesn't shift the page layout. Replaces spinner-style
/// `FeedbackView.loading` on the home and catalog surfaces.
///
/// Extracted from `skeleton_loaders.dart` (now a barrel); tile bodies
/// live in `skeleton/` (one widget per file).
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    // §17: the OS reduce-motion flag swaps the animated pulse for a
    // static shimmer-free placeholder grid.
    if (MediaQuery.disableAnimationsOf(context)) {
      return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: productGridDelegateForWidth(constraints.maxWidth),
          itemCount: itemCount,
          itemBuilder: (context, index) => const StaticCardSkeleton(),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Skeletonizer(
        enabled: true,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: productGridDelegateForWidth(constraints.maxWidth),
          itemCount: itemCount,
          itemBuilder: (context, index) => const ProductCardSkeleton(),
        ),
      ),
    );
  }
}
