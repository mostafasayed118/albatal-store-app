import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/grid_delegate.dart';

/// Catalog-shaped loading placeholder (feature-batch §3).
///
/// Mirrors the product-card grid so swapping the skeleton for real
/// content doesn't shift the page layout. Replaces spinner-style
/// `FeedbackView.loading` on the home and catalog surfaces.
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
          itemBuilder: (context, index) => const _StaticCardSkeleton(),
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
          itemBuilder: (context, index) => const _ProductCardSkeleton(),
        ),
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

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

/// Orders-list loading placeholder (feature-batch §3).
class OrdersSkeleton extends StatelessWidget {
  const OrdersSkeleton({super.key, this.tileCount = 6});

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tileCount,
        itemBuilder: (context, index) => const _StaticTileSkeleton(),
      );
    }
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tileCount,
        itemBuilder: (context, index) => const _OrderTileSkeleton(),
      ),
    );
  }
}

/// Static (non-animated) placeholder used when the OS reduce-motion
/// flag is on (feature-batch §17).
class _StaticCardSkeleton extends StatelessWidget {
  const _StaticCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                SizedBox(width: 120, height: 12),
                SizedBox(height: 4),
                SizedBox(width: 60, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticTileSkeleton extends StatelessWidget {
  const _StaticTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(width: 44, height: 44),
        title: SizedBox(width: 160, height: 12),
        subtitle: SizedBox(width: 100, height: 10),
      ),
    );
  }
}

class _OrderTileSkeleton extends StatelessWidget {
  const _OrderTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Bone.circle(size: 44),
        title: Bone.text(words: 2),
        subtitle: Bone.text(words: 1),
        trailing: Bone.button(width: 64),
      ),
    );
  }
}
