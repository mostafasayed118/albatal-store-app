import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'order_tile_skeleton.dart';
import 'static_tile_skeleton.dart';

/// Orders-list loading placeholder (feature-batch §3).
///
/// Extracted from `skeleton_loaders.dart` (now a barrel); tile bodies
/// live in `skeleton/` (one widget per file).
class OrdersSkeleton extends StatelessWidget {
  const OrdersSkeleton({super.key, this.tileCount = 6});

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tileCount,
        itemBuilder: (context, index) => const StaticTileSkeleton(),
      );
    }
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tileCount,
        itemBuilder: (context, index) => const OrderTileSkeleton(),
      ),
    );
  }
}
