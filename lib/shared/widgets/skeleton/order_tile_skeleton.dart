import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Animated order-tile bone (was private `_OrderTileSkeleton`).
class OrderTileSkeleton extends StatelessWidget {
  const OrderTileSkeleton({super.key});

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
