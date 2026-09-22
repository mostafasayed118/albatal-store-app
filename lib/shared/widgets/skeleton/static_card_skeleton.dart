import 'package:flutter/material.dart';

/// Static (non-animated) card placeholder used when the OS reduce-motion
/// flag is on (feature-batch §17; was private `_StaticCardSkeleton`).
class StaticCardSkeleton extends StatelessWidget {
  const StaticCardSkeleton({super.key});

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
