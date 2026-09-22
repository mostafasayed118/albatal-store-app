import 'package:flutter/material.dart';

/// Static (non-animated) tile placeholder used when the OS reduce-motion
/// flag is on (feature-batch §17; was private `_StaticTileSkeleton`).
class StaticTileSkeleton extends StatelessWidget {
  const StaticTileSkeleton({super.key});

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
