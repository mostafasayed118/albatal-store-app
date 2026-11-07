import 'package:flutter/material.dart';

/// Centers [child] when it fits and scrolls when it does not.
///
/// Full-screen empty/error/gate states are the worst offenders at large text
/// scales and in landscape: a plain `Center > Column` overflows and clips its
/// CTA. This keeps the centered look on normal viewports and makes the whole
/// block reachable when the content outgrows the screen.
final class ScrollableCenter extends StatelessWidget {
  const ScrollableCenter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded height (e.g. inside another scrollable) has nothing to
        // center against; the child simply sizes itself.
        final minHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Padding(padding: padding, child: child),
            ),
          ),
        );
      },
    );
  }
}
